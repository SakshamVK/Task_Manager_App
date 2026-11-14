import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_model.dart';
import '../services/task_service.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  final service = TaskService();
  ref.onDispose(service.dispose);
  return service;
});

final tasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskServiceProvider).getTasks();
});
