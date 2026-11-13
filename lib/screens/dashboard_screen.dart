import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../models/task_model.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  TaskPriority? _priorityFilter;
  String _statusFilter = 'all';

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${task.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(taskServiceProvider).deleteTask(task.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to delete task.')));
      }
    }
  }

  Future<void> _toggleTask(Task task) async {
    try {
      await ref.read(taskServiceProvider).toggleTaskCompletion(task);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to update task.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Task Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load tasks.'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(tasksProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (tasks) {
          final completed = tasks.where((t) => t.isCompleted).length;
          final pending = tasks.length - completed;

          final filteredTasks = tasks.where((task) {
            final matchesPriority =
                _priorityFilter == null || task.priority == _priorityFilter;

            final matchesStatus = switch (_statusFilter) {
              'completed' => task.isCompleted,
              'pending' => !task.isCompleted,
              _ => true,
            };

            return matchesPriority && matchesStatus;
          }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tasksProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Text(
                  'Your productivity starts here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total tasks',
                        count: tasks.length,
                        icon: Icons.assignment_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Pending',
                        count: pending,
                        icon: Icons.pending_actions_outlined,
                        color: AppColors.mediumPriority,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Completed',
                        count: completed,
                        icon: Icons.task_alt_rounded,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Text(
                  'My Tasks',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _statusFilter == 'all',
                      onSelected: () => setState(() => _statusFilter = 'all'),
                    ),
                    _FilterChip(
                      label: 'Pending',
                      selected: _statusFilter == 'pending',
                      onSelected: () =>
                          setState(() => _statusFilter = 'pending'),
                    ),
                    _FilterChip(
                      label: 'Completed',
                      selected: _statusFilter == 'completed',
                      onSelected: () =>
                          setState(() => _statusFilter = 'completed'),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                const Text(
                  'Priority',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _priorityFilter == null,
                      onSelected: () => setState(() => _priorityFilter = null),
                    ),
                    ...TaskPriority.values.map((priority) {
                      return _FilterChip(
                        label: priority.name.toUpperCase(),
                        selected: _priorityFilter == priority,
                        onSelected: () =>
                            setState(() => _priorityFilter = priority),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 20),

                if (filteredTasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(
                          tasks.isEmpty
                              ? Icons.task_alt_outlined
                              : Icons.filter_alt_off_outlined,
                          size: 52,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tasks.isEmpty ? 'No tasks yet' : 'No matching tasks',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tasks.isEmpty
                              ? 'Create your first task to get started.'
                              : 'Try changing your filters.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredTasks.map((task) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TaskCard(
                        task: task,
                        onToggle: () => _toggleTask(task),
                        onEdit: () => context.push('/task', extra: task),
                        onDelete: () => _deleteTask(task),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/task'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
    );
  }
}
