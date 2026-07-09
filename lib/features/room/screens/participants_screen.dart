import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_initials.dart';
import '../providers/room_provider.dart';

/// Full-screen participants list, pushed on top of the room screen. The
/// in-app back button and the Android hardware back button both just pop
/// this route (Flutter's default Navigator behaviour), which returns to the
/// still-live room screen underneath — i.e. "minimise" (same pattern as
/// [openWaitingRoomScreen] in waiting_room_screen.dart).
void openParticipantsScreen(BuildContext context, RoomProvider room) {
  final selfName = context.read<AuthProvider>().user?.name ?? 'You';
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: room,
      child: ParticipantsScreen(selfName: selfName),
    ),
  ));
}

class ParticipantsScreen extends StatelessWidget {
  const ParticipantsScreen({super.key, required this.selfName});
  final String selfName;

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, room, _) {
        final peers = room.peers;
        return Scaffold(
          backgroundColor: VtColors.bg,
          appBar: AppBar(
            backgroundColor: VtColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: VtColors.text),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text('Participants (${peers.length + 1})',
                style: const TextStyle(color: VtColors.text, fontSize: 17)),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: peers.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1, color: VtColors.border),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _ParticipantRow(
                  name: '$selfName (You)',
                  isMuted: !room.micEnabled,
                  isCamOff: !room.camEnabled,
                  isCoHost: room.isHost || room.isCoHost,
                  handRaised: room.handRaised,
                  showControls: false,
                );
              }
              final peer = peers[i - 1];
              return _ParticipantRow(
                name: peer.displayName,
                isMuted: peer.isMuted,
                isCamOff: peer.isCamOff,
                isCoHost: peer.isCoHost,
                handRaised: peer.handRaised,
                showControls: room.isHost,
                onToggleMute: () => peer.isMuted
                    ? room.requestUnmute(peer.socketId)
                    : room.muteParticipant(peer.socketId),
                onCamOff: peer.isCamOff ? null : () => room.requestCamOff(peer.socketId),
                onToggleCoHost: () => peer.isCoHost
                    ? room.revokeCohost(peer.socketId)
                    : room.assignCohost(peer.socketId),
              );
            },
          ),
        );
      },
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.name,
    required this.isMuted,
    required this.isCamOff,
    required this.isCoHost,
    required this.showControls,
    this.handRaised = false,
    this.onToggleMute,
    this.onCamOff,
    this.onToggleCoHost,
  });

  final String name;
  final bool isMuted;
  final bool isCamOff;
  final bool isCoHost;
  final bool handRaised;
  final bool showControls;
  final VoidCallback? onToggleMute;
  final VoidCallback? onCamOff;
  final VoidCallback? onToggleCoHost;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: VtColors.primary.withValues(alpha: 0.15),
        child: Text(avatarInitials(name),
            style: const TextStyle(color: VtColors.primary, fontWeight: FontWeight.bold)),
      ),
      title: Row(children: [
        Flexible(child: Text(name, style: const TextStyle(color: VtColors.text), overflow: TextOverflow.ellipsis)),
        if (isCoHost) ...[
          const SizedBox(width: 6),
          const _Tag(label: 'Co-host'),
        ],
        if (handRaised) ...[
          const SizedBox(width: 6),
          const Icon(Icons.back_hand_rounded, size: 14, color: VtColors.warning),
        ],
      ]),
      subtitle: Row(children: [
        Icon(isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, size: 14, color: VtColors.text3),
        const SizedBox(width: 4),
        Icon(isCamOff ? Icons.videocam_off_rounded : Icons.videocam_rounded, size: 14, color: VtColors.text3),
      ]),
      trailing: showControls
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: isMuted ? 'Ask to unmute' : 'Mute',
                icon: Icon(isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: isMuted ? VtColors.text3 : VtColors.text2),
                onPressed: onToggleMute,
              ),
              IconButton(
                tooltip: isCamOff ? 'Camera off' : 'Turn off camera',
                icon: Icon(Icons.videocam_off_rounded,
                    color: onCamOff == null ? VtColors.text3.withValues(alpha: 0.4) : VtColors.text2),
                onPressed: onCamOff,
              ),
              IconButton(
                tooltip: isCoHost ? 'Revoke co-host' : 'Make co-host',
                icon: Icon(Icons.shield_rounded,
                    color: isCoHost ? VtColors.primary : VtColors.text2),
                onPressed: onToggleCoHost,
              ),
            ])
          : null,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: VtColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: VtColors.primary, fontWeight: FontWeight.w600)),
    );
  }
}
