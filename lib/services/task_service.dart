import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TaskService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _tasks {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    return _firestore.collection('users').doc(user.uid).collection('tasks');
  }

  // Stream all tasks, sorted by due date.
  Stream<List<Task>> getTasks() {
    return _tasks
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList(),
        );
  }

  // Create a new task.
  Future<void> createTask(Task task) async {
    final now = DateTime.now();

    await _tasks.add({
      ...task.toMap(),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  // Update an existing task.
  Future<void> updateTask(Task task) async {
    await _tasks.doc(task.id).update({
      ...task.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete a task.
  Future<void> deleteTask(String taskId) async {
    await _tasks.doc(taskId).delete();
  }

  // Toggle task completion.
  Future<void> toggleTaskCompletion(Task task) async {
    await _tasks.doc(task.id).update({
      'isCompleted': !task.isCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
