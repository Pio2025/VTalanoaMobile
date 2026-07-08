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
      height: 76,
      color: VtColors.surface,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
              const SizedBox(width: 6),
              _CtrlBtn(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Chat',
                active: room.chatOpen,
                onTap: () => room.toggleChat(),
                badge: room.messages.isNotEmpty ? room.messages.length : null,
              ),
              const SizedBox(width: 14),
              // End call
              GestureDetector(
                onTap: onLeave,
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: VtColors.danger,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 24),
                ),
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
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: active ? VtColors.surface2 : VtColors.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? VtColors.border : VtColors.danger.withOpacity(0.3),
                ),
              ),
              child: Icon(icon, size: 22,
                  color: active ? VtColors.text : VtColors.danger),
            ),
            if (badge != null && badge! > 0)
              Positioned(
                right: -4, top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: VtColors.primary, shape: BoxShape.circle),
                  child: Text('$badge',
                    style: const TextStyle(fontSize: 9, color: Colors.white,
                        fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          Text(label,
            style: const TextStyle(fontSize: 10, color: VtColors.text2),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
