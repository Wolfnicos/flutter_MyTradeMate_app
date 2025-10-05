import 'package:flutter/material.dart';

class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  const KpiTile({super.key, required this.label, required this.value, this.suffix});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.outline)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Text(suffix!, style: Theme.of(context).textTheme.labelSmall),
              ]
            ],
          ),
        ],
      ),
    );
  }
}




