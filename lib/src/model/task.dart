class Task {
  final String uniqueId;
  final TaskData? data;
  final int? maxRetryCount;

  Task({
    String? uniqueId,
    this.data,
    this.maxRetryCount,
  })  : assert(maxRetryCount == null || maxRetryCount > 0),
        uniqueId =
            uniqueId ?? (DateTime.now().millisecondsSinceEpoch).toString();

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
  // The existing task is replaced by a new one (only possible if the status is
  // not in running)
  replaced,
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
