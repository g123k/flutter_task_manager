class Task {
  final int uniqueId;
  final TaskData? data;
  final int? maxRetryCount;

  Task({
    int? uniqueId,
    this.data,
    this.maxRetryCount,
  })  : assert(maxRetryCount == null || maxRetryCount > 0),
        uniqueId = uniqueId ?? DateTime.now().millisecondsSinceEpoch;

  @override
  String toString() {
    return 'Task{'
        'id: $uniqueId, '
        'data: $data, '
        'maxRetryCount: $maxRetryCount'
        '}';
  }
}

typedef TaskData = Map<String, dynamic>;

typedef TaskExecutor = Future<TaskResult> Function(Task task);
typedef TaskManagerListener = Function(Task task, TaskStatus status);

enum TaskStatus {
  // Just added (never ran)
  added,
  // Running
  running,
  // Ran at least one time with an error, but will retry later
  errorAndRetry,
  // Ran multiple times but failed, won't be restarted
  error,
  // Successful
  success;
}

enum TaskResult {
  success,
  errorAndRetry,
  errorAndCancel,
}
