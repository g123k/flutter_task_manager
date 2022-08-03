import 'package:hive/hive.dart';
import 'package:task_manager/src/model/task.dart';
import 'package:task_manager/src/utils/task_manager_utils.dart';

class HiveTask extends Task {
  final int? hiveId;
  final String? workManagerId;
  final DateTime dateAddedEvent;
  final DateTime lastEvent;
  final DateTime? nextRetryMinDate;
  final TaskStatus status;
  final int currentRetryCount;
  final bool runInAnIsolate;

  HiveTask.fromTask(
    Task task, {
    this.hiveId,
    this.workManagerId,
    bool runTasksInIsolates = true,
  })  : dateAddedEvent = DateTime.now(),
        lastEvent = DateTime.now(),
        nextRetryMinDate = null,
        status = TaskStatus.added,
        currentRetryCount = 0,
        runInAnIsolate = runTasksInIsolates,
        super(
          uniqueId: task.uniqueId,
          data: task.data,
          maxRetryCount: task.maxRetryCount,
        );

  HiveTask._({
    required int uniqueId,
    this.hiveId,
    this.workManagerId,
    TaskData? data,
    required this.dateAddedEvent,
    required this.currentRetryCount,
    required this.nextRetryMinDate,
    int? maxRetryCount,
    required this.lastEvent,
    required this.status,
    required this.runInAnIsolate,
  }) : super(
          uniqueId: uniqueId,
          data: data,
          maxRetryCount: maxRetryCount,
        );

  HiveTask cloneWith({
    int? hiveId,
    DateTime? lastEvent,
    DateTime? nextRetryMinDate,
    String? workManagerId,
    int? currentRetryCount,
    int? maxRetryCount,
    TaskStatus? status,
    bool? runInAnIsolate,
  }) {
    return HiveTask._(
      hiveId: hiveId ?? this.hiveId,
      uniqueId: uniqueId,
      workManagerId: workManagerId ?? this.workManagerId,
      data: data,
      dateAddedEvent: dateAddedEvent,
      nextRetryMinDate: nextRetryMinDate ?? this.nextRetryMinDate,
      currentRetryCount: currentRetryCount ?? this.currentRetryCount,
      maxRetryCount: maxRetryCount ?? this.maxRetryCount,
      lastEvent: lastEvent ?? DateTime.now(),
      status: status ?? this.status,
      runInAnIsolate: runInAnIsolate ?? this.runInAnIsolate,
    );
  }

  bool get isManagedByWorkManager => workManagerId != null;

  bool get isWaiting =>
      [
        TaskStatus.added,
        TaskStatus.errorAndRetry,
      ].contains(status) &&
      (nextRetryMinDate == null || nextRetryMinDate!.isBefore(DateTime.now()));
}

class HiveTaskAdapter extends TypeAdapter<HiveTask> {
  @override
  HiveTask read(BinaryReader reader) {
    return HiveTask._(
      uniqueId: reader.readInt(),
      data: _readMap(reader),
      maxRetryCount: reader.readInt().let((int value) {
        if (value == -1) {
          return null;
        } else {
          return value;
        }
      }),
      hiveId: reader.readInt().let((int value) {
        if (value == -1) {
          return null;
        } else {
          return value;
        }
      }),
      workManagerId: reader.readString().let((String value) {
        if (value.isEmpty) {
          return null;
        } else {
          return value;
        }
      }),
      dateAddedEvent: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      lastEvent: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      nextRetryMinDate: reader.readInt().let((int value) {
        if (value == -1) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        } else {
          return null;
        }
      }),
      status: TaskStatus.values[reader.readInt()],
      currentRetryCount: reader.readInt(),
      runInAnIsolate: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, HiveTask obj) {
    writer.writeInt(obj.uniqueId);
    _writeMap(writer, obj.data ?? <String, dynamic>{});
    writer.writeInt(obj.maxRetryCount ?? -1);
    writer.writeInt(obj.hiveId ?? -1);
    writer.writeString(obj.workManagerId ?? '');
    writer.writeInt(obj.dateAddedEvent.millisecondsSinceEpoch);
    writer.writeInt(obj.lastEvent.millisecondsSinceEpoch);
    writer.writeInt(obj.nextRetryMinDate?.millisecondsSinceEpoch ?? -1);
    writer.writeInt(obj.status.index);
    writer.writeInt(obj.currentRetryCount);
    writer.writeBool(obj.runInAnIsolate);
  }

  Map<String, dynamic> _readMap(BinaryReader reader) {
    String value = reader.readString();
    if (value != '--- Start') {
      throw Exception('Unknown type!');
    }

    Map<String, dynamic> map = <String, dynamic>{};
    while (true) {
      dynamic value = reader.readString();

      if (value == '--- End') {
        break;
      } else {
        map[value] = reader.read();
      }
    }

    return map;
  }

  void _writeMap(BinaryWriter writer, Map<String, dynamic> map) {
    writer.writeString('--- Start');

    for (String key in map.keys) {
      writer.writeString(key);
      writer.write(map[key]);
    }

    writer.writeString('--- End');
  }

  @override
  int get typeId => 200;
}
