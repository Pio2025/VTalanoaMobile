import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/meeting_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/vt_log.dart';
import 'vt_button.dart';
import 'vt_text_field.dart';

/// Extracts a meeting token/UUID from either a bare code or a pasted
/// join/room link (e.g. "https://vtalanoa.com/join/abc123" -> "abc123").
String _extractMeetingId(String input) {
  final trimmed = input.trim();
  if (!trimmed.contains('/')) return trimmed;
  final segments = Uri.parse(trimmed).pathSegments;
  return segments.isNotEmpty ? segments.last : trimmed;
}

/// Unified "Join a Meeting" sheet used by every entry point in the app
/// (landing screen, deep links, Home tab, Meetings tab). Validates the
/// meeting ID up front and only asks for what isn't already known:
/// - [knownName] null (guest) -> asks for a display name.
/// - [knownName] set (signed-in user) -> name is skipped entirely.
/// A password field is revealed once the meeting is known to require one,
/// rather than only after a failed join attempt.
class JoinMeetingSheet extends StatefulWidget {
  const JoinMeetingSheet({super.key, this.prefillMeetingId, this.knownName});

  /// When opened from a shared meeting link, the meeting ID/token is already
  /// known — pre-fill and lock that field.
  final String? prefillMeetingId;

  /// The signed-in user's display name, if any. When set, no name field is
  /// shown and this value is sent as the join display name.
  final String? knownName;

  @override
  State<JoinMeetingSheet> createState() => _JoinMeetingSheetState();
}

class _JoinMeetingSheetState extends State<JoinMeetingSheet> {
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: VtColors.danger,
    ));
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final rawInput = _meeting.text;
    final displayName = widget.knownName ?? _name.text.trim();
    try {
      final id = _extractMeetingId(rawInput);
      vtLog('join', 'resolving meeting id/link "$rawInput" -> extracted id "$id"');
      final resolved = await _service.resolveMeeting(id);
      vtLog('join', 'resolveMeeting OK -> token="${resolved.token}" passwordRequired=${resolved.passwordRequired}');

      if (resolved.passwordRequired && !_needsPassword) {
        // Reveal the password field instead of attempting to join blind —
        // avoids a wasted round trip and a confusing "invalid password"
        // error the very first time the field appears.
        setState(() { _needsPassword = true; _loading = false; });
        return;
      }

      vtLog('join', 'joinAsGuest name="$displayName" hasPassword=${_password.text.trim().isNotEmpty}');
      final result = await _service.joinAsGuest(
        resolved.token,
        displayName: displayName,
        password: _password.text.trim(),
      );
      vtLog('join', 'joinAsGuest OK -> meetingToken="${result.meetingToken}" roomToken="${result.roomToken}" waiting=${result.waiting}');
      if (!mounted) return;
      Navigator.pop(context);
      if (widget.knownName != null) {
        // Signed-in user: RoomScreen's existing signed-in path re-derives
        // host/waiting-room status and its own api token — nothing extra
        // to pass through.
        context.push('/room/${result.meetingToken}');
      } else {
        context.push('/room/${result.meetingToken}', extra: {
          'guestName': displayName,
          'guestToken': result.roomToken,
          'waiting': result.waiting,
          // The real, human-entered meeting ID (or token, if a link was
          // pasted) — shown at the top of the room screen since a guest's
          // JWT can't call the authenticated endpoint that resolves it.
          'guestMeetingId': id,
        });
      }
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
        _showError(serverError ??
            (status == 404 ? 'Meeting not found.' : 'Could not join meeting.'));
      }
    } catch (e) {
      vtLog('join', 'FAILED unexpected error: $e');
      _showError('Could not join meeting. Check your connection and try again.');
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
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom + 24,
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
              if (widget.knownName == null) ...[
                const SizedBox(height: 14),
                VtTextField(
                  controller: _name, label: 'Your name',
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: _needsPassword ? TextInputAction.next : TextInputAction.done,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Your name is required' : null,
                  onFieldSubmitted: (_) => _needsPassword ? null : _submit(),
                ),
              ],
              if (_needsPassword) ...[
                const SizedBox(height: 14),
                VtTextField(
                  controller: _password, label: 'Meeting password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscure: true,
                  autofocus: widget.knownName != null || widget.prefillMeetingId != null,
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
