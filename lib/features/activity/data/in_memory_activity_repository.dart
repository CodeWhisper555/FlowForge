import 'dart:async';
import '../domain/models/activity_log.dart';
import '../domain/repositories/activity_repository.dart';

class InMemoryActivityRepository implements ActivityRepository {
  final List<ActivityLog> _logs = [];
  final _controller = StreamController<List<ActivityLog>>.broadcast();

  InMemoryActivityRepository() {
    _seedActivities();
  }

  void _seedActivities() {
    final now = DateTime.now();
    _logs.addAll([
      ActivityLog(
        id: 'act-1',
        userId: 'demo-user-123',
        workflowId: 'wf-college-project',
        workflowTitle: 'Develop a College Project',
        type: ActivityType.workflowCreated,
        description: 'Created workflow "Develop a College Project"',
        timestamp: now.subtract(const Duration(hours: 12)),
      ),
      ActivityLog(
        id: 'act-2',
        userId: 'demo-user-123',
        workflowId: 'wf-mobile-release',
        workflowTitle: 'Mobile App Store Release',
        stepId: 'step-mob-1',
        stepTitle: 'Build Release AAB & Web Artifacts',
        type: ActivityType.stepCompleted,
        description: 'Completed step "Build Release AAB & Web Artifacts"',
        timestamp: now.subtract(const Duration(hours: 4)),
      ),
    ]);
  }

  @override
  Stream<List<ActivityLog>> watchUserActivities(String userId, {int limit = 30}) async* {
    yield _filter(userId, limit);
    yield* _controller.stream.map((_) => _filter(userId, limit));
  }

  List<ActivityLog> _filter(String userId, int limit) {
    final list = _logs.where((l) => l.userId == userId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list.take(limit).toList();
  }

  @override
  Future<void> logActivity(ActivityLog activity) async {
    _logs.insert(0, activity);
    _controller.add(List.unmodifiable(_logs));
  }

  void dispose() {
    _controller.close();
  }
}
