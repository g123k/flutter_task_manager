import 'package:hive_flutter/hive_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'package:task_manager/src/model/task.dart';
import 'package:task_manager/src/storage/model/hive_task.dart';

class TaskManagerStorage {
  final Lock _lock = Lock();
  late Box<HiveTask> _box;
  bool _initialized = false;

  Future<void> init() async {
    await Hive.initFlutter();

    try {
      Hive.registerAdapter(HiveTaskAdapter());
    } on HiveError {
      // Type already registered
    }

    _box = await Hive.openBox('task_manager_storage');
    _resetStatuses();
    _initialized = true;
  }

  Future<void> _resetStatuses() {
    return _lock.synchronized(() {
      for (HiveTask task in _box.values) {
        if (task.status == TaskStatus.running) {
          _box.put(task.hiveId!, task.cloneWith(status: TaskStatus.added));
        }
      }
    });
  }

  Future<HiveTask> addTask(HiveTask task) async {
    await _ensureInitialized();

    await _lock.synchronized(() async {
      task = task.cloneWith(hiveId: _getMinKey() + 1);
      await _box.put(task.hiveId, task);
    });

    return task;
  }

  Future<HiveTask?> findTaskByUniqueId(
    String taskId, {
    bool lock = false,
  }) async {
    await _ensureInitialized();

    if (lock) {
      return _lock.synchronized(() => _findTaskByUniqueIdInternal(taskId));
    } else {
      return _findTaskByUniqueIdInternal(taskId);
    }
  }

  Future<HiveTask?> _findTaskByUniqueIdInternal(String taskId) async {
    try {
      return _box.values.firstWhere((HiveTask task) => task.uniqueId == taskId);
    } catch (err) {
      return null;
    }
  }

  Future<void> updateTask(HiveTask task) async {
    assert(task.hiveId != null);
    await _ensureInitialized();

    await _lock.synchronized(() async {
      await _box.put(task.hiveId, task);
    });
  }

  Future<void> removeTask(HiveTask task) async {
    await _ensureInitialized();

    await _lock.synchronized(() async {
      await _box.delete(task.hiveId);
    });
  }

  Future<void> clear() async {
    await _ensureInitialized();

    await _lock.synchronized(() async {
      await _box.clear();
    });
  }

  Future<bool> removeTaskById(int taskId) async {
    await _ensureInitialized();

    return await _lock.synchronized(() async {
      HiveTask? task;
      try {
        task = _box.values.firstWhere((HiveTask task) => task.hiveId == taskId);

        await _box.delete(task.hiveId);
        return true;
      } catch (err) {
        return false;
      }
    });
  }

  Future<bool> removeTaskByUniqueId(String taskId) async {
    await _ensureInitialized();

    return await _lock.synchronized(() async {
      HiveTask? task;
      try {
        task =
            _box.values.firstWhere((HiveTask task) => task.uniqueId == taskId);

        await _box.delete(task.hiveId);
        return true;
      } catch (err) {
        return false;
      }
    });
  }

  Future<Iterable<HiveTask>> listPendingTasks() async {
    await _ensureInitialized();

    return _lock.synchronized(
      () => _box.values.where((HiveTask task) {
        if (task.isWaiting) {
          if (task.nextRetryMinDate != null) {
            return task.nextRetryMinDate!.isBefore(DateTime.now());
          } else {
            return true;
          }
        }

        return false;
      }),
      // Order by
    );
  }

  Future<Iterable<HiveTask>> listPublicPendingTasks() async {
    await _ensureInitialized();

    return _lock.synchronized(
      () => _box.values.where((HiveTask task) {
        return [
          TaskStatus.added,
          TaskStatus.errorAndRetry,
        ].contains(task.status);
      }),
    );
  }

  Future<bool> get hasPendingTasks =>
      listPendingTasks().then((value) => value.isNotEmpty);

  int _getMinKey() {
    if (_box.keys.isEmpty) {
      return -1;
    }

    return _box.keys.reduce((dynamic a, dynamic b) {
      if (a is int && b is int) {
        return a > b ? a : b;
      } else {
        return 0;
      }
    });
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }
}
