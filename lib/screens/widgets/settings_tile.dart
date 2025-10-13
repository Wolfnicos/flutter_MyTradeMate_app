import 'package:flutter/material.dart';
import 'package:mytrademate/widgets/premium_widgets.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const SettingsTile(
      {super.key,
      required this.icon,
      required this.title,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ModernCard(
        hasGlow: false,
        child: ListTile(
          leading: Icon(icon, color: kHold),
          title: Text(title, style: const TextStyle(color: kText)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kText2),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ModernCard(
        hasGlow: false,
        child: ListTile(
          leading: Icon(icon, color: kHold),
          title: Text(title, style: const TextStyle(color: kText)),
          trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kHold,
            activeTrackColor: kHold.withOpacity(0.35),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
