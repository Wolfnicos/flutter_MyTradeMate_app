import 'package:flutter/material.dart';

class UiMarketSkeleton extends StatelessWidget {
  final int count;
  const UiMarketSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) => _row(context, i)),
    );
  }

  Widget _row(BuildContext context, int i) {
    final color =
        Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
