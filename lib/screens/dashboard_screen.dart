import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../models/task_model.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/offline_banner.dart';

const _orange = Color(0xFFEA8B35);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

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

  bool get _hasActiveFilters =>
      _priorityFilter != null ||
      _categoryFilter != null ||
      _statusFilter != 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────── Actions ─────────────────────────

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await ref.read(taskServiceProvider).deleteTask(task.id);
      _showMessage(
        '"${task.title}" deleted',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await ref.read(taskServiceProvider).restoreTask(task);
            } catch (_) {
              _showMessage('Unable to restore task.');
            }
          },
        ),
      );
    } catch (_) {
      _showMessage('Unable to delete task.');
    }
  }

  Future<void> _toggleTask(Task task) async {
    try {
      await ref.read(taskServiceProvider).toggleTaskCompletion(task);
    } catch (_) {
      _showMessage('Unable to update task.');
    }
  }

  // ───────────────────────── Data helpers ─────────────────────────

  List<Task> _filterTasks(List<Task> tasks) {
    final query = _searchController.text.trim().toLowerCase();

    final result = tasks.where((task) {
      final matchesSearch = query.isEmpty ||
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
    }).toList();

    result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  // ───────────────────────── Filter sheet ─────────────────────────

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void update(VoidCallback fn) {
              setState(fn);
              setSheetState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Filters',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _hasActiveFilters
                              ? () => update(() {
                                  _statusFilter = 'all';
                                  _categoryFilter = null;
                                  _priorityFilter = null;
                                })
                              : null,
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const _SheetLabel('Status'),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(
                            value: 'pending',
                            label: Text('Pending'),
                          ),
                          ButtonSegment(value: 'completed', label: Text('Done')),
                        ],
                        selected: {_statusFilter},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) =>
                            update(() => _statusFilter = s.first),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SheetLabel('Category'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterPill(
                          label: 'All',
                          selected: _categoryFilter == null,
                          onTap: () => update(() => _categoryFilter = null),
                        ),
                        ...TaskCategory.values.map(
                          (c) => _FilterPill(
                            label: c.label,
                            selected: _categoryFilter == c,
                            onTap: () => update(() => _categoryFilter = c),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SheetLabel('Priority'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterPill(
                          label: 'All',
                          selected: _priorityFilter == null,
                          onTap: () => update(() => _priorityFilter = null),
                        ),
                        ...TaskPriority.values.map(
                          (p) => _FilterPill(
                            label:
                                p.name[0].toUpperCase() + p.name.substring(1),
                            selected: _priorityFilter == p,
                            onTap: () => update(() => _priorityFilter = p),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ───────────────────────── Header ─────────────────────────

  Widget _buildHeader(List<Task>? tasks) {
    const radius = BorderRadius.vertical(bottom: Radius.circular(30));
    final now = DateTime.now();
    final completed = tasks?.where((t) => t.isCompleted).length ?? 0;
    final total = tasks?.length ?? 0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              left: -50,
              bottom: -70,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _HeaderButton(
                          icon: Icons.grid_view_rounded,
                          tooltip: 'Filters',
                          showBadge: _hasActiveFilters,
                          onTap: _openFilterSheet,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSearchField()),
                        const SizedBox(width: 12),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onSelected: (value) async {
                            if (value == 'logout') {
                              await ref.read(authServiceProvider).signOut();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text('Log out'),
                                ],
                              ),
                            ),
                          ],
                          child: const _HeaderCircle(
                            child: Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Today, ${_formatDate(now)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(
                          child: Text(
                            'My tasks',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (tasks != null)
                          Text(
                            '$completed/$total done',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search tasks',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  // ───────────────────────── Body ─────────────────────────

  List<Widget> _section(String title, List<Task> tasks) {
    if (tasks.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: title == 'Overdue' ? AppColors.error : null,
          ),
        ),
      ),
      for (final task in tasks)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey(task.id),
            direction: DismissDirection.endToStart,
            background: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            onDismissed: (_) => _deleteTask(task),
            child: _TaskTile(
              task: task,
              onToggle: () => _toggleTask(task),
              onTap: () => context.push('/task', extra: task),
            ),
          ),
        ),
    ];
  }

  Widget _buildEmptyState({required bool hasTasks}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
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
                : 'Tap + to create your first task.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskBody(List<Task> tasks) {
    final filtered = _filterTasks(tasks);

    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    bool pending(Task t) => !t.isCompleted;
    DateTime due(Task t) => DateUtils.dateOnly(t.dueDate);

    final overdue = filtered
        .where((t) => pending(t) && due(t).isBefore(today))
        .toList();
    final todayTasks = filtered
        .where((t) => pending(t) && due(t) == today)
        .toList();
    final tomorrowTasks = filtered
        .where((t) => pending(t) && due(t) == tomorrow)
        .toList();
    final thisWeek = filtered
        .where(
          (t) =>
              pending(t) &&
              due(t).isAfter(tomorrow) &&
              !due(t).isAfter(weekEnd),
        )
        .toList();
    final later = filtered
        .where((t) => pending(t) && due(t).isAfter(weekEnd))
        .toList();
    final done = filtered.where((t) => t.isCompleted).toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tasksProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          const OfflineBanner(),
          if (filtered.isEmpty)
            _buildEmptyState(hasTasks: tasks.isNotEmpty)
          else ...[
            ..._section('Overdue', overdue),
            ..._section('Today', todayTasks),
            ..._section('Tomorrow', tomorrowTasks),
            ..._section('This week', thisWeek),
            ..._section('Later', later),
            ..._section('Completed', done),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(tasksAsync.value),
          Expanded(
            child: tasksAsync.when(
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
              data: _buildTaskBody,
            ),
          ),
        ],
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

// ───────────────────────── Components ─────────────────────────

class _TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.isCompleted;
    final priority =
        task.priority.name[0].toUpperCase() + task.priority.name.substring(1);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Opacity(
            opacity: done ? 0.55 : 1,
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: done
                          ? const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(task.dueDate),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Tag(label: task.category.label, color: AppColors.primary),
                const SizedBox(width: 6),
                _Tag(label: priority, color: _orange),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeaderCircle extends StatelessWidget {
  final Widget child;

  const _HeaderCircle({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool showBadge;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _HeaderCircle(child: Icon(icon, color: Colors.white, size: 20)),
            if (showBadge)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
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
}