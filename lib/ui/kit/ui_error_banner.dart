import 'package:flutter/material.dart';

class UiErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const UiErrorBanner({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(message, maxLines: 3)),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}


