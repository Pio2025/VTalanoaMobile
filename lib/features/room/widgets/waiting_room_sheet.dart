import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/room_provider.dart';

void showWaitingRoomSheet(BuildContext context) {
  final room = context.read<RoomProvider>();
  showModalBottomSheet(
    context: context,
    backgroundColor: VtColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ChangeNotifierProvider.value(
      value: room,
      child: const WaitingRoomSheet(),
    ),
  );
}

class WaitingRoomSheet extends StatelessWidget {
  const WaitingRoomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, room, _) {
        final waiting = room.waitingList;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.people_outline_rounded, color: VtColors.text2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Waiting room (${waiting.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: VtColors.text)),
                ),
                if (waiting.isNotEmpty)
                  TextButton(
                    onPressed: room.admitAll,
                    child: const Text('Admit all'),
                  ),
              ]),
              const SizedBox(height: 8),
              if (waiting.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No one is waiting right now.',
                      style: TextStyle(color: VtColors.text3)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: waiting.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: VtColors.border),
                    itemBuilder: (_, i) {
                      final p = waiting[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
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
                            onPressed: () => room.removeParticipant(p.socketId),
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
                ),
            ]),
          ),
        );
      },
    );
  }
}
