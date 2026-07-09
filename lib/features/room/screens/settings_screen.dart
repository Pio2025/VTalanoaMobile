import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/room_provider.dart';

/// Full-screen in-call settings, pushed on top of the room screen. The
/// in-app back button and the Android hardware back button both just pop
/// this route (Flutter's default Navigator behaviour), which returns to the
/// still-live room screen underneath — i.e. "minimise" (same pattern as
/// [openParticipantsScreen]/[openWaitingRoomScreen]).
void openSettingsScreen(BuildContext context, RoomProvider room, String meetingId) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: room,
      child: SettingsScreen(meetingId: meetingId),
    ),
  ));
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.meetingId});
  final String meetingId;

  @override
  Widget build(BuildContext context) {
    final inviteLink = '${ApiConstants.baseUrl}/join/$meetingId';
    return Scaffold(
      backgroundColor: VtColors.bg,
      appBar: AppBar(
        backgroundColor: VtColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: VtColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings', style: TextStyle(color: VtColors.text, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('MEETING',
              style: TextStyle(fontSize: 12, color: VtColors.text3, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.tag_rounded,
            title: 'Meeting ID',
            subtitle: meetingId,
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18, color: VtColors.text2),
              tooltip: 'Copy meeting ID',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: meetingId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Meeting ID copied')));
              },
            ),
          ),
          const Divider(height: 1, color: VtColors.border),
          _SettingsTile(
            icon: Icons.link_rounded,
            title: 'Invite link',
            subtitle: inviteLink,
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18, color: VtColors.text2),
              tooltip: 'Copy invite link',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite link copied')));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: VtColors.text2),
      title: Text(title, style: const TextStyle(color: VtColors.text, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: VtColors.text3, fontSize: 12), overflow: TextOverflow.ellipsis),
      trailing: trailing,
    );
  }
}
