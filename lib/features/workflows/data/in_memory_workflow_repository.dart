import 'dart:async';
import '../domain/models/workflow.dart';
import '../domain/models/workflow_enums.dart';
import '../domain/models/workflow_step.dart';
import '../domain/repositories/workflow_repository.dart';

class InMemoryWorkflowRepository implements WorkflowRepository {
  final List<Workflow> _storage = [];
  final _workflowsStreamController = StreamController<List<Workflow>>.broadcast();

  InMemoryWorkflowRepository({bool seedDemoData = true}) {
    if (seedDemoData) {
      _seedCollegeProject();
      _seedMobileReleaseProject();
    }
  }

  void _seedCollegeProject() {
    final now = DateTime.now();
    const planningId = 'step-col-1';
    const devId = 'step-col-2';
    const docId = 'step-col-3';
    const testingId = 'step-col-4';
    const submissionId = 'step-col-5';

    final collegeWorkflow = Workflow(
      id: 'wf-college-project',
      userId: 'demo-user-123',
      title: 'Develop a College Project',
      description:
          'End-to-end college capstone project workflow with multi-step branch dependencies.',
      status: WorkflowStatus.active,
      priority: WorkflowPriority.urgent,
      dueDate: now.add(const Duration(days: 14)),
      steps: [
        WorkflowStep(
          id: planningId,
          title: 'Planning',
          description: 'Define requirements, scope, architecture, and technology stack.',
          order: 0,
          status: StepStatus.ready, // Ready because no prerequisites
          prerequisiteIds: const [],
          dueDate: now.add(const Duration(days: 2)),
          createdAt: now,
          updatedAt: now,
        ),
        WorkflowStep(
          id: devId,
          title: 'Development',
          description: 'Implement core application features, database models, and API endpoints.',
          order: 1,
          status: StepStatus.pending,
          prerequisiteIds: const [planningId],
          dueDate: now.add(const Duration(days: 7)),
          createdAt: now,
          updatedAt: now,
        ),
        WorkflowStep(
          id: docId,
          title: 'Documentation',
          description: 'Write comprehensive report, API docs, and user guide.',
          order: 2,
          status: StepStatus.pending,
          prerequisiteIds: const [planningId],
          dueDate: now.add(const Duration(days: 8)),
          createdAt: now,
          updatedAt: now,
        ),
        WorkflowStep(
          id: testingId,
          title: 'Testing',
          description: 'Execute unit tests, integration tests, and QA user validation.',
          order: 3,
          status: StepStatus.pending,
          prerequisiteIds: const [devId, docId],
          dueDate: now.add(const Duration(days: 11)),
          createdAt: now,
          updatedAt: now,
        ),
        WorkflowStep(
          id: submissionId,
          title: 'Final Submission',
          description: 'Deliver project artifacts and presentation deck to committee.',
          order: 4,
          status: StepStatus.pending,
          prerequisiteIds: const [testingId],
          dueDate: now.add(const Duration(days: 14)),
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    _storage.add(collegeWorkflow);
  }

  void _seedMobileReleaseProject() {
    final now = DateTime.now();
    const buildId = 'step-mob-1';
    const storeId = 'step-mob-2';

    final mobileWorkflow = Workflow(
      id: 'wf-mobile-release',
      userId: 'demo-user-123',
      title: 'Mobile App Store Release',
      description: 'Prepare production binaries, store assets, and submit for app review.',
      status: WorkflowStatus.active,
      priority: WorkflowPriority.high,
      dueDate: now.add(const Duration(days: 5)),
      steps: [
        WorkflowStep(
          id: buildId,
          title: 'Build Release AAB & Web Artifacts',
          description: 'Compile signed release bundles with production keys.',
          order: 0,
          status: StepStatus.completed,
          prerequisiteIds: const [],
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(hours: 4)),
          completedAt: now.subtract(const Duration(hours: 4)),
        ),
        WorkflowStep(
          id: storeId,
          title: 'Submit to Google Play & Deploy Web',
          description: 'Upload build, update release notes, and rollout.',
          order: 1,
          status: StepStatus.ready,
          prerequisiteIds: const [buildId],
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(hours: 4)),
        ),
      ],
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
    );

    _storage.add(mobileWorkflow);
  }

  void _notify() {
    _workflowsStreamController.add(List.unmodifiable(_storage));
  }

  @override
  Stream<List<Workflow>> watchWorkflows(String userId, {WorkflowStatus? statusFilter}) async* {
    yield _filterWorkflows(userId, statusFilter);
    yield* _workflowsStreamController.stream.map(
      (_) => _filterWorkflows(userId, statusFilter),
    );
  }

  List<Workflow> _filterWorkflows(String userId, WorkflowStatus? statusFilter) {
    return _storage.where((wf) {
      if (wf.userId != userId) return false;
      if (statusFilter != null && wf.status != statusFilter) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<Workflow>> getWorkflows(String userId, {WorkflowStatus? statusFilter}) async {
    return _filterWorkflows(userId, statusFilter);
  }

  @override
  Stream<Workflow?> watchWorkflow(String userId, String workflowId) async* {
    yield _findWorkflow(userId, workflowId);
    yield* _workflowsStreamController.stream.map(
      (_) => _findWorkflow(userId, workflowId),
    );
  }

  Workflow? _findWorkflow(String userId, String workflowId) {
    try {
      return _storage.firstWhere((w) => w.id == workflowId && w.userId == userId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Workflow?> getWorkflow(String userId, String workflowId) async {
    return _findWorkflow(userId, workflowId);
  }

  @override
  Future<void> createWorkflow(Workflow workflow) async {
    final index = _storage.indexWhere((w) => w.id == workflow.id);
    if (index >= 0) {
      throw Exception('Workflow with ID "${workflow.id}" already exists.');
    }
    _storage.add(workflow);
    _notify();
  }

  @override
  Future<void> updateWorkflow(Workflow workflow) async {
    final index = _storage.indexWhere((w) => w.id == workflow.id && w.userId == workflow.userId);
    if (index == -1) {
      throw Exception('Workflow not found or access denied: ${workflow.id}');
    }
    _storage[index] = workflow;
    _notify();
  }

  @override
  Future<void> deleteWorkflow(String userId, String workflowId) async {
    final beforeCount = _storage.length;
    _storage.removeWhere((w) => w.id == workflowId && w.userId == userId);
    if (_storage.length == beforeCount) {
      throw Exception('Workflow not found or access denied: $workflowId');
    }
    _notify();
  }

  void dispose() {
    _workflowsStreamController.close();
  }
}
