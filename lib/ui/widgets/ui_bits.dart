import 'package:flutter/material.dart';
import 'package:mytrademate/src/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? pad;
  const GlassCard({super.key, required this.child, this.pad});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(padding: pad ?? const EdgeInsets.all(16), child: child),
      );
}

class LivePill extends StatelessWidget {
  final bool live;
  const LivePill({super.key, required this.live});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: live ? AppTheme.ok() : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(live ? 'Live' : 'Offline',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
}

class MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const MetricChip(
      {super.key, required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class SegTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<String> tabs;
  const SegTabs(
      {super.key,
      required this.index,
      required this.onChanged,
      required this.tabs});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        i == index ? AppTheme.accent(0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                      child: Text(tabs[i],
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color:
                                  i == index ? Colors.white : Colors.white70))),
                ),
              ),
            ),
        ]),
      );
}

class PrimaryCTA extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  const PrimaryCTA(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon = Icons.flash_on});
  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.accent(),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
}
