import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/in_memory_activity_repository.dart';
import '../../domain/models/activity_log.dart';
import '../../domain/repositories/activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return InMemoryActivityRepository();
});

final recentActivitiesStreamProvider = StreamProvider<List<ActivityLog>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const []);
  }
  final repo = ref.watch(activityRepositoryProvider);
  return repo.watchUserActivities(user.id);
});
