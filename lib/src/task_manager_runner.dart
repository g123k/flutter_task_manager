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

  late StreamSubscription<bool> connectivitySubscription;

  bool _running = false;

  TaskManagerRunner(
    this.executor,
    this.storage,
    this.listener,
    this.logger,
  ) : connectivityListener = TaskManagerConnectivityListener() {
    connectivitySubscription =
        TaskManagerConnectivityListener().onConnectivityChanged.listen((event) {
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
        break;
      }

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
    }

    _running = false;
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
    if (!_running) {
      _checkPendingTasks();
    }
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
