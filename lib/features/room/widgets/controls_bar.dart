import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../../../core/theme/app_theme.dart';

class ControlsBar extends StatelessWidget {
  const ControlsBar({super.key, required this.onLeave});
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();
    return Container(
      color: VtColors.surface,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _CtrlBtn(
                icon: room.micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                label: room.micEnabled ? 'Mute' : 'Unmute',
                active: room.micEnabled,
                onTap: () => room.toggleMic(),
              ),
              const SizedBox(width: 6),
              _CtrlBtn(
                icon: room.camEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                label: room.camEnabled ? 'Stop Cam' : 'Start Cam',
                active: room.camEnabled,
                onTap: () => room.toggleCam(),
              ),
              const SizedBox(width: 6),
              _CtrlBtn(
                icon: Icons.flip_camera_ios_rounded,
                label: 'Flip',
                active: true,
                onTap: () => room.switchCamera(),
              ),
              if (room.isHost && !room.e2eeEnabled) ...[
                const SizedBox(width: 6),
                _CtrlBtn(
                  icon: Icons.fiber_manual_record_rounded,
                  label: 'Rec',
                  active: !room.isRecording,
                  onTap: () => room.toggleRecording(),
                ),
              ],
              const SizedBox(width: 6),
              _CtrlBtn(
                icon: room.handRaised ? Icons.back_hand_rounded : Icons.back_hand_outlined,
                label: 'Hand',
                active: !room.handRaised,
                onTap: () => room.toggleHandRaise(),
              ),
              const SizedBox(width: 6),
              _CtrlBtn(
                icon: Icons.call_end_rounded,
                label: 'End',
                active: false,
                onTap: onLeave,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: active ? VtColors.surface2 : VtColors.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? VtColors.border : VtColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, size: 22,
                color: active ? VtColors.text : VtColors.danger),
          ),
          const SizedBox(height: 4),
          Text(label,
            style: const TextStyle(fontSize: 10, color: VtColors.text2),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
