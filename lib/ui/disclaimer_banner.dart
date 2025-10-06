import 'package:flutter/material.dart';

class FirstRunDisclaimerBanner extends StatelessWidget {
  final VoidCallback onAcknowledge;
  const FirstRunDisclaimerBanner({super.key, required this.onAcknowledge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: Semantics(
        liveRegion: true,
        container: true,
        label: 'Important disclaimer',
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'This app performs simulated (paper) trades only. Nothing here is financial advice.',
                  style: TextStyle(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('btnDisclaimerAcknowledge'),
                onPressed: onAcknowledge,
                child: const Text('I understand'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



