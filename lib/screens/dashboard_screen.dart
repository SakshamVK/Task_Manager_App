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
  final TextEditingController _searchController = TextEditingController();

  TaskPriority? _priorityFilter;
  TaskCategory? _categoryFilter;
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await ref.read(taskServiceProvider).deleteTask(task.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('"${task.title}" deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await ref.read(taskServiceProvider).restoreTask(task);
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to restore task.')),
                  );
                }
              },
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to delete task.')));
    }
  }

  Future<void> _toggleTask(Task task) async {
    try {
      await ref.read(taskServiceProvider).toggleTaskCompletion(task);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to update task.')));
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Task> _sortTasks(List<Task> tasks) {
    return [...tasks]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<Task> _filterTasks(List<Task> tasks) {
    final query = _searchController.text.trim().toLowerCase();

    return _sortTasks(
      tasks.where((task) {
        final matchesSearch =
            query.isEmpty ||
            task.title.toLowerCase().contains(query) ||
            task.description.toLowerCase().contains(query);

        final matchesCategory =
            _categoryFilter == null || task.category == _categoryFilter;

        final matchesPriority =
            _priorityFilter == null || task.priority == _priorityFilter;

        final matchesStatus = switch (_statusFilter) {
          'pending' => !task.isCompleted,
          'completed' => task.isCompleted,
          _ => true,
        };

        return matchesSearch &&
            matchesCategory &&
            matchesPriority &&
            matchesStatus;
      }).toList(),
    );
  }

  Widget _sectionHeading(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    return Column(
      children: tasks.map((task) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey(task.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 22),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            onDismissed: (_) => _deleteTask(task),
            child: TaskCard(
              task: task,
              onToggle: () => _toggleTask(task),
              onEdit: () => context.push('/task', extra: task),
              onDelete: () => _deleteTask(task),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _categoryChip('All', null),
          ...TaskCategory.values.map(
            (category) => _categoryChip(category.label, category),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, TaskCategory? category) {
    final selected = _categoryFilter == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) {
          setState(() => _categoryFilter = category);
        },
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        backgroundColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.divider,
        ),
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityFilters() {
    return Wrap(
      spacing: 8,
      children: [
        _priorityChip('All', null),
        ...TaskPriority.values.map(
          (priority) => _priorityChip(
            priority.name[0].toUpperCase() + priority.name.substring(1),
            priority,
          ),
        ),
      ],
    );
  }

  Widget _priorityChip(String label, TaskPriority? priority) {
    final selected = _priorityFilter == priority;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) {
        setState(() => _priorityFilter = priority);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildEmptyState({required bool hasTasks}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            hasTasks ? Icons.search_off_rounded : Icons.task_alt_rounded,
            size: 54,
            color: AppColors.primary.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 14),
          Text(
            hasTasks ? 'No matching tasks' : 'Nothing on your list yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            hasTasks
                ? 'Try adjusting your search or filters.'
                : 'Create your first task and get things done.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummary(int completed, int total) {
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF625BEE), Color(0xFF817AF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Every little step counts.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$completed of $total tasks completed',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Task Manager',
          style: TextStyle(fontWeight: FontWeight.w800),
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
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text('Unable to load tasks.'),
              TextButton(
                onPressed: () => ref.invalidate(tasksProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (tasks) {
          final completedCount = tasks.where((task) => task.isCompleted).length;

          final pendingCount = tasks.length - completedCount;
          final filtered = _filterTasks(tasks);

          final today = DateUtils.dateOnly(DateTime.now());
          final tomorrow = today.add(const Duration(days: 1));

          final overdue = filtered.where(
            (task) =>
                !task.isCompleted &&
                DateUtils.dateOnly(task.dueDate).isBefore(today),
          );

          final todayTasks = filtered.where(
            (task) => !task.isCompleted && _isSameDay(task.dueDate, today),
          );

          final tomorrowTasks = filtered.where(
            (task) => !task.isCompleted && _isSameDay(task.dueDate, tomorrow),
          );

          final upcoming = filtered.where(
            (task) =>
                !task.isCompleted &&
                DateUtils.dateOnly(task.dueDate).isAfter(tomorrow),
          );

          final completedTasks = filtered.where((task) => task.isCompleted);

          final hasVisibleTasks = filtered.isNotEmpty;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tasksProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: [
                Text(
                  '${_greeting()}!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${authServiceProvider.name}!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Let’s make today productive.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                _buildProgressSummary(completedCount, tasks.length),

                const SizedBox(height: 25),

                Row(
                  children: [
                    Expanded(
                      child: _QuickStat(
                        icon: Icons.pending_actions_rounded,
                        label: 'Pending',
                        count: pendingCount,
                        color: const Color(0xFFEA8B35),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickStat(
                        icon: Icons.task_alt_rounded,
                        label: 'Completed',
                        count: completedCount,
                        color: const Color(0xFF22A06B),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                SearchBar(
                  controller: _searchController,
                  hintText: 'Search your tasks...',
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                  ],
                  onChanged: (_) => setState(() {}),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    theme.colorScheme.surface,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.divider),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  'Categories',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _buildCategoryFilters(),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Text(
                      'My Tasks',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length} tasks',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'pending', label: Text('Pending')),
                    ButtonSegment(value: 'completed', label: Text('Done')),
                  ],
                  selected: {_statusFilter},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() => _statusFilter = selection.first);
                  },
                ),

                const SizedBox(height: 18),

                Text(
                  'Priority',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPriorityFilters(),

                if (!hasVisibleTasks) ...[
                  _buildEmptyState(hasTasks: tasks.isNotEmpty),
                ] else ...[
                  if (overdue.isNotEmpty) ...[
                    _sectionHeading('Overdue', overdue.length),
                    _buildTaskList(overdue.toList()),
                  ],

                  if (todayTasks.isNotEmpty) ...[
                    _sectionHeading('Today', todayTasks.length),
                    _buildTaskList(todayTasks.toList()),
                  ],

                  if (tomorrowTasks.isNotEmpty) ...[
                    _sectionHeading('Tomorrow', tomorrowTasks.length),
                    _buildTaskList(tomorrowTasks.toList()),
                  ],

                  if (upcoming.isNotEmpty) ...[
                    _sectionHeading('Upcoming', upcoming.length),
                    _buildTaskList(upcoming.toList()),
                  ],

                  if (completedTasks.isNotEmpty) ...[
                    _sectionHeading('Completed', completedTasks.length),
                    _buildTaskList(completedTasks.toList()),
                  ],
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/task'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Task'),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
