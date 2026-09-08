import fs from "fs";
import { Document } from "@langchain/core/documents";
import { RecursiveCharacterTextSplitter } from "@langchain/textsplitters";
import { OllamaEmbeddings } from "@langchain/ollama";
import { PGVectorStore } from "@langchain/community/vectorstores/pgvector";

async function processText() {
  console.log("Mulai membaca dokumen TXT...");

  // 1. Baca file TXT menggunakan sistem file bawaan Node.js
  const textData = fs.readFileSync("./ryan.txt", "utf-8");

  // Bungkus teks ke dalam format Dokumen LangChain
  const docs = [new Document({ pageContent: textData })];
  console.log("Dokumen berhasil dibaca. Mulai memotong teks...");

  // 2. Potong teks
  const splitter = new RecursiveCharacterTextSplitter({
    chunkSize: 500,
    chunkOverlap: 50,
  });
  const splitDocs = await splitter.splitDocuments(docs);
  console.log(
    `Teks dipotong menjadi ${splitDocs.length} bagian. Menyimpan ke Database...`,
  );

  // 3. Konfigurasi Koneksi PostgreSQL (Sesuaikan jika Anda mengganti password docker)
  const dbConfig = {
    postgresConnectionOptions: {
      type: "postgres",
      host: "127.0.0.1",
      port: 5433,
      user: "admin",
      password: "rahasia",
      database: "rag_db",
    },
    tableName: "txt_embeddings", // Nama tabel kita bedakan
    columns: {
      idColumnName: "id",
      vectorColumnName: "embedding",
      contentColumnName: "text",
    },
  };

  // 4. Ubah teks ke Vektor (Embedding) dan Simpan ke DB
  const embeddings = new OllamaEmbeddings({ 
    model: "nomic-embed-text",
    baseUrl: "http://127.0.0.1:11434" // Paksa menggunakan IPv4
  });
  // Tampung hasil inisialisasi ke dalam variabel 'vectorStore'
  const vectorStore = await PGVectorStore.initialize(embeddings, dbConfig);
  await vectorStore.addDocuments(splitDocs);

  console.log(
    "Berhasil! Konteks teks telah diproses dan disimpan ke PostgreSQL pgvector!",
  );

  // Tambahkan baris ini agar script Node.js otomatis berhenti
  process.exit(0);
}

processText().catch(console.error);
