import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/vt_log.dart';
import '../../../shared/widgets/vt_button.dart';
import '../../../shared/widgets/vt_text_field.dart';

/// Extracts a meeting token/UUID from either a bare code or a pasted
/// join/room link (e.g. "https://vtalanoa.com/join/abc123" -> "abc123").
String _extractMeetingId(String input) {
  final trimmed = input.trim();
  if (!trimmed.contains('/')) return trimmed;
  final segments = Uri.parse(trimmed).pathSegments;
  return segments.isNotEmpty ? segments.last : trimmed;
}

class GuestJoinSheet extends StatefulWidget {
  const GuestJoinSheet({super.key, this.prefillMeetingId});

  /// When opened from a shared meeting link, the meeting ID/token is already
  /// known — pre-fill and lock that field so the guest only enters their name.
  final String? prefillMeetingId;

  @override
  State<GuestJoinSheet> createState() => _GuestJoinSheetState();
}

class _GuestJoinSheetState extends State<GuestJoinSheet> {
  final _form     = GlobalKey<FormState>();
  late final _meeting = TextEditingController(text: widget.prefillMeetingId ?? '');
  final _name     = TextEditingController();
  final _password = TextEditingController();
  final _service  = MeetingService();

  bool _needsPassword = false;
  bool _loading = false;

  @override
  void dispose() {
    _meeting.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final rawInput = _meeting.text;
    try {
      final id = _extractMeetingId(rawInput);
      vtLog('join', 'resolving meeting id/link "$rawInput" -> extracted id "$id"');
      final token = await _service.resolveMeeting(id);
      vtLog('join', 'resolveMeeting OK -> token="$token"');
      vtLog('join', 'joinAsGuest name="${_name.text.trim()}" hasPassword=${_password.text.trim().isNotEmpty}');
      final result = await _service.joinAsGuest(
        token,
        displayName: _name.text.trim(),
        password: _password.text.trim(),
      );
      vtLog('join', 'joinAsGuest OK -> meetingToken="${result.meetingToken}" roomToken="${result.roomToken}" waiting=${result.waiting}');
      if (!mounted) return;
      Navigator.pop(context);
      context.push('/room/${result.meetingToken}', extra: {
        'guestName': _name.text.trim(),
        'guestToken': result.roomToken,
        'waiting': result.waiting,
        // The real, human-entered meeting ID (or token, if a link was
        // pasted) — shown at the top of the room screen since a guest's
        // JWT can't call the authenticated endpoint that resolves it.
        'guestMeetingId': id,
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final serverError = e.response?.data is Map
          ? (e.response?.data['error'] as String?)
          : null;
      vtLog('join', 'FAILED status=$status error="$serverError" url="${e.requestOptions.uri}" message="${e.message}"');
      if (status == 403 && !_needsPassword) {
        setState(() => _needsPassword = true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(serverError ??
              (status == 404 ? 'Meeting not found.' : 'Could not join meeting.')),
          backgroundColor: VtColors.danger,
        ));
      }
    } catch (e) {
      vtLog('join', 'FAILED unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not join meeting. Check your connection and try again.'),
          backgroundColor: VtColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('Join a Meeting',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 20),
              if (widget.prefillMeetingId == null)
                VtTextField(
                  controller: _meeting, label: 'Meeting ID or link',
                  prefixIcon: Icons.videocam_outlined,
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Meeting ID is required' : null,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: VtColors.authFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: VtColors.authBorder),
                  ),
                  child: Row(children: [
                    const Icon(Icons.videocam_outlined, size: 18, color: VtColors.authInkMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Joining meeting · ${widget.prefillMeetingId}',
                          style: const TextStyle(color: VtColors.authInkMuted, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              const SizedBox(height: 14),
              VtTextField(
                controller: _name, label: 'Your name',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: _needsPassword ? TextInputAction.next : TextInputAction.done,
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Your name is required' : null,
                onFieldSubmitted: (_) => _needsPassword ? null : _submit(),
              ),
              if (_needsPassword) ...[
                const SizedBox(height: 14),
                VtTextField(
                  controller: _password, label: 'Meeting password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
              const SizedBox(height: 20),
              VtButton(label: 'Join', onPressed: _submit, loading: _loading,
                icon: Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
