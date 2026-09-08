# 🚀 AI-Local: On-Premise Enterprise AI Chatbot & HR Candidate Screening RAG System

![AI-Local Architecture](https://img.shields.io/badge/Architecture-Fullstack_AI_RAG-deeppurple)
![Flutter](https://img.shields.io/badge/Frontend-Flutter_Material_3-blue)
![Express](https://img.shields.io/badge/Backend-Node.js_Express_ESM-green)
![Ollama](https://img.shields.io/badge/AI_Engine-Ollama_qwen2.5--coder-orange)
![PostgreSQL](https://img.shields.io/badge/Vector_DB-PostgreSQL_pgvector-blue)

A 100% **On-Premise, Zero-Cloud-Dependency** Enterprise AI Platform built with Node.js Express, LangChain, PostgreSQL (`pgvector`), Ollama, and Flutter.

---

## 🎯 System Architecture

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
  Embeddings   │ Similarity Search            │ Prompt + Context Stream
 ┌─────────────▼──────────────┐  ┌────────────▼──────────────┐
 │ PostgreSQL pgvector (5433) │  │   Ollama Engine (11434)  │
 │   Tabel: txt_embeddings    │  │ qwen2.5-coder & nomic-embed│
 └────────────────────────────┘  └──────────────────────────┘
```

---

## 🌟 Key Features

### 1. 🤖 Menu 1: AI Chatbot (Real-time SSE Stream)
- Real-time Server-Sent Events (SSE) stream using Ollama (`qwen2.5-coder:7b`).
- Responsive typing effect in Flutter with zero UI freezing (*non-blocking stream*).

### 2. 📑 Menu 2: HR Candidate Screening & RAG Filter
- **Zero-Hallucination RAG**: Answers queries strictly based on candidate CVs and company SOP documents stored in pgvector.
- **Automated 1-100 Match Score Grading**: Calculates a `[MATCH SCORE: XX/100]` matching score badge for candidate qualification.
- **Bilingual CV Support**: Seamlessly analyzes resumes written in **Indonesian** or **English**.
- **In-App Document Ingestion**: Ingest new candidate CVs or SOP text files directly via Flutter modal UI or API.

---

## 📦 Prerequisites & System Setup

### 1. Run Ollama & Pull Local Models
Make sure Ollama is installed and running on your system:
```bash
ollama pull qwen2.5-coder:7b
ollama pull nomic-embed-text
```

### 2. Run PostgreSQL with `pgvector` via Docker
Launch the PostgreSQL vector database on port `5433`:
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
The server will start at `http://localhost:3000`.

#### Environment Configuration (`backend/.env`):
```env
PORT=3000
OLLAMA_HOST=127.0.0.1
OLLAMA_PORT=11434
OLLAMA_MODEL=qwen2.5-coder:7b
EMBED_MODEL=nomic-embed-text
PG_HOST=127.0.0.1
PG_PORT=5433
PG_USER=admin
PG_PASSWORD=rahasia
PG_DATABASE=rag_db
```

### 2. Ingest Sample Document / Candidate CV (Optional Command-Line)
```bash
cd backend
node ingest.js
```

### 3. Frontend Client (Flutter)
```bash
cd frontend
flutter pub get
flutter run
```

---

## 🛠️ Tech Stack & Dependencies

- **Frontend**: Flutter, Flutter Riverpod 3.x, `http` client, Material 3.
- **Backend Gateway**: Node.js (ES Modules), Express 5, CORS, Dotenv.
- **RAG & Vector AI**: LangChain (`@langchain/community`, `@langchain/ollama`), PostgreSQL (`pgvector`).
- **Local AI Models**: Ollama (`qwen2.5-coder:7b` for LLM, `nomic-embed-text` for Embeddings).

---

## 📄 License
Licensed under the ISC License.
