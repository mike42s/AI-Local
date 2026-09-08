import express from "express";
import http from "http";

const router = express.Router();

/**
 * POST /api/chat/stream
 * Body: { prompt: string, model?: string }
 * Streams real-time AI responses using Server-Sent Events (SSE).
 */
router.post("/stream", (req, res) => {
  const { prompt, model } = req.body;

  if (!prompt || typeof prompt !== "string" || prompt.trim() === "") {
    return res.status(400).json({ error: "Prompt parameter is required." });
  }

  const selectedModel = model || process.env.OLLAMA_MODEL || "qwen2.5-coder:7b";
  const ollamaHost = process.env.OLLAMA_HOST || "127.0.0.1";
  const ollamaPort = process.env.OLLAMA_PORT || 11434;

  // Set headers for Server-Sent Events (SSE)
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no"); // Disable proxy buffering

  const payload = JSON.stringify({
    model: selectedModel,
    prompt: prompt,
    stream: true,
  });

  const options = {
    hostname: ollamaHost,
    port: ollamaPort,
    path: "/api/generate",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(payload),
    },
  };

  const ollamaReq = http.request(options, (ollamaRes) => {
    if (ollamaRes.statusCode !== 200) {
      res.write(`data: ${JSON.stringify({ error: `Ollama error status ${ollamaRes.statusCode}` })}\n\n`);
      res.end();
      return;
    }

    let buffer = "";

    ollamaRes.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      const lines = buffer.split("\n");
      buffer = lines.pop(); // Keep remaining incomplete line in buffer

      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const parsed = JSON.parse(line);
          const responseText = parsed.response || "";
          const isDone = parsed.done || false;

          res.write(
            `data: ${JSON.stringify({
              text: responseText,
              done: isDone,
            })}\n\n`
          );
        } catch (e) {
          // If JSON parse fails, skip
        }
      }
    });

    ollamaRes.on("end", () => {
      if (buffer.trim()) {
        try {
          const parsed = JSON.parse(buffer);
          res.write(
            `data: ${JSON.stringify({
              text: parsed.response || "",
              done: true,
            })}\n\n`
          );
        } catch (e) {
          // Ignore
        }
      }
      res.write(`data: ${JSON.stringify({ done: true })}\n\n`);
      res.end();
    });
  });

  ollamaReq.on("error", (err) => {
    console.error("[Ollama HTTP Error]:", err.message);
    res.write(
      `data: ${JSON.stringify({
        error: `Unable to connect to Ollama at ${ollamaHost}:${ollamaPort}. Make sure Ollama is running.`,
        done: true,
      })}\n\n`
    );
    res.end();
  });

  // Handle client response connection drop
  res.on("close", () => {
    if (!res.writableEnded) {
      ollamaReq.destroy();
    }
  });

  ollamaReq.write(payload);
  ollamaReq.end();
});

export default router;
