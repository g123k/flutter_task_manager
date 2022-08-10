import 'package:task_manager/src/model/task.dart';
import 'package:task_manager/src/storage/model/hive_task.dart';
import 'package:task_manager/src/storage/task_manager_storage.dart';
import 'package:task_manager/src/task_manager_logger.dart';
import 'package:task_manager/src/task_manager_runner.dart';
import 'package:workmanager/workmanager.dart';

class TaskManager {
  // Singleton pattern
  static TaskManager? _instance;

  factory TaskManager() {
    _instance ??= TaskManager._internal();
    return _instance!;
  }

  // Task Manager private stuff
  static TaskExecutor? _executor;
  final TaskManagerStorage _storage;
  TaskManagerLogger? _logger;
  TaskManagerListener? _listener;
  TaskManagerRunner? _runner;
  bool? _runTasksInIsolates;

  TaskManager._internal() : _storage = TaskManagerStorage() {
    _storage.init();
  }

  Future<void> init({
    required TaskExecutor executor,
    TaskManagerListener? listener,
    TaskManagerLogger? logger,
    bool runTasksInIsolates = true,
  }) async {
    _executor = executor;
    _logger = logger;
    _runTasksInIsolates = runTasksInIsolates;

    /* Temporary disabled
    await Workmanager().initialize(
      workManagerCallbackDispatcher,
      isInDebugMode: logger != null,
    );*/

    _runner = TaskManagerRunner(executor, _storage, listener, logger);
    // Runner will automatically start at the same time
  }

  Future<int> addTask(Task task) async {
    assert(
      isInitialized == true,
      'Runner is not initialized, please ensure to call the init method!',
    );

    if (_runner?.runningTaskId == task.uniqueId) {
      throw Exception('This task id is already running!');
    }

    TaskStatus status;
    if (await _storage.findTask(task.uniqueId) != null) {
      status = TaskStatus.replaced;
    } else {
      status = TaskStatus.added;
    }

    HiveTask hiveTask = HiveTask.fromTask(
      task,
      runTasksInIsolates: _runTasksInIsolates!,
      taskStatus: status,
    );

    // Always add task to the storage
    hiveTask = await _storage.addTask(hiveTask);
    _listener?.call(hiveTask, status);
    _logger?.call(
      TaskManagerLog.info(
          'New task ${status == TaskStatus.added ? 'added' : 'replaced'}: ${hiveTask.uniqueId}'),
    );

    // WorkManager only used with no connection available and on Android
    String? workManagerId = await _registerTaskWithWorkManager(hiveTask);

    if (workManagerId != null) {
      _storage.updateTask(hiveTask.cloneWith(workManagerId: workManagerId));
    } else if (_runner?.isRunning == false) {
      _runner!.runPendingTasks(task);
    }

    return hiveTask.uniqueId;
  }

  Future<bool> cancelTask(int taskId) async {
    assert(
      isInitialized == true,
      'Runner is not initialized, please ensure to call the init method!',
    );

    if (_runner?.runningTaskId == taskId) {
      throw Exception('This task id is already running!');
    }

    return _runner!.removeTaskId(taskId);
  }

  Future<void> cancelTasks() async {
    assert(
      isInitialized == true,
      'Runner is not initialized, please ensure to call the init method!',
    );

    if (_runner?.isRunning == true) {
      throw Exception('Runner is running, unable to remove tasks!');
    }

    return _runner!.removeAllTasks();
  }

  Future<Iterable<Task>> listPendingTasks() {
    return _storage.listPublicPendingTasks();
  }

  void runTask(int taskId) {
    assert(
      isInitialized == true,
      'Runner is not initialized, please ensure to call the init method!',
    );

    if (_runner?.runningTaskId == taskId) {
      throw Exception('This task is already running');
    }

    _runner!.forceRunTask(taskId);
  }

  Future<String?> _registerTaskWithWorkManager(HiveTask task) async {
    String? id;

    // TODO Find a workaround
    /*if (_runner!.hasConnection != true && Platform.isAndroid) {
      id = task.uniqueId.toString();

      Workmanager().registerOneOffTask(
        id,
        id,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        initialDelay: Duration.zero,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }*/

    return id;
  }

  void stop() {
    _runner?.stop();
  }

  bool get isInitialized => _runner != null;
}

// Entrypoint for WorkManager
void workManagerCallbackDispatcher() {
  Workmanager()
      .executeTask((String taskName, Map<String, dynamic>? inputData) async {
    TaskManager taskManager = TaskManager();

    if (TaskManager._executor != null) {}

    /*if (!taskManager.isInitialized) {
      taskManager.init(executor: (executor) {

      },);
    }

    taskManager._runner!.runTask();*/
    return true;
  });
}
