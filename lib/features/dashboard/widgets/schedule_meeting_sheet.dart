import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/meeting_model.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/vt_button.dart';
import '../../../shared/widgets/vt_text_field.dart';

class ScheduleMeetingSheet extends StatefulWidget {
  const ScheduleMeetingSheet({super.key, required this.onCreated});
  final void Function(MeetingModel) onCreated;

  @override
  State<ScheduleMeetingSheet> createState() => _ScheduleMeetingSheetState();
}

class _ScheduleMeetingSheetState extends State<ScheduleMeetingSheet> {
  final _form     = GlobalKey<FormState>();
  final _title    = TextEditingController();
  final _desc     = TextEditingController();
  final _password = TextEditingController();
  final _service  = MeetingService();

  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  DateTime _end   = DateTime.now().add(const Duration(hours: 2));
  bool _waiting   = true;
  bool _loading   = false;
  bool _requirePassword = false;
  bool _pwVisible = true;

  @override
  void dispose() { _title.dispose(); _desc.dispose(); _password.dispose(); super.dispose(); }

  // Mirrors the web app's generatePassword() in app/Views/meetings/schedule.php
  String _generatePassword() {
    const digits  = '23456789';
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz';
    const chars   = letters + digits;
    final rnd = Random();
    final pw = <String>[
      digits[rnd.nextInt(digits.length)],
      letters[rnd.nextInt(letters.length)],
      for (var i = 2; i < 10; i++) chars[rnd.nextInt(chars.length)],
    ]..shuffle(rnd);
    return pw.join();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(context: context,
        initialDate: _start, firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context,
        initialTime: TimeOfDay.fromDateTime(_start));
    if (t == null) return;
    setState(() => _start = d.copyWith(hour: t.hour, minute: t.minute));
    if (_end.isBefore(_start)) {
      setState(() => _end = _start.add(const Duration(hours: 1)));
    }
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(context: context,
        initialDate: _end,
        firstDate: _start,
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context,
        initialTime: TimeOfDay.fromDateTime(_end));
    if (t == null) return;
    setState(() => _end = d.copyWith(hour: t.hour, minute: t.minute));
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time'),
            backgroundColor: VtColors.danger));
      return;
    }
    setState(() => _loading = true);
    try {
      final meeting = await _service.createMeeting(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        scheduledStart: _start,
        scheduledEnd: _end,
        waitingRoom: _waiting,
        password: _requirePassword ? _password.text.trim() : null,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(meeting);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create meeting: $e'),
              backgroundColor: VtColors.danger));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, MMM d, y  h:mm a');
    return Theme(
      data: AppTheme.light,
      child: Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Schedule Meeting',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: VtColors.authInk)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: VtColors.authInkMuted), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 20),
            VtTextField(
              controller: _title, label: 'Meeting title',
              prefixIcon: Icons.title_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) => (v?.isEmpty ?? true) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            VtTextField(
              controller: _desc, label: 'Description (optional)',
              prefixIcon: Icons.notes_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            _DateTile(label: 'Start', value: df.format(_start), onTap: _pickStart),
            const SizedBox(height: 10),
            _DateTile(label: 'End', value: df.format(_end), onTap: _pickEnd),
            const SizedBox(height: 14),
            SwitchListTile(
              value: _waiting, onChanged: (v) => setState(() => _waiting = v),
              title: const Text('Waiting room', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Approve participants before they enter',
                style: TextStyle(fontSize: 12, color: VtColors.authInkMuted)),
              activeColor: VtColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _requirePassword,
              onChanged: (v) => setState(() {
                _requirePassword = v;
                if (v) {
                  _password.text = _generatePassword();
                  _pwVisible = true;
                } else {
                  _password.clear();
                }
              }),
              title: const Text('Require password', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Participants must enter this to join',
                style: TextStyle(fontSize: 12, color: VtColors.authInkMuted)),
              activeColor: VtColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            if (_requirePassword) ...[
              const SizedBox(height: 10),
              VtTextField(
                controller: _password,
                label: 'Meeting password',
                prefixIcon: Icons.lock_outline_rounded,
                obscure: !_pwVisible,
                validator: (v) => _requirePassword && (v?.trim().isEmpty ?? true)
                    ? 'Password is required' : null,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_pwVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                      tooltip: 'Show/hide',
                      onPressed: () => setState(() => _pwVisible = !_pwVisible),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: 'Regenerate',
                      onPressed: () => setState(() => _password.text = _generatePassword()),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            VtButton(label: 'Create Meeting', onPressed: _submit, loading: _loading,
              icon: Icons.check_rounded),
          ],
          ),
        ),
      ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.value, required this.onTap});
  final String label, value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: VtColors.authFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VtColors.authBorder),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today_rounded, size: 18, color: VtColors.authInkMuted),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: VtColors.authInkMuted)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: VtColors.authInk)),
        ]),
        const Spacer(),
        const Icon(Icons.chevron_right_rounded, color: VtColors.authInkMuted),
      ]),
    ),
  );
}
