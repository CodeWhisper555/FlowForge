import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/validators/form_validators.dart';
import '../../domain/engine/workflow_engine.dart';
import '../../domain/models/workflow.dart';
import '../../domain/models/workflow_enums.dart';
import '../../domain/models/workflow_step.dart';

class StepEditDialog extends StatefulWidget {
  final Workflow workflow;
  final WorkflowStep? existingStep;
  final WorkflowEngine engine;

  const StepEditDialog({
    super.key,
    required this.workflow,
    this.existingStep,
    this.engine = const WorkflowEngine(),
  });

  static Future<WorkflowStep?> show(
    BuildContext context, {
    required Workflow workflow,
    WorkflowStep? existingStep,
  }) {
    return showDialog<WorkflowStep>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StepEditDialog(
        workflow: workflow,
        existingStep: existingStep,
      ),
    );
  }

  @override
  State<StepEditDialog> createState() => _StepEditDialogState();
}

class _StepEditDialogState extends State<StepEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late List<String> _selectedPrereqIds;
  DateTime? _dueDate;
  String? _validationWarning;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingStep?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingStep?.description ?? '');
    _selectedPrereqIds = List.from(widget.existingStep?.prerequisiteIds ?? const []);
    _dueDate = widget.existingStep?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _togglePrerequisite(String stepId) {
    setState(() {
      _validationWarning = null;
      if (_selectedPrereqIds.contains(stepId)) {
        _selectedPrereqIds.remove(stepId);
      } else {
        // Test cycle before adding
        final testCandidateStepId = widget.existingStep?.id ?? 'temp-new-step';
        final candidatePrereqs = [..._selectedPrereqIds, stepId];

        final testSteps = widget.workflow.steps.map((s) {
          if (s.id == testCandidateStepId) {
            return s.copyWith(prerequisiteIds: candidatePrereqs);
          }
          return s;
        }).toList();

        if (widget.existingStep == null) {
          testSteps.add(
            WorkflowStep(
              id: testCandidateStepId,
              title: 'Candidate',
              order: widget.workflow.steps.length,
              prerequisiteIds: candidatePrereqs,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        final cycle = widget.engine.detectCycle(testSteps);
        if (cycle.isNotEmpty) {
          _validationWarning =
              'Cannot add dependency: It creates a circular cycle (${cycle.join(' -> ')})';
          return;
        }

        _selectedPrereqIds.add(stepId);
      }
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final stepId = widget.existingStep?.id ?? const Uuid().v4();
    final order = widget.existingStep?.order ?? widget.workflow.steps.length;

    final result = WorkflowStep(
      id: stepId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      order: order,
      status: widget.existingStep?.status ??
          (_selectedPrereqIds.isEmpty ? StepStatus.ready : StepStatus.pending),
      prerequisiteIds: _selectedPrereqIds,
      dueDate: _dueDate,
      createdAt: widget.existingStep?.createdAt ?? now,
      updatedAt: now,
      completedAt: widget.existingStep?.completedAt,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherSteps = widget.workflow.steps
        .where((s) => s.id != widget.existingStep?.id)
        .toList();

    return AlertDialog(
      title: Text(widget.existingStep == null ? 'Add Step' : 'Edit Step'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Step Title',
                    hintText: 'e.g. Planning, Testing',
                  ),
                  validator: (v) => FormValidators.requiredField(v, 'Step title'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'What needs to be done in this step?',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Due Date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dueDate == null
                            ? 'No Due Date'
                            : 'Due: ${DateFormat('yyyy-MM-dd').format(_dueDate!)}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    if (_dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _dueDate = null),
                      ),
                    TextButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text(_dueDate == null ? 'Set Due Date' : 'Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Prerequisites Selection
                Text(
                  'Prerequisites (Dependencies)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This step will remain Pending until all selected prerequisites are Completed.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),

                if (_validationWarning != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _validationWarning!,
                      style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (otherSteps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No other steps in this workflow to depend on.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: otherSteps.map((other) {
                      final isSelected = _selectedPrereqIds.contains(other.id);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(other.title),
                        avatar: isSelected
                            ? const Icon(Icons.check, size: 16)
                            : const Icon(Icons.link, size: 16),
                        onSelected: (_) => _togglePrerequisite(other.id),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.existingStep == null ? 'Add Step' : 'Update Step'),
        ),
      ],
    );
  }
}
