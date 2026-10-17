import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/workflow.dart';
import '../domain/models/workflow_enums.dart';
import '../domain/repositories/workflow_repository.dart';

class FirestoreWorkflowRepository implements WorkflowRepository {
  final FirebaseFirestore _firestore;

  FirestoreWorkflowRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('workflows');

  @override
  Stream<List<Workflow>> watchWorkflows(String userId, {WorkflowStatus? statusFilter}) {
    Query<Map<String, dynamic>> query =
        _collection.where('userId', isEqualTo: userId);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.name);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Workflow.fromMap(doc.data()))
          .toList();
    });
  }

  @override
  Future<List<Workflow>> getWorkflows(String userId, {WorkflowStatus? statusFilter}) async {
    Query<Map<String, dynamic>> query =
        _collection.where('userId', isEqualTo: userId);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.name);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Workflow.fromMap(doc.data()))
        .toList();
  }

  @override
  Stream<Workflow?> watchWorkflow(String userId, String workflowId) {
    return _collection.doc(workflowId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      if (data['userId'] != userId) return null; // Security check
      return Workflow.fromMap(data);
    });
  }

  @override
  Future<Workflow?> getWorkflow(String userId, String workflowId) async {
    final doc = await _collection.doc(workflowId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    if (data['userId'] != userId) return null;
    return Workflow.fromMap(data);
  }

  @override
  Future<void> createWorkflow(Workflow workflow) async {
    await _collection.doc(workflow.id).set(workflow.toMap());
  }

  @override
  Future<void> updateWorkflow(Workflow workflow) async {
    await _collection.doc(workflow.id).set(workflow.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteWorkflow(String userId, String workflowId) async {
    final doc = await _collection.doc(workflowId).get();
    if (doc.exists && doc.data()?['userId'] == userId) {
      await _collection.doc(workflowId).delete();
    }
  }
}
