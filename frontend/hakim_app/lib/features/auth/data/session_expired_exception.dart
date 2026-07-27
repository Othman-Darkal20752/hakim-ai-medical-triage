class SessionExpiredException implements Exception {
  final String message;

  const SessionExpiredException([
    this.message = 'The authenticated session has expired.',
  ]);

  @override
  String toString() {
    return 'SessionExpiredException: $message';
  }
}
