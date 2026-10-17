import 'package:workflow_manager/core/errors/workflow_exceptions.dart';
import '../models/workflow.dart';
import '../models/workflow_enums.dart';
import '../models/workflow_step.dart';

class StepPrerequisiteSummary {
  final List<WorkflowStep> satisfiedPrerequisites;
  final List<WorkflowStep> pendingPrerequisites;

  const StepPrerequisiteSummary({
    required this.satisfiedPrerequisites,
    required this.pendingPrerequisites,
  });

  bool get areAllSatisfied => pendingPrerequisites.isEmpty;

  String get waitingReason {
    if (pendingPrerequisites.isEmpty) return '';
    final titles = pendingPrerequisites.map((s) => '"${s.title}"').join(', ');
    return 'Waiting for $titles to be completed';
  }
}

class WorkflowEngine {
  const WorkflowEngine();

  /// Validates step IDs, prerequisites validity, self-dependencies, and cycles.
  void validateWorkflow(Workflow workflow) {
    final stepIds = <String>{};
    final stepMap = <String, WorkflowStep>{};

    for (final step in workflow.steps) {
      if (stepIds.contains(step.id)) {
        throw WorkflowException(
          'Duplicate step ID detected: ${step.id}',
          code: 'DUPLICATE_STEP_ID',
        );
      }
      stepIds.add(step.id);
      stepMap[step.id] = step;
    }

    for (final step in workflow.steps) {
      final seenPrereqs = <String>{};
      for (final prereqId in step.prerequisiteIds) {
        if (prereqId == step.id) {
          throw InvalidDependencyException(
            'Step "${step.title}" (${step.id}) cannot depend on itself.',
            code: 'SELF_DEPENDENCY',
          );
        }
        if (seenPrereqs.contains(prereqId)) {
          throw InvalidDependencyException(
            'Step "${step.title}" has duplicate dependency on $prereqId.',
            code: 'DUPLICATE_DEPENDENCY',
          );
        }
        seenPrereqs.add(prereqId);

        if (!stepMap.containsKey(prereqId)) {
          throw InvalidDependencyException(
            'Step "${step.title}" references non-existent prerequisite step: $prereqId.',
            code: 'MISSING_DEPENDENCY',
          );
        }
      }
    }

    // Detect cycles using graph DFS
    final cycle = detectCycle(workflow.steps);
    if (cycle.isNotEmpty) {
      throw CycleDetectedException(cycle);
    }
  }

  /// Detects circular dependencies using DFS graph coloring.
  /// Returns the cycle path if found, or an empty list if acyclic.
  List<String> detectCycle(List<WorkflowStep> steps) {
    final adjacency = <String, List<String>>{};
    for (final step in steps) {
      adjacency[step.id] = List.from(step.prerequisiteIds);
    }

    // 0: unvisited, 1: visiting, 2: visited
    final visitState = <String, int>{};
    final parent = <String, String>{};
    List<String>? foundCycle;

    bool dfs(String u) {
      visitState[u] = 1;
      final neighbors = adjacency[u] ?? const [];
      for (final v in neighbors) {
        if (!adjacency.containsKey(v)) continue;
        if (visitState[v] == 1) {
          // Cycle found! Reconstruct cycle path
          final cycle = <String>[v, u];
          var curr = u;
          while (parent.containsKey(curr) && parent[curr] != v) {
            curr = parent[curr]!;
            cycle.add(curr);
          }
          foundCycle = cycle.reversed.toList();
          return true;
        } else if (visitState[v] == null || visitState[v] == 0) {
          parent[v] = u;
          if (dfs(v)) return true;
        }
      }
      visitState[u] = 2;
      return false;
    }

    for (final step in steps) {
      if (visitState[step.id] == null || visitState[step.id] == 0) {
        if (dfs(step.id)) {
          return foundCycle ?? [];
        }
      }
    }

    return const [];
  }

  /// Evaluates prerequisite satisfaction for a given step in a workflow.
  StepPrerequisiteSummary getPrerequisiteSummary(
    Workflow workflow,
    String stepId,
  ) {
    final stepMap = {for (final s in workflow.steps) s.id: s};
    final step = stepMap[stepId];
    if (step == null) {
      throw WorkflowException('Step not found: $stepId', code: 'STEP_NOT_FOUND');
    }

    final satisfied = <WorkflowStep>[];
    final pending = <WorkflowStep>[];

    for (final prereqId in step.prerequisiteIds) {
      final prereq = stepMap[prereqId];
      if (prereq == null || prereq.status != StepStatus.completed) {
        if (prereq != null) {
          pending.add(prereq);
        }
      } else {
        satisfied.add(prereq);
      }
    }

    return StepPrerequisiteSummary(
      satisfiedPrerequisites: satisfied,
      pendingPrerequisites: pending,
    );
  }

  /// Recalculates all step statuses in the workflow following progression rules.
  /// Idempotent: running multiple times yields the same result.
  Workflow recalculateWorkflow(Workflow workflow) {
    validateWorkflow(workflow);

    final stepMap = {for (final s in workflow.steps) s.id: s};
    final updatedSteps = <WorkflowStep>[];
    final now = DateTime.now();

    for (final step in workflow.steps) {
      final allPrereqsMet = step.prerequisiteIds.every(
        (id) => stepMap[id]?.status == StepStatus.completed,
      );

      var newStatus = step.status;

      switch (step.status) {
        case StepStatus.pending:
          if (allPrereqsMet) {
            newStatus = StepStatus.ready;
          }
          break;

        case StepStatus.ready:
          if (!allPrereqsMet) {
            // Prerequisite was reopened or is no longer complete
            newStatus = StepStatus.pending;
          }
          break;

        case StepStatus.inProgress:
          if (!allPrereqsMet) {
            // Prerequisite no longer met: cannot remain inProgress
            newStatus = StepStatus.pending;
          }
          break;

        case StepStatus.blocked:
          // Remains blocked until user manually unblocks
          break;

        case StepStatus.cancelled:
          // Remains cancelled until user manually reopens
          break;

        case StepStatus.completed:
          // Completed steps retain completed status during automatic recalculation
          break;
      }

      if (newStatus != step.status) {
        updatedSteps.add(
          step.copyWith(
            status: newStatus,
            updatedAt: now,
          ),
        );
      } else {
        updatedSteps.add(step);
      }
    }

    return _syncWorkflowState(workflow.copyWith(steps: updatedSteps));
  }

  /// Transitions a step to a new status with validation and downstream recalculation.
  Workflow updateStepStatus(
    Workflow workflow,
    String stepId,
    StepStatus targetStatus, {
    bool resetCompletedDescendants = false,
  }) {
    validateWorkflow(workflow);

    final stepIndex = workflow.steps.indexWhere((s) => s.id == stepId);
    if (stepIndex == -1) {
      throw WorkflowException('Step not found: $stepId', code: 'STEP_NOT_FOUND');
    }

    final currentStep = workflow.steps[stepIndex];
    if (currentStep.status == targetStatus) {
      return workflow;
    }

    final prereqSummary = getPrerequisiteSummary(workflow, stepId);

    // Validate permitted transitions
    _validateTransition(
      currentStep: currentStep,
      targetStatus: targetStatus,
      prereqSummary: prereqSummary,
    );

    final now = DateTime.now();
    var updatedSteps = List<WorkflowStep>.from(workflow.steps);

    // If reopening a completed step, handle downstream steps
    if (currentStep.status == StepStatus.completed &&
        (targetStatus == StepStatus.ready ||
            targetStatus == StepStatus.inProgress ||
            targetStatus == StepStatus.pending)) {
      if (resetCompletedDescendants) {
        final downstreamIds = getDownstreamStepIds(workflow, stepId);
        updatedSteps = updatedSteps.map((s) {
          if (downstreamIds.contains(s.id) && s.status == StepStatus.completed) {
            return s.copyWith(
              status: StepStatus.pending,
              clearCompletedAt: true,
              updatedAt: now,
            );
          }
          return s;
        }).toList();
      }
    }

    final updatedStep = currentStep.copyWith(
      status: targetStatus,
      updatedAt: now,
      completedAt: targetStatus == StepStatus.completed
          ? (currentStep.completedAt ?? now)
          : null,
      clearCompletedAt: targetStatus != StepStatus.completed,
    );

    updatedSteps[stepIndex] = updatedStep;

    final updatedWorkflow = workflow.copyWith(
      steps: updatedSteps,
      updatedAt: now,
    );

    return recalculateWorkflow(updatedWorkflow);
  }

  void _validateTransition({
    required WorkflowStep currentStep,
    required StepStatus targetStatus,
    required StepPrerequisiteSummary prereqSummary,
  }) {
    final from = currentStep.status;

    switch (targetStatus) {
      case StepStatus.ready:
        if (!prereqSummary.areAllSatisfied) {
          throw InvalidTransitionException(
            fromStatus: from.displayName,
            toStatus: targetStatus.displayName,
            reason: prereqSummary.waitingReason,
          );
        }
        break;

      case StepStatus.inProgress:
        if (from == StepStatus.pending && !prereqSummary.areAllSatisfied) {
          throw InvalidTransitionException(
            fromStatus: from.displayName,
            toStatus: targetStatus.displayName,
            reason: prereqSummary.waitingReason,
          );
        }
        break;

      case StepStatus.completed:
        if (from == StepStatus.pending && !prereqSummary.areAllSatisfied) {
          throw InvalidTransitionException(
            fromStatus: from.displayName,
            toStatus: targetStatus.displayName,
            reason:
                'Cannot complete step while prerequisites are pending. ${prereqSummary.waitingReason}',
          );
        }
        break;

      case StepStatus.blocked:
        if (from == StepStatus.completed) {
          throw InvalidTransitionException(
            fromStatus: from.displayName,
            toStatus: targetStatus.displayName,
            reason: 'Completed step cannot be directly marked as blocked without reopening.',
          );
        }
        break;

      case StepStatus.cancelled:
        break;

      case StepStatus.pending:
        break;
    }
  }

  /// Returns set of all downstream step IDs that depend directly or indirectly on [stepId].
  Set<String> getDownstreamStepIds(Workflow workflow, String stepId) {
    final downstreamMap = <String, List<String>>{};
    for (final s in workflow.steps) {
      for (final p in s.prerequisiteIds) {
        downstreamMap.putIfAbsent(p, () => []).add(s.id);
      }
    }

    final result = <String>{};
    void collect(String id) {
      final children = downstreamMap[id] ?? const [];
      for (final child in children) {
        if (result.add(child)) {
          collect(child);
        }
      }
    }

    collect(stepId);
    return result;
  }

  /// Adds a step to the workflow, ensuring no validation or cycle violations.
  Workflow addStep(Workflow workflow, WorkflowStep newStep) {
    final newSteps = List<WorkflowStep>.from(workflow.steps)..add(newStep);
    final candidate = workflow.copyWith(
      steps: newSteps,
      updatedAt: DateTime.now(),
    );
    validateWorkflow(candidate);
    return recalculateWorkflow(candidate);
  }

  /// Updates an existing step in the workflow, re-validating dependencies.
  Workflow updateStep(Workflow workflow, WorkflowStep updatedStep) {
    final index = workflow.steps.indexWhere((s) => s.id == updatedStep.id);
    if (index == -1) {
      throw WorkflowException('Step not found: ${updatedStep.id}', code: 'STEP_NOT_FOUND');
    }
    final newSteps = List<WorkflowStep>.from(workflow.steps);
    newSteps[index] = updatedStep.copyWith(updatedAt: DateTime.now());

    final candidate = workflow.copyWith(
      steps: newSteps,
      updatedAt: DateTime.now(),
    );
    validateWorkflow(candidate);
    return recalculateWorkflow(candidate);
  }

  /// Deletes a step safely.
  /// If [cascadeRemoveDependencies] is false and dependent steps exist, throws an exception.
  /// If true, removes this step ID from all dependent steps' prerequisite lists.
  Workflow deleteStep(
    Workflow workflow,
    String stepId, {
    bool cascadeRemoveDependencies = false,
  }) {
    final dependentSteps = workflow.steps
        .where((s) => s.prerequisiteIds.contains(stepId))
        .map((s) => s.id)
        .toList();

    if (dependentSteps.isNotEmpty && !cascadeRemoveDependencies) {
      throw WorkflowException(
        'Cannot delete step "$stepId" because steps $dependentSteps depend on it.',
        code: 'DEPENDENT_STEPS_EXIST',
        details: dependentSteps,
      );
    }

    final newSteps = workflow.steps
        .where((s) => s.id != stepId)
        .map((s) => s.prerequisiteIds.contains(stepId)
            ? s.copyWith(
                prerequisiteIds:
                    s.prerequisiteIds.where((id) => id != stepId).toList(),
              )
            : s)
        .toList();

    // Re-index orders
    final reorderedSteps = <WorkflowStep>[];
    for (var i = 0; i < newSteps.length; i++) {
      reorderedSteps.add(newSteps[i].copyWith(order: i));
    }

    final candidate = workflow.copyWith(
      steps: reorderedSteps,
      updatedAt: DateTime.now(),
    );
    validateWorkflow(candidate);
    return recalculateWorkflow(candidate);
  }

  /// Syncs overall workflow completion state.
  Workflow _syncWorkflowState(Workflow workflow) {
    if (workflow.status == WorkflowStatus.archived) {
      return workflow;
    }

    // "Do not mark an empty workflow as completed automatically"
    final shouldBeCompleted =
        workflow.steps.isNotEmpty && workflow.steps.every((s) => s.status == StepStatus.completed);

    if (shouldBeCompleted) {
      return workflow.copyWith(
        status: WorkflowStatus.completed,
        completedAt: workflow.completedAt ?? DateTime.now(),
      );
    } else {
      return workflow.copyWith(
        status: WorkflowStatus.active,
        clearCompletedAt: true,
      );
    }
  }
}
