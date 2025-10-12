import 'package:flutter/material.dart';

class UiMarketError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const UiMarketError(
      {super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.warning_amber),
        title: Text(message),
        trailing: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
    );
  }
}
