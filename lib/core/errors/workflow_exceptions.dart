class WorkflowException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const WorkflowException(this.message, {this.code, this.details});

  @override
  String toString() => 'WorkflowException($code): $message';
}

class CycleDetectedException extends WorkflowException {
  final List<String> cyclePath;

  CycleDetectedException(this.cyclePath)
      : super(
          'Circular dependency detected along path: ${cyclePath.join(" -> ")}',
          code: 'CIRCULAR_DEPENDENCY',
          details: cyclePath,
        );
}

class InvalidDependencyException extends WorkflowException {
  InvalidDependencyException(super.message, {super.code = 'INVALID_DEPENDENCY', super.details});
}

class InvalidTransitionException extends WorkflowException {
  final String fromStatus;
  final String toStatus;

  InvalidTransitionException({
    required this.fromStatus,
    required this.toStatus,
    required String reason,
  }) : super(
          'Cannot transition step from $fromStatus to $toStatus: $reason',
          code: 'INVALID_TRANSITION',
        );
}
