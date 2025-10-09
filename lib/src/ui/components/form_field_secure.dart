import 'package:flutter/material.dart';

class FormFieldSecure extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const FormFieldSecure(
      {super.key, required this.controller, required this.label});

  @override
  State<FormFieldSecure> createState() => _FormFieldSecureState();
}

class _FormFieldSecureState extends State<FormFieldSecure> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      obscureText: _obscure,
    );
  }
}


