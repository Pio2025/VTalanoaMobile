import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/room_provider.dart';

/// Full-screen chat, pushed on top of the room screen. The in-app back
/// button and the Android hardware back button both just pop this route
/// (Flutter's default Navigator behaviour), which returns to the still-live
/// room screen underneath — i.e. "minimise" (same pattern as
/// [openParticipantsScreen]/[openWaitingRoomScreen]/[openSettingsScreen]).
void openChatScreen(BuildContext context, RoomProvider room) {
  final auth = context.read<AuthProvider>();
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: room,
      child: ChatScreen(
        selfName: auth.user?.name ?? 'You',
        selfId: auth.user?.userId ?? 0,
      ),
    ),
  ));
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.selfName, required this.selfId});
  final String selfName;
  final int selfId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    context.read<RoomProvider>().sendChatMessage(
      text,
      senderId:   widget.selfId.toString(),
      senderName: widget.selfName,
    );
    _ctrl.clear();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.watch<RoomProvider>().messages;
    final tf = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: VtColors.bg,
      appBar: AppBar(
        backgroundColor: VtColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: VtColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Chat', style: TextStyle(color: VtColors.text, fontSize: 17)),
      ),
      body: Column(children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(child: Text('No messages yet',
                  style: TextStyle(color: VtColors.text3, fontSize: 13)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final isSelf = m.senderId == widget.selfId.toString();
                    return _Bubble(msg: m, isSelf: isSelf, tf: tf);
                  },
                ),
        ),
        Container(
          padding: EdgeInsets.only(
            left: 12, right: 8, top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          decoration: const BoxDecoration(
            color: VtColors.surface,
            border: Border(top: BorderSide(color: VtColors.border))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(fontSize: 14, color: VtColors.text),
                minLines: 1, maxLines: 4,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: const TextStyle(color: VtColors.text3, fontSize: 13),
                  filled: true, fillColor: VtColors.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: VtColors.border)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: VtColors.border)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: VtColors.primary)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _send,
              icon: const Icon(Icons.send_rounded, size: 22),
              color: VtColors.primary,
              style: IconButton.styleFrom(
                backgroundColor: VtColors.primaryBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.isSelf, required this.tf});
  final ChatMessage msg;
  final bool isSelf;
  final DateFormat tf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isSelf)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(msg.senderName,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: VtColors.text2)),
            ),
          Row(
            mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelf ? VtColors.primary : VtColors.surface2,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isSelf ? 12 : 2),
                    bottomRight: Radius.circular(isSelf ? 2 : 12),
                  ),
                ),
                child: Text(msg.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelf ? Colors.white : VtColors.text,
                  )),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(tf.format(msg.time),
              style: const TextStyle(fontSize: 10, color: VtColors.text3)),
          ),
        ],
      ),
    );
  }
}
