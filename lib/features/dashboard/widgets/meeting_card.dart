import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/meeting_model.dart';
import '../../../core/theme/app_theme.dart';

class MeetingCard extends StatelessWidget {
  const MeetingCard({super.key, required this.meeting});
  final MeetingModel meeting;

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: meeting.joinUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied'), backgroundColor: VtColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df  = DateFormat('EEE, MMM d · h:mm a');
    final isLive = meeting.isLive;
    final showActions = !meeting.isEnded && !meeting.isCancelled;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: meeting.statusColor.withOpacity(0.35), width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/meetings/${meeting.token}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: meeting.statusColor, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(meeting.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: VtColors.authInk),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                _StatusChip(meeting: meeting),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 14, color: VtColors.authInkMuted),
                const SizedBox(width: 4),
                Text(df.format(meeting.scheduledStart),
                  style: const TextStyle(fontSize: 12, color: VtColors.authInkMuted)),
              ]),
              if (meeting.description != null && meeting.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(meeting.description!,
                  style: const TextStyle(fontSize: 12, color: VtColors.authInkMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(children: [
                  _SquareIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Copy link',
                    background: Colors.white,
                    foreground: VtColors.authInkMuted,
                    borderColor: VtColors.authBorder,
                    onPressed: () => _copyLink(context),
                  ),
                  const SizedBox(width: 8),
                  _SquareIconButton(
                    icon: isLive ? Icons.login_rounded : Icons.videocam_rounded,
                    tooltip: isLive ? 'Join now' : 'Start meeting',
                    background: isLive ? VtColors.success : VtColors.primary,
                    foreground: Colors.white,
                    onPressed: () => context.push('/room/${meeting.token}'),
                  ),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.borderColor,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: borderColor != null ? Border.all(color: borderColor!) : null,
            ),
            child: Icon(icon, size: 18, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.meeting});
  final MeetingModel meeting;

  @override
  Widget build(BuildContext context) {
    final color = meeting.statusColor;
    final label = meeting.isLive ? 'LIVE' : meeting.statusLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(meeting.isLive ? 1 : 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: meeting.isLive ? Colors.white : color,
          letterSpacing: .4,
        )),
    );
  }
}
