import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/room_provider.dart';
import '../services/webrtc_service.dart' show WaitingParticipant;

/// Full-screen waiting-room admin view, pushed on top of the room screen.
/// The in-app back button and the Android hardware back button both just
/// pop this route (Flutter's default Navigator behaviour), which returns
/// to the still-live room screen underneath — i.e. "minimise".
void openWaitingRoomScreen(BuildContext context, RoomProvider room) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: room,
      child: const WaitingRoomScreen(),
    ),
  ));
}

void _confirmRemove(BuildContext context, RoomProvider room, WaitingParticipant p) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: VtColors.surface,
      icon: const Icon(Icons.warning_rounded, color: VtColors.danger, size: 32),
      title: const Text('Remove from waiting room?'),
      content: Text('${p.displayName} will not be admitted and must ask to join again.',
          style: const TextStyle(color: VtColors.text2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            room.removeParticipant(p.socketId);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: VtColors.danger, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}

class WaitingRoomScreen extends StatelessWidget {
  const WaitingRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, room, _) {
        final waiting = room.waitingList;
        return Scaffold(
          backgroundColor: VtColors.bg,
          appBar: AppBar(
            backgroundColor: VtColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: VtColors.text),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text('Waiting Room (${waiting.length})',
                style: const TextStyle(color: VtColors.text, fontSize: 17)),
            actions: [
              if (waiting.isNotEmpty)
                TextButton(
                  onPressed: room.admitAll,
                  child: const Text('Admit all'),
                ),
            ],
          ),
          body: waiting.isEmpty
              ? const Center(
                  child: Text('No one is waiting right now.',
                      style: TextStyle(color: VtColors.text3)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: waiting.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: VtColors.border),
                  itemBuilder: (_, i) {
                    final p = waiting[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: VtColors.primary.withValues(alpha: 0.15),
                        backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                        child: p.photoUrl == null
                            ? Text(p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?',
                                style: const TextStyle(color: VtColors.primary, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: Text(p.displayName, style: const TextStyle(color: VtColors.text)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close_rounded, color: VtColors.danger),
                          onPressed: () => _confirmRemove(context, room, p),
                        ),
                        ElevatedButton(
                          onPressed: () => room.admitParticipant(p.socketId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VtColors.primary, elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Admit'),
                        ),
                      ]),
                    );
                  },
                ),
        );
      },
    );
  }
}
