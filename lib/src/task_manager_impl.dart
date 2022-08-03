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

  Future<void> addTask(Task task) async {
    assert(
      isInitialized == true,
      'Runner is not initialized, please ensure to call the init method!',
    );

    HiveTask hiveTask = HiveTask.fromTask(
      task,
      runTasksInIsolates: _runTasksInIsolates!,
    );

    // Always add task to the storage
    hiveTask = await _storage.addTask(hiveTask);
    _listener?.call(hiveTask, TaskStatus.added);
    _logger?.call(TaskManagerLog.info('New task added: ${hiveTask.uniqueId}'));

    // WorkManager only used with no connection available and on Android
    String? workManagerId = await _registerTaskWithWorkManager(hiveTask);

    if (workManagerId != null) {
      _storage.updateTask(hiveTask.cloneWith(workManagerId: workManagerId));
    } else if (_runner?.isRunning == true) {
      _runner!.runPendingTasks(task);
    }
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
