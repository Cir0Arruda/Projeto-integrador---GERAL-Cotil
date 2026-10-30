class ApiException implements Exception {
  const ApiException(this.message, {this.status = 0});
  final String message;
  final int status;
  @override
  String toString() => message;
}

class QueuedOperationException extends ApiException {
  const QueuedOperationException(this.operationId)
    : super(
        'Salvo neste dispositivo como pendente. O servidor ainda não confirmou a alteração.',
      );
  final String operationId;
}
