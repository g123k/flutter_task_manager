typedef TaskManagerLogger = void Function(TaskManagerLog logEvent);

class TaskManagerLog {
  final String message;
  final TaskManagerLogLevel level;
  final dynamic extra;

  TaskManagerLog(
    this.message,
    this.level, {
    this.extra,
  });

  TaskManagerLog.debug(
    this.message, {
    this.extra,
  }) : level = TaskManagerLogLevel.debug;

  TaskManagerLog.info(
    this.message, {
    this.extra,
  }) : level = TaskManagerLogLevel.info;

  TaskManagerLog.warning(
    this.message, {
    this.extra,
  }) : level = TaskManagerLogLevel.warning;

  TaskManagerLog.error(
    this.message, {
    this.extra,
  }) : level = TaskManagerLogLevel.error;
}

enum TaskManagerLogLevel {
  debug,
  info,
  warning,
  error,
}
