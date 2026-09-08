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

    console.log(`[RAG INGEST SUCCESS] Ingested '${docTitle}' into pgvector (${splitDocs.length} chunks)`);

    return res.json({
      success: true,
      message: `Dokumen SOP/Rules '${docTitle}' berhasil disimpan ke PostgreSQL pgvector!`,
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

    const docTitle = title || `Rules_PDF_${Date.now()}`;
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

    console.log(`[RAG INGEST PDF SUCCESS] Ingested '${docTitle}' into pgvector (${splitDocs.length} chunks)`);

    return res.json({
      success: true,
      message: `Dokumen SOP/Rules PDF '${docTitle}' (${extractedText.length} karakter) berhasil diekstrak dan disimpan ke PostgreSQL pgvector!`,
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
 * Accepts candidate CV attached on-the-fly via candidatePdfBase64 without polluting the pgvector rules database.
 * Body: { prompt?: string, question?: string, candidatePdfBase64?: string, candidateText?: string }
 */
router.post("/stream", async (req, res) => {
  const query = req.body.prompt || req.body.question || "Evaluasi kualifikasi CV pelamar ini";
  const candidatePdfBase64 = req.body.candidatePdfBase64;
  let candidateCvText = req.body.candidateText || "";

  // Set SSE Headers
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");

  try {
    console.log("==================================================");
    console.log(`[RAG DEBUG] Incoming Query: "${query}"`);

    // Parse Candidate PDF CV on-the-fly if attached
    if (candidatePdfBase64 && typeof candidatePdfBase64 === "string") {
      try {
        const pdfBuf = Buffer.from(candidatePdfBase64, "base64");
        const parsed = await pdfParse(pdfBuf);
        candidateCvText = parsed.text ? parsed.text.trim() : "";
        console.log(`[RAG DEBUG] On-The-Fly Candidate CV Extracted (${candidateCvText.length} chars)`);
      } catch (pdfErr) {
        console.error("[RAG DEBUG] Failed to parse candidate PDF on-the-fly:", pdfErr.message);
      }
    }

    if (!candidateCvText) {
      candidateCvText = "Tidak ada dokumen CV pelamar yang diunggah secara khusus pada request ini. Evaluasi dilakukan berdasarkan konteks kualifikasi umum.";
    }

    // Retrieve Company Rules / Job Position requirements from pgvector DB
    const dbConfig = getDbConfig();
    const vectorStore = await PGVectorStore.initialize(getEmbeddings(), dbConfig);

    const searchResults = await vectorStore.similaritySearch(query, 2);

    let companyRulesContext = "";
    if (searchResults && searchResults.length > 0) {
      companyRulesContext = searchResults.map((doc) => doc.pageContent).join("\n---\n");
      console.log(`[RAG DEBUG] Company Rules Retrieved from pgvector (${searchResults.length} chunks):`);
      console.log(companyRulesContext.substring(0, 300) + "...");
    } else {
      companyRulesContext = "Tidak ditemukan dokumen aturan/syarat posisi spesifik di database pgvector.";
      console.log("[RAG DEBUG] No specific Company Rules found in pgvector.");
    }

    const hrPromptTemplate = PromptTemplate.fromTemplate(`
Anda adalah Sistem AI HRD Screening & Evaluasi Pelamar Kerja yang sangat profesional dan obyektif.
Sistem ini mendukung analisis CV dan dokumen kualifikasi baik dalam Bahasa Indonesia maupun Bahasa Inggris (Bilingual).

Instruksi Evaluasi:
1. **MATCH SCORE (1-100)**: Berikan SKOR KECOCOKAN PELAMAR dari skala 1 sampai 100 berdasarkan kesesuaian antara Dokumen CV Pelamar dengan Syarat/Aturan Perusahaan.
   WAJIB sertakan header unik persis dalam format: \`[MATCH SCORE: XX/100]\` (contoh: \`[MATCH SCORE: 85/100]\`).
2. **Kelebihan Utama (Key Strengths)**: Tuliskan poin-poin keunggulan kandidat.
3. **Kekurangan / Gap (Missing Requirements)**: Tuliskan kualifikasi yang belum terpenuhi atau perlu diklarifikasi.
4. **Rekomendasi Akhir HRD**: Berikan kesimpulan (Sangat Layak / Dipertimbangkan / Tidak Layak).

Syarat / Aturan Perusahaan (Dari Database Vector pgvector):
---
{companyRulesContext}
---

Dokumen CV Pelamar (Diunggah pada Request Ini):
---
{candidateCvText}
---

Pertanyaan / Instruksi Evaluasi HRD:
{question}

Jawaban Evaluasi HRD & Skor Match:
    `);

    const formattedPrompt = await hrPromptTemplate.format({
      companyRulesContext: companyRulesContext,
      candidateCvText: candidateCvText,
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

    console.log("[RAG DEBUG] Streaming response finished successfully.");
    console.log("==================================================");

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
