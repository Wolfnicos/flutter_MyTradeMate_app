import 'package:flutter/material.dart';

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
    return ListTile(
      leading: Icon(icon, color: Colors.indigoAccent),
      title: Text(title),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
      onTap: onTap,
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
    return ListTile(
      leading: Icon(icon, color: Colors.indigoAccent),
      title: Text(title),
      trailing: Switch(
          value: value, onChanged: onChanged, activeThumbColor: Colors.indigoAccent),
    );
  }
}
