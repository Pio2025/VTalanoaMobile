import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class JoinByCodeDialog extends StatefulWidget {
  const JoinByCodeDialog({super.key});

  @override
  State<JoinByCodeDialog> createState() => _JoinByCodeDialogState();
}

class _JoinByCodeDialogState extends State<JoinByCodeDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final token = _ctrl.text.trim();
    if (token.isEmpty) return;
    Navigator.pop(context);
    context.push('/room/$token');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VtColors.surface,
      title: const Text('Join a Meeting'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(color: VtColors.text),
        decoration: const InputDecoration(hintText: 'Enter meeting ID or link'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Join')),
      ],
    );
  }
}
