const { spawn, exec } = require("child_process");
const fs = require("fs");
const path = require("path");

const TASKS_FILE = path.join(__dirname, "TASKS.md");
const OPENCODE_CMD = path.join(process.env.APPDATA, "npm", "opencode.cmd");
const DELAY_BETWEEN_TASKS_MS = 5000;

function processNextTask() {
  if (!fs.existsSync(TASKS_FILE)) {
    console.error(`[❌] File TASKS.md tidak ditemukan di: ${TASKS_FILE}`);
    process.exit(1);
  }

  const content = fs.readFileSync(TASKS_FILE, "utf8");
  const lines = content.split("\n");

  const allTasks = lines.filter(
    (l) => l.trim().startsWith("- [ ]") || l.trim().startsWith("- [x]"),
  );
  const completedTasks = lines.filter((l) => l.trim().startsWith("- [x]"));
  const pendingTaskIndex = lines.findIndex((line) =>
    line.trim().startsWith("- [ ]"),
  );

  if (pendingTaskIndex === -1) {
    console.log(`\n==================================================`);
    console.log(`🎉 [ALL DONE] Semua tugas di TASKS.md (100%) telah selesai!`);
    console.log(`Menutup agent runner... Sampai jumpa! 👋`);
    console.log(`==================================================\n`);
    process.exit(0);
  }

  const total = allTasks.length;
  const done = completedTasks.length;
  const percent = Math.round((done / total) * 100);

  const rawTask = lines[pendingTaskIndex].replace("- [ ]", "").trim();
  const safeTask = rawTask.replace(/"/g, "'").replace(/`/g, "").replace(/&/g, "dan").replace(/</g, " ").replace(/>/g, " ");

  console.log(`\n==================================================`);
  console.log(`🚀 [PROGRESS: ${done}/${total} Task (${percent}%)]`);
  console.log(`⏳ Executing: "${safeTask}"`);
  console.log(`==================================================\n`);

  // --- PERBAIKAN: Parameter isAutoFixMode ---
  function runAIAgent(promptText, isAutoFixMode = false) {
    const startTime = Date.now();
    
    const child = spawn(OPENCODE_CMD, ["run", "--thinking", promptText], {
      cwd: __dirname,
      shell: true,
      stdio: ["inherit", "pipe", "pipe"],
      env: { ...process.env, FORCE_COLOR: "1" },
    });

    let agentOutput = "";

    child.stdout.on("data", (data) => {
      const str = data.toString();
      process.stdout.write(str); 
      agentOutput += str; 
    });

    child.stderr.on("data", (data) => {
      process.stderr.write(data.toString());
    });

    child.on("close", (code) => {
      const duration = ((Date.now() - startTime) / 1000).toFixed(1);
      let fileWritten = false;

      try {
        const cleanOutput = agentOutput.replace(/```json/gi, "").replace(/```dart/gi, "").replace(/```/g, "").trim();
        const startIndex = cleanOutput.indexOf("{");
        const endIndex = cleanOutput.lastIndexOf("}");

        if (startIndex !== -1 && endIndex !== -1) {
          const jsonStr = cleanOutput.substring(startIndex, endIndex + 1);
          const parsed = JSON.parse(jsonStr);

          if (parsed.name === "write" && parsed.arguments) {
            const args = parsed.arguments;
            let targetPath = args.filePath || args.file_path;
            const fileContent = args.content;

            if (targetPath.startsWith("/")) { targetPath = targetPath.substring(1); }

            const absolutePath = path.join(__dirname, targetPath);
            const dirName = path.dirname(absolutePath);

            if (!fs.existsSync(dirName)) { fs.mkdirSync(dirName, { recursive: true }); }
            fs.writeFileSync(absolutePath, fileContent, "utf8");
            console.log(`\n🎯 [SUCCESS] File berhasil di-generate di: ${targetPath}`);
            fileWritten = true;
          }
        }
      } catch (err) {
        // Abaikan peringatan error parsing
      }

      if (code === 0) {
        if (!isAutoFixMode) {
          // JIKA NORMAL MODE: Langsung centang task sebagai selesai
          console.log(`\n✅ [FINISHED in ${duration}s] Task: "${safeTask}"`);
          const currentContent = fs.readFileSync(TASKS_FILE, "utf8");
          const currentLines = currentContent.split("\n");
          const currentPendingIndex = currentLines.findIndex((line) => line.includes(rawTask) && line.trim().startsWith("- [ ]"));

          if (currentPendingIndex !== -1) {
            currentLines[currentPendingIndex] = currentLines[currentPendingIndex].replace("- [ ]", "- [x]");
            fs.writeFileSync(TASKS_FILE, currentLines.join("\n"), "utf8");
          }
        } else {
          // JIKA AUTO-FIX MODE: JANGAN DICENTANG! Biarkan loop meng-test ulang di interval berikutnya
          if (fileWritten) {
            console.log(`\n🔄 [AUTO-FIX APPLIED in ${duration}s] File telah diperbarui. Akan melakukan re-test terminal...`);
          } else {
            console.log(`\n⚠️ [AUTO-FIX FAILED in ${duration}s] AI gagal menulis perbaikan. Mencoba menganalisis ulang...`);
          }
        }
      }

      console.log(`\nMenunggu ${DELAY_BETWEEN_TASKS_MS / 1000} detik sebelum tugas selanjutnya...`);
      setTimeout(processNextTask, DELAY_BETWEEN_TASKS_MS);
    });
  }

  // --- LOGIKA CABANG ---
  if (safeTask.startsWith("[TEST]")) {
    const commandToRun = safeTask.replace("[TEST]", "").trim();
    console.log(`🔍 [TEST MODE] Menjalankan command: ${commandToRun}`);

    exec(commandToRun, { cwd: __dirname }, (error, stdout, stderr) => {
      const outputLog = stdout + "\n" + stderr;

      // Flutter analyze mereturn error atau teks "issue" jika kode bermasalah
      if (error || stdout.toLowerCase().includes("issue") || stderr) {
        console.log(`\n❌ [TEST FAILED] Ditemukan Error! Agen akan mencoba membenahi sendiri...`);
         
        // PROMPT SUPER KETAT: Larang AI membuat file dummy atau mengajak ngobrol
        const autoFixPrompt = `Saya menjalankan command '${commandToRun}' dan mendapat error dari compiler:\n\n${outputLog}\n\nINSTRUKSI SUPER KETAT: Kamu adalah mesin perbaikan kode otomatis. DILARANG BERBICARA. DILARANG membuat file dummy seperti .txt. Kamu WAJIB membaca log error di atas, mencari tahu file .dart mana yang bermasalah, dan menulis ulang kode Dart tersebut agar tidak error. HANYA BALAS DENGAN JSON VALID: {"name": "write", "arguments": {"filePath": "lokasi_file_asli.dart", "content": "kode Dart yang sudah diperbaiki"}}.`;
        runAIAgent(autoFixPrompt, true); // true = Jangan centang TASKS.md setelah AI mikir
      } else {
        console.log(`\n✅ [TEST PASSED] Command berhasil tanpa error!`);
        
        const currentContent = fs.readFileSync(TASKS_FILE, "utf8");
        const currentLines = currentContent.split("\n");
        const currentPendingIndex = currentLines.findIndex((line) => line.includes(rawTask) && line.trim().startsWith("- [ ]"));

        if (currentPendingIndex !== -1) {
          currentLines[currentPendingIndex] = currentLines[currentPendingIndex].replace("- [ ]", "- [x]");
          fs.writeFileSync(TASKS_FILE, currentLines.join("\n"), "utf8");
        }
        
        console.log(`\nMenunggu ${DELAY_BETWEEN_TASKS_MS / 1000} detik sebelum tugas selanjutnya...`);
        setTimeout(processNextTask, DELAY_BETWEEN_TASKS_MS);
      }
    });
  } else {
    const promptText = `Tugas: ${safeTask}. Berikan output dalam format JSON valid (Gunakan Tanda Kutip Ganda). Key "name" bernilai "write", dan "arguments" berisi "filePath" (lokasi file) dan "content" (kode lengkap). Jangan ada teks lain selain JSON.`;
    runAIAgent(promptText, false);
  }
}

processNextTask();