import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:task_manager/src/connectivity/task_manager_connectivity_listener.dart';
import 'package:task_manager/src/model/task.dart';
import 'package:task_manager/src/storage/model/hive_task.dart';
import 'package:task_manager/src/storage/task_manager_storage.dart';
import 'package:task_manager/src/task_manager_logger.dart';

class TaskManagerRunner {
  static const _maxRetries = 5;
  static const Iterable<Duration> _errorWindows = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 6),
    Duration(days: 1),
  ];

  final TaskManagerStorage? storage;
  final TaskManagerConnectivityListener connectivityListener;
  final TaskExecutor? executor;
  final TaskManagerListener? listener;
  final TaskManagerLogger? logger;
  final List<int> _tasksToIgnore = <int>[];

  late StreamSubscription<bool> connectivitySubscription;

  bool? _isConnected;
  bool _running = false;
  int? _runningTaskId;

  TaskManagerRunner(
    this.executor,
    this.storage,
    this.listener,
    this.logger,
  ) : connectivityListener = TaskManagerConnectivityListener() {
    connectivitySubscription =
        TaskManagerConnectivityListener().onConnectivityChanged.listen((event) {
      _isConnected = event;
      if (event) {
        _checkPendingTasks();
      } else {
        _stopRunningTasks();
      }
    });

    logger?.call(TaskManagerLog.info('Connectivity listener started'));
    logger?.call(TaskManagerLog.info('Task Manager successfully started'));
  }

  bool get isRunning => _running;

  int? get runningTaskId => _runningTaskId;

  bool get hasConnection => connectivityListener.isConnectionAvailable;

  void stop() {
    logger?.call(TaskManagerLog.info('Connectivity listener stopped'));
    connectivitySubscription.cancel();

    logger?.call(TaskManagerLog.info('Task Manager successfully stopped'));
  }

  Future<void> _checkPendingTasks() async {
    if (_running) {
      return;
    }

    _running = true;

    Iterable<HiveTask> tasks = await storage!.listPendingTasks();
    for (HiveTask task in tasks) {
      if (!_running) {
        _runningTaskId = null;
        break;
      } else if (_tasksToIgnore.contains(task.hiveId)) {
        continue;
      }

      _runningTaskId = task.uniqueId;
      listener?.call(task, TaskStatus.running);

      try {
        await _markTaskAsRunning(task);
        _TaskData taskData = _TaskData(executor: executor!, task: task);

        final TaskResult result;
        if (task.runInAnIsolate) {
          result = await compute(_runTask, taskData);
        } else {
          result = await _runTask(taskData);
        }

        if (result == TaskResult.success) {
          await _markTaskAsSuccessful(task);
        } else {
          await _onTaskError(task, result: result);
        }
      } catch (err) {
        await _onTaskError(task, exception: err);
      }

      _runningTaskId = null;
    }

    _tasksToIgnore.clear();
    _running = false;

    if (await storage?.hasPendingTasks == true) {
      return _checkPendingTasks();
    }
  }

  Future<void> _onTaskError(
    HiveTask task, {
    Object? exception,
    TaskResult? result,
  }) async {
    await _markTaskAsError(task, exception, result);
  }

  Future<HiveTask> _markTaskAsRunning(HiveTask task) async {
    HiveTask hTask = task.cloneWith(
      status: TaskStatus.running,
    );

    await storage!.updateTask(hTask);

    listener?.call(hTask, TaskStatus.running);

    return hTask;
  }

  Future<void> _markTaskAsSuccessful(HiveTask task) async {
    await storage!.removeTask(task);
    listener?.call(task, TaskStatus.success);
  }

  Future<void> _markTaskAsError(
    HiveTask task,
    Object? err,
    TaskResult? result,
  ) async {
    final int retries = task.currentRetryCount + 1;
    final HiveTask hTask;

    if (retries > (task.maxRetryCount ?? _maxRetries) &&
        result != TaskResult.errorAndCancel) {
      hTask = task.cloneWith(
        currentRetryCount: retries,
        nextRetryMinDate: DateTime.now().add(
          _errorWindows.elementAt(retries - 1),
        ),
        status: TaskStatus.errorAndRetry,
      );
    } else {
      hTask = task.cloneWith(
        currentRetryCount: retries,
        status: TaskStatus.error,
      );
    }

    await storage!.updateTask(hTask);

    listener?.call(hTask, hTask.status);
  }

  void _stopRunningTasks() {
    _running = false;
  }

  void runPendingTasks(Task task) {
    if (!_running && _isConnected == true) {
      _checkPendingTasks();
    }
  }

  Future<bool> removeTaskId(int taskId) async {
    HiveTask? task = await storage?.findTaskByUniqueId(taskId, lock: true);

    if (task == null) {
      return false;
    }

    if (_running) {
      _tasksToIgnore.add(task.hiveId!);
    }

    await storage?.removeTask(task);
    return true;
  }

  Future<void> removeAllTasks() async {
    _tasksToIgnore.clear();
    return storage?.clear();
  }
}

Future<TaskResult> _runTask(_TaskData data) async {
  return data.executor.call(data.task);
}

class _TaskData {
  final HiveTask task;
  final TaskExecutor executor;

  _TaskData({
    required this.task,
    required this.executor,
  });
}
