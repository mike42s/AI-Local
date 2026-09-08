const markdownParser = require('commonmark');
const taskRegex = /\- \[\] \[(.*)\] (.*)/g;

function parseTasks(fileContent) {
  let match;
  const tasks = {
    pendingTasks: [],
    completedTasks: []
  };

  while ((match = taskRegex.exec(fileContent)) !== null) {
    const status = match[1].trim().toLowerCase();
    const content = match[2].trim();

    if (status === 'pending') {
      tasks.pendingTasks.push(content);
    } else if (status === 'completed') {
      tasks.completedTasks.push(content);
    }
  }

  return tasks;
}

module.exports = { parseTasks };
