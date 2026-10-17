import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_manager/core/errors/workflow_exceptions.dart';
import 'package:workflow_manager/features/workflows/domain/engine/workflow_engine.dart';
import 'package:workflow_manager/features/workflows/domain/models/workflow.dart';
import 'package:workflow_manager/features/workflows/domain/models/workflow_enums.dart';
import 'package:workflow_manager/features/workflows/domain/models/workflow_step.dart';

void main() {
  const engine = WorkflowEngine();
  final now = DateTime(2025, 1, 1);

  Workflow createWorkflow({List<WorkflowStep> steps = const []}) {
    return Workflow(
      id: 'wf-1',
      userId: 'user-1',
      title: 'College Project',
      description: 'Develop a College Project',
      status: WorkflowStatus.active,
      priority: WorkflowPriority.high,
      steps: steps,
      createdAt: now,
      updatedAt: now,
    );
  }

  WorkflowStep makeStep(
    String id,
    String title, {
    List<String> prereqs = const [],
    StepStatus status = StepStatus.pending,
    int order = 0,
  }) {
    return WorkflowStep(
      id: id,
      title: title,
      order: order,
      status: status,
      prerequisiteIds: prereqs,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('WorkflowEngine - Validation & Cycle Detection', () {
    test('Duplicate step IDs throw WorkflowException', () {
      final wf = createWorkflow(steps: [
        makeStep('step-1', 'Step 1'),
        makeStep('step-1', 'Step 1 Duplicate'),
      ]);
      expect(() => engine.validateWorkflow(wf), throwsA(isA<WorkflowException>()));
    });

    test('Self-dependencies throw InvalidDependencyException', () {
      final wf = createWorkflow(steps: [
        makeStep('step-1', 'Self depending step', prereqs: ['step-1']),
      ]);
      expect(() => engine.validateWorkflow(wf), throwsA(isA<InvalidDependencyException>()));
    });

    test('Missing dependency references throw InvalidDependencyException', () {
      final wf = createWorkflow(steps: [
        makeStep('step-1', 'Step 1', prereqs: ['ghost-step']),
      ]);
      expect(() => engine.validateWorkflow(wf), throwsA(isA<InvalidDependencyException>()));
    });

    test('Duplicate dependency in a step throws InvalidDependencyException', () {
      final wf = createWorkflow(steps: [
        makeStep('step-1', 'Step 1'),
        makeStep('step-2', 'Step 2', prereqs: ['step-1', 'step-1']),
      ]);
      expect(() => engine.validateWorkflow(wf), throwsA(isA<InvalidDependencyException>()));
    });

    test('Circular dependencies throw CycleDetectedException', () {
      // step-1 -> step-2 -> step-3 -> step-1
      final wf = createWorkflow(steps: [
        makeStep('step-1', 'Step 1', prereqs: ['step-3']),
        makeStep('step-2', 'Step 2', prereqs: ['step-1']),
        makeStep('step-3', 'Step 3', prereqs: ['step-2']),
      ]);
      expect(() => engine.validateWorkflow(wf), throwsA(isA<CycleDetectedException>()));
    });
  });

  group('WorkflowEngine - Progression and Readiness', () {
    test('Initial step readiness: Steps without prerequisites become Ready automatically', () {
      final wf = createWorkflow(steps: [
        makeStep('step-1', 'Planning'),
        makeStep('step-2', 'Development', prereqs: ['step-1']),
      ]);

      final recalculated = engine.recalculateWorkflow(wf);
      expect(recalculated.steps[0].status, equals(StepStatus.ready));
      expect(recalculated.steps[1].status, equals(StepStatus.pending));
    });

    test('Sequential dependencies: A -> B -> C', () {
      final wf = createWorkflow(steps: [
        makeStep('step-a', 'A', status: StepStatus.ready),
        makeStep('step-b', 'B', prereqs: ['step-a']),
        makeStep('step-c', 'C', prereqs: ['step-b']),
      ]);

      // Complete A -> B becomes Ready, C remains Pending
      final wfAfterA = engine.updateStepStatus(wf, 'step-a', StepStatus.completed);
      expect(wfAfterA.steps[0].status, equals(StepStatus.completed));
      expect(wfAfterA.steps[1].status, equals(StepStatus.ready));
      expect(wfAfterA.steps[2].status, equals(StepStatus.pending));

      // Complete B -> C becomes Ready
      final wfAfterB = engine.updateStepStatus(wfAfterA, 'step-b', StepStatus.completed);
      expect(wfAfterB.steps[1].status, equals(StepStatus.completed));
      expect(wfAfterB.steps[2].status, equals(StepStatus.ready));
    });

    test('Branching dependencies: Planning -> Development and Documentation', () {
      final wf = createWorkflow(steps: [
        makeStep('planning', 'Planning'),
        makeStep('dev', 'Development', prereqs: ['planning']),
        makeStep('doc', 'Documentation', prereqs: ['planning']),
      ]);

      final initial = engine.recalculateWorkflow(wf);
      expect(initial.steps[0].status, equals(StepStatus.ready));
      expect(initial.steps[1].status, equals(StepStatus.pending));
      expect(initial.steps[2].status, equals(StepStatus.pending));

      // Complete Planning -> Dev AND Doc both become Ready
      final afterPlanning = engine.updateStepStatus(initial, 'planning', StepStatus.completed);
      expect(afterPlanning.steps[0].status, equals(StepStatus.completed));
      expect(afterPlanning.steps[1].status, equals(StepStatus.ready));
      expect(afterPlanning.steps[2].status, equals(StepStatus.ready));
    });

    test('Multiple prerequisites: Testing depends on both Dev and Doc', () {
      final wf = createWorkflow(steps: [
        makeStep('dev', 'Development', status: StepStatus.completed),
        makeStep('doc', 'Documentation', status: StepStatus.ready),
        makeStep('testing', 'Testing', prereqs: ['dev', 'doc']),
      ]);

      final initial = engine.recalculateWorkflow(wf);
      // Testing must remain pending because Doc is only ready, not completed
      expect(initial.steps[2].status, equals(StepStatus.pending));

      // Now complete Doc
      final afterDoc = engine.updateStepStatus(initial, 'doc', StepStatus.completed);
      expect(afterDoc.steps[2].status, equals(StepStatus.ready));
    });

    test('Reopening a prerequisite sets actionable descendants back to Pending', () {
      final wf = createWorkflow(steps: [
        makeStep('planning', 'Planning', status: StepStatus.completed),
        makeStep('dev', 'Development', prereqs: ['planning'], status: StepStatus.ready),
      ]);

      // Reopening planning back to inProgress
      final reopened = engine.updateStepStatus(wf, 'planning', StepStatus.inProgress);
      expect(reopened.steps[0].status, equals(StepStatus.inProgress));
      expect(reopened.steps[1].status, equals(StepStatus.pending));
    });

    test('Reopening policy: Reset completed descendants when explicitly requested', () {
      final wf = createWorkflow(steps: [
        makeStep('planning', 'Planning', status: StepStatus.completed),
        makeStep('dev', 'Development', prereqs: ['planning'], status: StepStatus.completed),
      ]);

      // Reopen without resetting descendants (default policy preserves completed work)
      final reopenedSoft = engine.updateStepStatus(wf, 'planning', StepStatus.inProgress);
      expect(reopenedSoft.steps[1].status, equals(StepStatus.completed));

      // Reopen with resetCompletedDescendants: true
      final reopenedHard = engine.updateStepStatus(
        wf,
        'planning',
        StepStatus.inProgress,
        resetCompletedDescendants: true,
      );
      expect(reopenedHard.steps[1].status, equals(StepStatus.pending));
    });

    test('Cancelling a step and reopening', () {
      final wf = createWorkflow(steps: [
        makeStep('step-1', 'Step 1', status: StepStatus.ready),
      ]);

      final cancelled = engine.updateStepStatus(wf, 'step-1', StepStatus.cancelled);
      expect(cancelled.steps[0].status, equals(StepStatus.cancelled));

      // Reopen step-1
      final reopened = engine.updateStepStatus(cancelled, 'step-1', StepStatus.ready);
      expect(reopened.steps[0].status, equals(StepStatus.ready));
    });

    test('Invalid state transitions: Cannot complete pending step directly', () {
      final wf = createWorkflow(steps: [
        makeStep('p1', 'Prereq 1', status: StepStatus.ready),
        makeStep('p2', 'Step 2', prereqs: ['p1'], status: StepStatus.pending),
      ]);

      expect(
        () => engine.updateStepStatus(wf, 'p2', StepStatus.completed),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('Progress calculation and completion state', () {
      final emptyWf = createWorkflow(steps: []);
      final recalculatedEmpty = engine.recalculateWorkflow(emptyWf);
      // Empty workflow must NOT be automatically completed
      expect(recalculatedEmpty.status, equals(WorkflowStatus.active));
      expect(recalculatedEmpty.progress, equals(0.0));

      final wf = createWorkflow(steps: [
        makeStep('s1', 'Step 1', status: StepStatus.completed),
        makeStep('s2', 'Step 2', prereqs: ['s1'], status: StepStatus.ready),
      ]);
      expect(wf.progress, equals(0.5));
      expect(wf.progressPercent, equals(50));
      expect(wf.isCompleted, isFalse);

      final completedWf = engine.updateStepStatus(wf, 's2', StepStatus.completed);
      expect(completedWf.progress, equals(1.0));
      expect(completedWf.progressPercent, equals(100));
      expect(completedWf.isCompleted, isTrue);
      expect(completedWf.status, equals(WorkflowStatus.completed));
    });

    test('Deleting a step with dependents rejected without cascade flag', () {
      final wf = createWorkflow(steps: [
        makeStep('step-1', 'Step 1'),
        makeStep('step-2', 'Step 2', prereqs: ['step-1']),
      ]);

      expect(
        () => engine.deleteStep(wf, 'step-1', cascadeRemoveDependencies: false),
        throwsA(isA<WorkflowException>()),
      );

      final cascadeResult = engine.deleteStep(wf, 'step-1', cascadeRemoveDependencies: true);
      expect(cascadeResult.steps.length, equals(1));
      expect(cascadeResult.steps.first.id, equals('step-2'));
      expect(cascadeResult.steps.first.prerequisiteIds, isEmpty);
      expect(cascadeResult.steps.first.status, equals(StepStatus.ready));
    });

    test('Idempotency: recalculating multiple times produces identical state', () {
      final wf = createWorkflow(steps: [
        makeStep('s1', 'Planning'),
        makeStep('s2', 'Dev', prereqs: ['s1']),
      ]);

      final run1 = engine.recalculateWorkflow(wf);
      final run2 = engine.recalculateWorkflow(run1);
      final run3 = engine.recalculateWorkflow(run2);

      expect(run1.steps[0].status, equals(run2.steps[0].status));
      expect(run2.steps[0].status, equals(run3.steps[0].status));
      expect(run1.steps[1].status, equals(run2.steps[1].status));
      expect(run2.steps[1].status, equals(run3.steps[1].status));
    });
  });
}
