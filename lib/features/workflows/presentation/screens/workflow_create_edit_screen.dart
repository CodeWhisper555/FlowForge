import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../shared/layout/responsive_scaffold.dart';
import '../../../activity/domain/models/activity_log.dart';
import '../../../activity/presentation/controllers/activity_providers.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../domain/models/workflow.dart';
import '../../domain/models/workflow_enums.dart';
import '../controllers/workflow_providers.dart';

class WorkflowCreateEditScreen extends ConsumerStatefulWidget {
  final String? workflowId;

  const WorkflowCreateEditScreen({super.key, this.workflowId});

  @override
  ConsumerState<WorkflowCreateEditScreen> createState() => _WorkflowCreateEditScreenState();
}

class _WorkflowCreateEditScreenState extends ConsumerState<WorkflowCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  WorkflowPriority _priority = WorkflowPriority.medium;
  DateTime? _dueDate;
  bool _isLoading = false;
  bool _initialized = false;
  Workflow? _existingWorkflow;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initFromWorkflow(Workflow wf) {
    if (_initialized) return;
    _initialized = true;
    _existingWorkflow = wf;
    _titleController.text = wf.title;
    _descriptionController.text = wf.description;
    _priority = wf.priority;
    _dueDate = wf.dueDate;
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    final now = DateTime.now();

    try {
      if (_existingWorkflow != null) {
        final updated = _existingWorkflow!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null,
          updatedAt: now,
        );
        await ref.read(workflowRepositoryProvider).updateWorkflow(updated);

        await ref.read(activityRepositoryProvider).logActivity(
              ActivityLog(
                id: const Uuid().v4(),
                userId: user.id,
                workflowId: updated.id,
                workflowTitle: updated.title,
                type: ActivityType.workflowEdited,
                description: 'Updated workflow settings for "${updated.title}"',
                timestamp: now,
              ),
            );

        if (mounted) {
          context.pop();
        }
      } else {
        final newWorkflow = Workflow(
          id: const Uuid().v4(),
          userId: user.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          status: WorkflowStatus.active,
          priority: _priority,
          dueDate: _dueDate,
          steps: const [],
          createdAt: now,
          updatedAt: now,
        );

        await ref.read(workflowRepositoryProvider).createWorkflow(newWorkflow);

        await ref.read(activityRepositoryProvider).logActivity(
              ActivityLog(
                id: const Uuid().v4(),
                userId: user.id,
                workflowId: newWorkflow.id,
                workflowTitle: newWorkflow.title,
                type: ActivityType.workflowCreated,
                description: 'Created new workflow "${newWorkflow.title}"',
                timestamp: now,
              ),
            );

        if (mounted) {
          context.go('/workflows/${newWorkflow.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving workflow: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.workflowId != null;

    if (isEditing && !_initialized) {
      final wfAsync = ref.watch(workflowDetailsStreamProvider(widget.workflowId!));
      return wfAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
        data: (wf) {
          if (wf == null) return const Scaffold(body: Center(child: Text('Workflow not found')));
          _initFromWorkflow(wf);
          return _buildForm(context, isEditing: true);
        },
      );
    }

    return _buildForm(context, isEditing: isEditing);
  }

  Widget _buildForm(BuildContext context, {required bool isEditing}) {
    final theme = Theme.of(context);

    return ResponsiveScaffold(
      selectedIndex: 1,
      title: isEditing ? 'Edit Workflow' : 'Create Workflow',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEditing ? 'Workflow Details' : 'Design New Workflow',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set the title, goals, and schedule. You will be able to add ordered and dependent steps next.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Workflow Title',
                          hintText: 'e.g. Develop a College Project',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (v) => FormValidators.requiredField(v, 'Workflow title'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),

                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Brief summary of objectives and deliverables',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 18),

                      // Priority Dropdown
                      DropdownButtonFormField<WorkflowPriority>(
                        value: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: WorkflowPriority.values.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(p.displayName),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _priority = val);
                        },
                      ),
                      const SizedBox(height: 18),

                      // Due Date Picker
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: Text(
                          _dueDate == null
                              ? 'No Due Date Set'
                              : 'Due: ${DateFormat('yyyy-MM-dd').format(_dueDate!)}',
                          style: TextStyle(
                            fontWeight: _dueDate != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_dueDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                tooltip: 'Clear Due Date',
                                onPressed: () => setState(() => _dueDate = null),
                              ),
                            TextButton(
                              onPressed: _pickDueDate,
                              child: Text(_dueDate == null ? 'Set Date' : 'Change'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => context.pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 14),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(isEditing ? 'Save Changes' : 'Create Workflow'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
