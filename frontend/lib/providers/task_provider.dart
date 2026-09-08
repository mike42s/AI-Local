
class Task {
  final String id;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  String status;

  Task({required this.id, required this.description, required this.createdAt, this.updatedAt, required this.status});

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'status': status,
    };
  }
}

class TaskProvider {
  final List<Task> _tasks = [];

  List<Task> get tasks => _tasks;

  void addTask(Task task) {
    _tasks.add(task);
  }

  void updateTaskStatus(String taskId, String newStatus) {
    final task = _tasks.firstWhere((task) => task.id == taskId);
    task.status = newStatus;
  }
}

void main() {
  final taskProvider = TaskProvider();
  final task = Task(id: '1', description: 'Complete feature X', createdAt: DateTime.now(), status: 'in_progress');
  taskProvider.addTask(task);

  // Update task status
  taskProvider.updateTaskStatus('1', 'completed');
}
