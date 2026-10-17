import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/in_memory_template_repository.dart';
import '../../domain/models/workflow_template.dart';
import '../../domain/repositories/template_repository.dart';

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return InMemoryTemplateRepository();
});

final templatesStreamProvider = StreamProvider<List<WorkflowTemplate>>((ref) {
  final user = ref.watch(currentUserProvider);
  final userId = user?.id ?? 'system';
  final repo = ref.watch(templateRepositoryProvider);
  return repo.watchTemplates(userId);
});
