import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                controller: _cur,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Current password',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: _new,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'New password', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_new.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New passwords do not match')));
      return;
    }
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Password changed (demo)')));
    Navigator.pop(context);
  }
}

