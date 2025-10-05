import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mytrademate/core/errors.dart';

SnackBar buildErrorToast(UserError err) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(err.message)),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: err.diagnostics));
          },
          child: const Text('Copy logs', style: TextStyle(color: Colors.white70)),
        )
      ],
    ),
  );
}

class InlineErrorBox extends StatelessWidget {
  final UserError err;
  final VoidCallback? onRetry;
  const InlineErrorBox({super.key, required this.err, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(err.message)),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: err.diagnostics));
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied diagnostics')));
            },
            child: const Text('Copy logs'),
          ),
        ],
      ),
    );
  }
}


