import dotenv from "dotenv";
import express from "express";
import cors from "cors";
import chatRouter from "./routes/chat.js";
import ragRouter from "./routes/rag.js";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: "15mb" }));

app.use("/api/chat", chatRouter);
app.use("/api/rag", ragRouter);

app.get("/health", (req, res) => {
  res.json({
    success: true,
    message: "AI-Local Express Gateway with RAG Engine is running",
    timestamp: new Date().toISOString(),
  });
});

app.listen(PORT, () => {
  console.log(`Backend running at http://localhost:${PORT}`);
});
