import '../models/activity_log.dart';

abstract class ActivityRepository {
  Stream<List<ActivityLog>> watchUserActivities(String userId, {int limit = 30});
  Future<void> logActivity(ActivityLog activity);
}
