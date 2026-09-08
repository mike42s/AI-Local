import { Ollama, OllamaEmbeddings } from "@langchain/ollama";
import { PGVectorStore } from "@langchain/community/vectorstores/pgvector";
import { PromptTemplate } from "@langchain/core/prompts";

async function askQuestion(question) {
  console.log(`Mencari informasi di database untuk: "${question}"...\n`);
  
  // 1. Setup Embeddings (Harus sama persis dengan saat Ingest)
  const embeddings = new OllamaEmbeddings({ 
    model: "nomic-embed-text",
    baseUrl: "http://127.0.0.1:11434" 
  });

  // 2. Konfigurasi DB (Port 5433 dan tabel txt_embeddings)
  const dbConfig = {
    postgresConnectionOptions: {
      type: "postgres",
      host: "127.0.0.1",
      port: 5433,
      user: "admin",
      password: "rahasia",
      database: "rag_db",
    },
    tableName: "txt_embeddings", 
    columns: { idColumnName: "id", vectorColumnName: "embedding", contentColumnName: "text" },
  };

  // 3. Cari Konteks di Database (Retrieval)
  const vectorStore = await PGVectorStore.initialize(embeddings, dbConfig);
  const results = await vectorStore.similaritySearch(question, 1); // Ambil 1 potong teks paling relevan
  
  if (results.length === 0) {
    console.log("Konteks tidak ditemukan di database.");
    process.exit(1);
  }
  
  const context = results.map(r => r.pageContent).join("\n");
  console.log("✅ Konteks Ditemukan:\n", context, "\n");

  // 4. Siapkan Prompt untuk AI
  const promptTemplate = PromptTemplate.fromTemplate(`
Anda adalah asisten HRD internal perusahaan. Gunakan HANYA konteks berikut untuk menjawab pertanyaan.
Jika informasi tidak ada di dalam konteks, katakan "Saya tidak memiliki informasi tersebut".

Konteks: 
{context}

Pertanyaan: {question}
Jawaban:
  `);
  
  const formattedPrompt = await promptTemplate.format({ context, question });

  // 5. Tanya ke Ollama (LLM)
  // Catatan: Pastikan model qwen2.5-coder:7b sudah Anda pull, jika belum, ganti ke model yang Anda miliki (misal: llama3)
  const llm = new Ollama({ 
    model: "qwen2.5-coder:7b", 
    baseUrl: "http://127.0.0.1:11434"
  });
  
  console.log("🤖 AI sedang berpikir merangkai jawaban...\n");
  const response = await llm.invoke(formattedPrompt);
  
  console.log("===============================");
  console.log("JAWABAN AI:");
  console.log(response);
  console.log("===============================");
  
  process.exit(0);
}

// Mari kita tanya informasi spesifik yang ada di file TXT Anda tadi
askQuestion("Apa syarat pendidikan dan keahlian untuk posisi IT Developer SPV?");