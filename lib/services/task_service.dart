import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TaskService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static Database? _database;
  static Future<Database>? _databaseFuture;

  final StreamController<List<Task>> _tasksController =
      StreamController<List<Task>>.broadcast();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _remoteSubscription;
  String? _activeUid;
  bool _watching = false;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _databaseFuture ??= _openDatabase();
    _database = await _databaseFuture!;
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    return openDatabase(
      p.join(databasePath, 'task_manager.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT NOT NULL,
            userId TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            dueDate TEXT NOT NULL,
            priority TEXT NOT NULL,
            category TEXT NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            syncStatus INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (userId, id)
          )
        ''');
        await db.execute(
          'CREATE INDEX tasks_user_due_date ON tasks(userId, dueDate)',
        );
      },
    );
  }

  CollectionReference<Map<String, dynamic>> get _tasks {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated.');
    }
    return _firestore.collection('users').doc(user.uid).collection('tasks');
  }

  Stream<List<Task>> getTasks() {
    if (!_watching) {
      _watching = true;
      _startWatching();
    }
    return _tasksController.stream;
  }

  void _startWatching() {
    _authSubscription = _auth.authStateChanges().listen((user) async {
      await _remoteSubscription?.cancel();
      _activeUid = user?.uid;

      if (user == null) {
        _tasksController.add([]);
        return;
      }

      await _emitLocalTasks(user.uid);

      _remoteSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .orderBy('dueDate')
          .snapshots()
          .listen(
            (snapshot) async {
              await _applyRemoteSnapshot(user.uid, snapshot);
              await _emitLocalTasks(user.uid);
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Task sync stream error: $error');
              if (!_tasksController.isClosed) {
                _tasksController.addError(error, stackTrace);
              }
            },
          );
    });
  }

  Future<void> _emitLocalTasks(String userId) async {
    final db = await _db;
    final rows = await db.query(
      'tasks',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'dueDate ASC',
    );
    if (!_tasksController.isClosed && _activeUid == userId) {
      _tasksController.add(rows.map(Task.fromLocalMap).toList());
    }
  }

  Future<void> _applyRemoteSnapshot(
    String userId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      final remoteIds = <String>{};

      for (final doc in snapshot.docs) {
        remoteIds.add(doc.id);
        final task = Task.fromFirestore(doc);
        await txn.insert(
          'tasks',
          task.toLocalMap(
            userId: userId,
            syncStatus: doc.metadata.hasPendingWrites ? 1 : 0,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Remove cloud-deleted rows, but retain local writes still awaiting sync.
      final localRows = await txn.query(
        'tasks',
        columns: ['id', 'syncStatus'],
        where: 'userId = ?',
        whereArgs: [userId],
      );

      for (final row in localRows) {
        final id = row['id'] as String;
        final pending = row['syncStatus'] as int;
        if (!remoteIds.contains(id) && pending == 0) {
          await txn.delete(
            'tasks',
            where: 'userId = ? AND id = ?',
            whereArgs: [userId, id],
          );
        }
      }
    });
  }

  Future<void> createTask(Task task) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final doc = task.id.isEmpty ? _tasks.doc() : _tasks.doc(task.id);
    final now = DateTime.now();
    final localTask = task.copyWith(id: doc.id, updatedAt: now);
    final db = await _db;

    await db.insert(
      'tasks',
      localTask.toLocalMap(userId: user.uid, syncStatus: 1),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _emitLocalTasks(user.uid);

    // Firestore persists writes locally and queues them while offline.
    unawaited(
      _writeToCloud(
        doc.set({
          ...localTask.toMap(),
          'createdAt': Timestamp.fromDate(localTask.createdAt),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ),
    );
  }

  Future<void> updateTask(Task task) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final updated = task.copyWith(updatedAt: DateTime.now());
    final db = await _db;
    await db.insert(
      'tasks',
      updated.toLocalMap(userId: user.uid, syncStatus: 1),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _emitLocalTasks(user.uid);

    unawaited(
      _writeToCloud(
        _tasks.doc(task.id).set({
          ...updated.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ),
    );
  }

  Future<void> deleteTask(String taskId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final db = await _db;
    await db.delete(
      'tasks',
      where: 'userId = ? AND id = ?',
      whereArgs: [user.uid, taskId],
    );
    await _emitLocalTasks(user.uid);

    unawaited(_writeToCloud(_tasks.doc(taskId).delete()));
  }

  Future<void> restoreTask(Task task) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final db = await _db;
    await db.insert(
      'tasks',
      task.toLocalMap(userId: user.uid, syncStatus: 1),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _emitLocalTasks(user.uid);

    unawaited(_writeToCloud(_tasks.doc(task.id).set(task.toMap())));
  }

  Future<void> toggleTaskCompletion(Task task) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      updatedAt: DateTime.now(),
    );
    final db = await _db;
    await db.insert(
      'tasks',
      updated.toLocalMap(userId: user.uid, syncStatus: 1),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _emitLocalTasks(user.uid);

    unawaited(
      _writeToCloud(
        _tasks.doc(task.id).update({
          'isCompleted': updated.isCompleted,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ),
    );
  }

  Future<void> _writeToCloud(Future<void> write) async {
    try {
      await write;
    } catch (error) {
      // Keep the local copy. Firestore's offline queue handles connectivity
      // outages; this also prevents an unhandled asynchronous write error.
      debugPrint('Task cloud write failed: $error');
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _remoteSubscription?.cancel();
    _tasksController.close();
  }
}
