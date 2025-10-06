enum AppErrorType {
  network,
  timeout,
  rateLimit,
  auth,
  missingCredentials,
  maintenance,
  modelLoad,
  modelInference,
  unknown,
}

class UserError {
  final AppErrorType type;
  final String message; // user-friendly
  final String diagnostics; // for copy-to-clipboard
  const UserError(this.type, this.message, this.diagnostics);
}

class ErrorMapper {
  static UserError map(Object? error) {
    final msg = (error?.toString() ?? '').toLowerCase();
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return UserError(AppErrorType.timeout,
          'Network timeout. Please try again.', error.toString());
    }
    if (msg.contains('418') || msg.contains('rate limit')) {
      return UserError(AppErrorType.rateLimit,
          'Temporarily rate-limited. Retrying shortly…', error.toString());
    }
    if (msg.contains('401') ||
        msg.contains('-2015') ||
        msg.contains('invalid api')) {
      return UserError(
          AppErrorType.auth,
          'Authentication failed. Check API keys and permissions.',
          error.toString());
    }
    if (msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('maintenance')) {
      return UserError(AppErrorType.maintenance,
          'Exchange unavailable. Please retry later.', error.toString());
    }
    if (msg.contains('model') && msg.contains('load')) {
      return UserError(
          AppErrorType.modelLoad,
          'AI model load failed. Trading & prices still work.',
          error.toString());
    }
    if (msg.contains('model') &&
        (msg.contains('infer') || msg.contains('predict'))) {
      return UserError(AppErrorType.modelInference,
          'AI inference failed. Please retry.', error.toString());
    }
    if (msg.contains('http') ||
        msg.contains('socket') ||
        msg.contains('network')) {
      return UserError(AppErrorType.network,
          'Network error. Check your connection.', error.toString());
    }
    return UserError(AppErrorType.unknown,
        'Unexpected error. Please try again.', error.toString());
  }
}
