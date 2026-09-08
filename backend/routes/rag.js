import express from "express";
import pdfParse from "pdf-parse/lib/pdf-parse.js";
import { Ollama, OllamaEmbeddings } from "@langchain/ollama";
import { PGVectorStore } from "@langchain/community/vectorstores/pgvector";
import { PromptTemplate } from "@langchain/core/prompts";
import { Document } from "@langchain/core/documents";
import { RecursiveCharacterTextSplitter } from "@langchain/textsplitters";

const router = express.Router();

const getDbConfig = () => ({
  postgresConnectionOptions: {
    type: "postgres",
    host: process.env.PG_HOST || "127.0.0.1",
    port: parseInt(process.env.PG_PORT || "5433", 10),
    user: process.env.PG_USER || "admin",
    password: process.env.PG_PASSWORD || "rahasia",
    database: process.env.PG_DATABASE || "rag_db",
  },
  tableName: "txt_embeddings",
  columns: {
    idColumnName: "id",
    vectorColumnName: "embedding",
    contentColumnName: "text",
  },
});

const getEmbeddings = () => {
  return new OllamaEmbeddings({
    model: process.env.EMBED_MODEL || "nomic-embed-text",
    baseUrl: process.env.OLLAMA_URL || "http://127.0.0.1:11434",
  });
};

/**
 * POST /api/rag/ingest
 * Ingest document/text into pgvector database
 * Body: { content: string, title?: string }
 */
router.post("/ingest", async (req, res) => {
  try {
    const { content, title } = req.body;
    if (!content || typeof content !== "string" || content.trim() === "") {
      return res.status(400).json({ error: "Content parameter is required." });
    }

    const docTitle = title || `Document_${Date.now()}`;
    const doc = new Document({
      pageContent: content,
      metadata: { title: docTitle, createdAt: new Date().toISOString() },
    });

    const splitter = new RecursiveCharacterTextSplitter({
      chunkSize: 500,
      chunkOverlap: 50,
    });
    const splitDocs = await splitter.splitDocuments([doc]);

    const dbConfig = getDbConfig();
    const vectorStore = await PGVectorStore.initialize(getEmbeddings(), dbConfig);
    await vectorStore.addDocuments(splitDocs);

    return res.json({
      success: true,
      message: `Dokumen '${docTitle}' berhasil disimpan ke PostgreSQL pgvector!`,
      chunksCount: splitDocs.length,
    });
  } catch (error) {
    console.error("[RAG Ingest Error]:", error);
    return res.status(500).json({
      success: false,
      error: `Gagal memproses dokumen RAG: ${error.message}`,
    });
  }
});

/**
 * POST /api/rag/ingest-pdf
 * Parse PDF base64 buffer, chunk text, embed, and store into pgvector database
 * Body: { pdfBase64: string, title?: string }
 */
router.post("/ingest-pdf", async (req, res) => {
  try {
    const { pdfBase64, title } = req.body;
    if (!pdfBase64 || typeof pdfBase64 !== "string" || pdfBase64.trim() === "") {
      return res.status(400).json({ error: "pdfBase64 parameter is required." });
    }

    const pdfBuffer = Buffer.from(pdfBase64, "base64");
    const parsedPdf = await pdfParse(pdfBuffer);
    const extractedText = parsedPdf.text ? parsedPdf.text.trim() : "";

    if (!extractedText) {
      return res.status(400).json({ error: "Tidak dapat mengekstrak teks dari file PDF." });
    }

    const docTitle = title || `CV_PDF_${Date.now()}`;
    const doc = new Document({
      pageContent: extractedText,
      metadata: { title: docTitle, source: "PDF_Upload", createdAt: new Date().toISOString() },
    });

    const splitter = new RecursiveCharacterTextSplitter({
      chunkSize: 500,
      chunkOverlap: 50,
    });
    const splitDocs = await splitter.splitDocuments([doc]);

    const dbConfig = getDbConfig();
    const vectorStore = await PGVectorStore.initialize(getEmbeddings(), dbConfig);
    await vectorStore.addDocuments(splitDocs);

    return res.json({
      success: true,
      message: `File PDF CV '${docTitle}' (${extractedText.length} karakter) berhasil diekstrak dan disimpan ke PostgreSQL pgvector!`,
      chunksCount: splitDocs.length,
      charsExtracted: extractedText.length,
    });
  } catch (error) {
    console.error("[RAG PDF Ingest Error]:", error);
    return res.status(500).json({
      success: false,
      error: `Gagal mengekstrak dan memproses file PDF: ${error.message}`,
    });
  }
});

/**
 * POST /api/rag/stream
 * Perform RAG similarity search & stream response with 1-100 Grading and Bilingual (EN/ID) support.
 * Body: { prompt?: string, question?: string }
 */
router.post("/stream", async (req, res) => {
  const query = req.body.prompt || req.body.question;
  if (!query || typeof query !== "string" || query.trim() === "") {
    return res.status(400).json({ error: "Prompt/question parameter is required." });
  }

  // Set SSE Headers
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");

  try {
    const dbConfig = getDbConfig();
    const vectorStore = await PGVectorStore.initialize(getEmbeddings(), dbConfig);

    // Retrieve top 2 matching context chunks
    const searchResults = await vectorStore.similaritySearch(query, 2);

    let context = "";
    if (searchResults && searchResults.length > 0) {
      context = searchResults.map((doc) => doc.pageContent).join("\n---\n");
    } else {
      context = "Tidak ditemukan dokumen/konteks spesifik di database pgvector.";
    }

    const hrPromptTemplate = PromptTemplate.fromTemplate(`
Anda adalah Sistem AI HRD Screening & Evaluasi Pelamar Kerja yang sangat profesional dan obyektif.
Sistem ini mendukung analisis CV dan dokumen kualifikasi baik dalam Bahasa Indonesia maupun Bahasa Inggris (Bilingual).

Instruksi Evaluasi:
1. **MATCH SCORE (1-100)**: Berikan SKOR KECOCOKAN PELAMAR dari skala 1 sampai 100 berdasarkan kesesuaian antara kualifikasi pelamar pada konteks dengan kualifikasi yang dicari/ditanyakan.
   WAJIB sertakan header unik persis dalam format: \`[MATCH SCORE: XX/100]\` (contoh: \`[MATCH SCORE: 85/100]\`).
2. **Kelebihan Utama (Key Strengths)**: Tuliskan poin-poin keunggulan kandidat.
3. **Kekurangan / Gap (Missing Requirements)**: Tuliskan kualifikasi yang belum terpenuhi atau perlu diklarifikasi.
4. **Rekomendasi Akhir HRD**: Berikan kesimpulan (Sangat Layak / Dipertimbangkan / Tidak Layak).

Gunakan Konteks Dokumen dari Database berikut sebagai acuan utama:
---
{context}
---

Pertanyaan / Kriteria Evaluasi HRD:
{question}

Jawaban Evaluasi HRD & Skor Match:
    `);

    const formattedPrompt = await hrPromptTemplate.format({
      context: context,
      question: query,
    });

    const llm = new Ollama({
      model: process.env.OLLAMA_MODEL || "qwen2.5-coder:7b",
      baseUrl: process.env.OLLAMA_URL || "http://127.0.0.1:11434",
    });

    const stream = await llm.stream(formattedPrompt);

    for await (const chunk of stream) {
      if (res.writableEnded) break;
      res.write(
        `data: ${JSON.stringify({
          text: chunk,
          done: false,
        })}\n\n`
      );
    }

    res.write(`data: ${JSON.stringify({ done: true })}\n\n`);
    res.end();
  } catch (error) {
    console.error("[RAG Stream Error]:", error);
    res.write(
      `data: ${JSON.stringify({
        error: `RAG System Error: ${error.message}. Pastikan PostgreSQL pgvector (port 5433) dan Ollama sudah berjalan.`,
        done: true,
      })}\n\n`
    );
    res.end();
  }
});

export default router;
