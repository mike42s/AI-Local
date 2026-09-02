require("dotenv").config();

const express = require("express");
const cors = require("cors");

const app = express();

const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get("/health", (req, res) => {
  res.json({
    success: true,
    message: "AI-Local backend is running",
    timestamp: new Date().toISOString(),
  });
});

app.listen(PORT, () => {
  console.log(`Backend running at http://localhost:${PORT}`);
});