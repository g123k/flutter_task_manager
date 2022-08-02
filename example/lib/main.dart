import 'dart:async';

import 'package:flutter/material.dart';
import 'package:task_manager/task_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  TaskStatus? _status;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    await TaskManager().init(executor: (Task task) async {
      await Future.delayed(const Duration(seconds: 5));
      return TaskResult.success;
    }, listener: (Task task, TaskStatus status) {
      setState(() {
        _status = status;
      });
    });

    await TaskManager().addTask(Task(data: {
      'attr1': 'value1',
      'attr2': 2,
    }));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Task status : ${_status.toString()}'),
        ),
      ),
    );
  }
}
