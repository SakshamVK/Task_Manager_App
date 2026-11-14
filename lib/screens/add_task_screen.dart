import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  final Task? task;

  const AddTaskScreen({super.key, this.task});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late DateTime _dueDate;
  late TaskPriority _priority;
  late TaskCategory _category;

  bool _isLoading = false;

  bool get isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _titleController = TextEditingController(text: task?.title ?? '');

    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );

    _dueDate = task?.dueDate ?? DateUtils.dateOnly(DateTime.now());
    _priority = task?.priority ?? TaskPriority.medium;
    _category = task?.category ?? TaskCategory.other;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(today) ? today : _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() => _dueDate = selected);
    }
  }

  Future<void> _saveTask() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();

      final task = Task(
        id: widget.task?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        category: _category,
        isCompleted: widget.task?.isCompleted ?? false,
        createdAt: widget.task?.createdAt ?? now,
        updatedAt: now,
      );

      final service = ref.read(taskServiceProvider);

      if (isEditing) {
        await service.updateTask(task);
      } else {
        await service.createTask(task);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Task updated successfully.'
                : 'Task created successfully.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e Unable to save task. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Task' : 'Create Task',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing
                            ? 'Make changes to your task.'
                            : 'What would you like to get done?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 28),

                      _sectionLabel('Task title'),
                      const SizedBox(height: 9),

                      TextFormField(
                        controller: _titleController,
                        autofocus: false,
                        maxLength: 80,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Complete client project',
                          prefixIcon: Icon(Icons.edit_note_rounded),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a task title.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      _sectionLabel('Description'),
                      const SizedBox(height: 9),

                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Add details about your task...',
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 24),

                      _sectionLabel('Category'),
                      const SizedBox(height: 10),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.8,
                        children: TaskCategory.values.map((category) {
                          final selected = _category == category;

                          return _CategoryOption(
                            category: category,
                            selected: selected,
                            onTap: () {
                              setState(() => _category = category);
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 26),

                      _sectionLabel('Due date'),
                      const SizedBox(height: 10),

                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('EEEE').format(_dueDate),
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      DateFormat(
                                        'dd MMMM yyyy',
                                      ).format(_dueDate),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.edit_calendar_outlined,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 26),

                      _sectionLabel('Priority'),
                      const SizedBox(height: 10),

                      SegmentedButton<TaskPriority>(
                        segments: TaskPriority.values.map((priority) {
                          return ButtonSegment<TaskPriority>(
                            value: priority,
                            label: Text(
                              priority.name[0].toUpperCase() +
                                  priority.name.substring(1),
                            ),
                          );
                        }).toList(),
                        selected: {_priority},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          setState(() => _priority = selection.first);
                        },
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _saveTask,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isEditing ? Icons.check_rounded : Icons.add_rounded,
                          ),
                    label: Text(
                      _isLoading
                          ? 'Saving...'
                          : isEditing
                          ? 'Save Changes'
                          : 'Create Task',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  final TaskCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  Color get categoryColor {
    switch (category) {
      case TaskCategory.clientWork:
        return const Color(0xFF625BEE);
      case TaskCategory.delivery:
        return const Color(0xFFEA8B35);
      case TaskCategory.personal:
        return const Color(0xFF22A06B);
      case TaskCategory.other:
        return const Color(0xFF85859A);
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case TaskCategory.clientWork:
        return Icons.work_outline_rounded;
      case TaskCategory.delivery:
        return Icons.delivery_dining_rounded;
      case TaskCategory.personal:
        return Icons.person_outline_rounded;
      case TaskCategory.other:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = categoryColor;

    return Material(
      color: selected
          ? color.withValues(alpha: 0.10)
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? color : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(categoryIcon, size: 19, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
