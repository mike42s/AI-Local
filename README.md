# 🚀 AI-Local: On-Premise Enterprise AI Chatbot & HR Candidate Screening RAG System

![AI-Local Architecture](https://img.shields.io/badge/Architecture-Fullstack_AI_RAG-deeppurple)
![Flutter](https://img.shields.io/badge/Frontend-Flutter_Material_3-blue)
![Express](https://img.shields.io/badge/Backend-Node.js_Express_ESM-green)
![Ollama](https://img.shields.io/badge/AI_Engine-Ollama_qwen2.5--coder-orange)
![PostgreSQL](https://img.shields.io/badge/Vector_DB-PostgreSQL_pgvector-blue)

A 100% **On-Premise, Zero-Cloud-Dependency** Enterprise AI Platform built with Node.js Express, LangChain, PostgreSQL (`pgvector`), Ollama, and Flutter.

---

## 🎯 System Architecture & Isolation Model

```text
 ┌────────────────────────────────────────────────────────┐
 │                Flutter Client Application              │
 │   • Menu 1: AI Chatbot | Menu 2: HR Screening (RAG)    │
 └───────────────────────────┬────────────────────────────┘
                             │ HTTP SSE Stream (Port 3000)
 ┌───────────────────────────▼────────────────────────────┐
 │               Node.js Express API Gateway              │
 │  • /api/chat/stream  • /api/rag/stream & /api/rag/ingest │
 └─────────────┬──────────────────────────────┬───────────┘
               │                              │
  Company      │ Similarity Search            │ Prompt + Context Stream
  Rules Vector │                              │ (Rules DB + Candidate CV)
 ┌─────────────▼──────────────┐  ┌────────────▼──────────────┐
 │ PostgreSQL pgvector (5433) │  │   Ollama Engine (11434)  │
 │  Tabel Rules: txt_embeddings│  │ qwen2.5-coder & nomic-embed│
 └────────────────────────────┘  └──────────────────────────┘
```

> 🔒 **Isolated Candidate Evaluation Model**: Data CV pelamar yang diunggah saat chat dievaluasi secara **on-the-fly di memori** dan **TIDAK disimpan ke database pgvector**. Database pgvector murni digunakan untuk menyimpan **Rules/SOP/Syarat Perusahaan**, sehingga data antar pelamar tidak saling tercampur atau mengotori database!

---

## 🌟 Key Features

### 1. 🤖 Menu 1: AI Chatbot (Real-time SSE Stream)
- Real-time Server-Sent Events (SSE) stream using Ollama (`qwen2.5-coder:7b`).
- Responsive typing effect in Flutter with zero UI freezing (*non-blocking stream*).

### 2. 📑 Menu 2: HR Candidate Screening & RAG Filter
- **Zero-Hallucination RAG**: Answers queries strictly based on company SOP/rules documents stored in pgvector.
- **Direct PDF CV Attachment**: Attach candidate CVs directly in the chat bar (`📎`).
- **Automated 1-100 Match Score Grading**: Calculates a `[MATCH SCORE: XX/100]` matching score badge for candidate qualification.
- **Bilingual CV Support**: Seamlessly analyzes resumes written in **Indonesian** or **English**.

---

## 🔍 How to Debug & Verify the AI (Panduan Memastikan AI Bekerja dengan Benar)

### 1. Pengujian RAG & Zero-Hallucination
1. **Langkah 1**: Masukkan aturan/syarat jabatan perusahaan ke database via modal `+ Ingest CV / Dokumen` (atau jalankan `node ingest.js`).
2. **Langkah 2**: Tanyakan kriteria posisi yang **TIDAK ADA** di database (contoh: *"Berapa standar gaji Manajer Keuangan?"*).
   - **Hasil Valid**: AI akan menjawab: *"Tidak ditemukan dokumen/konteks spesifik di database pgvector"*. Ini membuktikan AI **100% tidak berhalusinasi** dan patuh pada database.

### 2. Pengujian Evaluasi Kandidat CV (Match Score 1-100)
1. **Langkah 1**: Klik icon klip 📎 di chat bar `RagScreen`, lampirkan file PDF CV pelamar (misal `RYAN-CV.pdf`).
2. **Langkah 2**: Tekan Kirim.
3. **Hasil Valid**:
   - **Terminal Backend**: Memunculkan log real-time:
     ```text
     [RAG DEBUG] Incoming Query: "Evaluasi kualifikasi CV pelamar..."
     [RAG DEBUG] On-The-Fly Candidate CV Extracted (5037 chars)
     [RAG DEBUG] Company Rules Retrieved from pgvector (2 chunks)
     ```
   - **Tampilan Flutter**: Menampilkan Badge Skor Match (misal `SCORE: 85/100 • Sangat Layak`), poin kelebihan kandidat, dan syarat yang belum terpenuhi.

---

## 📦 Prerequisites & System Setup

### 1. Run Ollama & Pull Local Models
```bash
ollama pull qwen2.5-coder:7b
ollama pull nomic-embed-text
```

### 2. Run PostgreSQL with `pgvector` via Docker
```bash
docker run --name pgvector-container \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=rahasia \
  -e POSTGRES_DB=rag_db \
  -p 5433:5432 \
  -d pgvector/pgvector:pg16
```

---

## 🚀 Running the Application

### 1. Backend API Gateway (Node.js Express)
```bash
cd backend
npm install
npm run dev
```

### 2. Frontend Client (Flutter)
```bash
cd frontend
flutter pub get
flutter run
```

---

## 📄 License
Licensed under the ISC License.
