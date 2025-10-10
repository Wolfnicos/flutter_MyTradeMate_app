import 'package:flutter/material.dart';

const Color kBg = Color(0xFF0F1419);
const Color kCard = Color(0xFF1A1F28);
const Color kNeon = Color(0xFF00FF88);
const Color kBuy = Color(0xFFFFD700);
const Color kSell = Color(0xFFFF3B3B);
const Color kHold = Color(0xFFA855F7);
const Color kText = Color(0xFFFFFFFF);
const Color kText2 = Color(0xFF8B96A5);

class ModernCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final bool hasGlow;
  final EdgeInsetsGeometry padding;
  const ModernCard({super.key, required this.child, this.accentColor, this.hasGlow = true, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).cardColor == Colors.transparent ? kCard : Theme.of(context).cardColor;
    return Container(
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(24),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: (accentColor ?? kNeon).withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
        border: Border.all(color: (accentColor ?? Colors.white12).withOpacity(0.12)),
      ),
      padding: padding,
      child: child,
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final List<Color> gradientColors;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final double height;
  final TextStyle? textStyle;
  const GradientButton({super.key, required this.label, required this.gradientColors, required this.onPressed, this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14), this.height = 56, this.textStyle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          height: height,
          padding: padding,
          alignment: Alignment.center,
          child: Text(label, style: textStyle ?? const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color accentColor;
  final Widget? trailing;
  const MetricCard({super.key, required this.label, required this.value, this.subtitle, required this.accentColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      accentColor: accentColor,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: kText2, fontSize: 14)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(color: kText, fontSize: 24, fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: const TextStyle(color: kText2, fontSize: 12)),
                ]
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class NeonProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  const NeonProgressBar({super.key, required this.value, this.color = kNeon});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 8,
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(999)),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth * value.clamp(0.0, 1.0);
          return Stack(children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.6), color]),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 16)],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            )
          ]);
        }),
      ),
    );
  }
}

class AssetListTile extends StatelessWidget {
  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final Widget icon;
  final VoidCallback? onTap;
  const AssetListTile({super.key, required this.symbol, required this.name, required this.price, required this.changePercent, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final up = changePercent >= 0;
    final chColor = up ? const Color(0xFF10B981) : kSell;
    return ModernCard(
      hasGlow: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Colors.white12, child: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(symbol, style: const TextStyle(color: kText, fontWeight: FontWeight.w700)),
                Text(name, style: const TextStyle(color: kText2, fontSize: 12)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(price.toStringAsFixed(2), style: const TextStyle(color: kText, fontWeight: FontWeight.w800)),
              Text('${up ? '+' : ''}${changePercent.toStringAsFixed(2)}%', style: TextStyle(color: chColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ],
        ),
      ),
    );
  }
}

class ActionBadge extends StatelessWidget {
  final String action; // BUY/SELL/HOLD
  const ActionBadge({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    final String upper = action.toUpperCase();
    Color c;
    if (upper == 'BUY') {
      c = kBuy;
    } else if (upper == 'SELL') {
      c = kSell;
    } else {
      c = kHold;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.withOpacity(0.5))),
      child: Text(upper, style: TextStyle(color: c, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}


