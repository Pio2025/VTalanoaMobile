import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_initials.dart';
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

// Matches the web app's reaction picker exactly, so a reaction applied from
// either platform renders identically everywhere.
const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

const _allowedFileExtensions = [
  'jpg', 'jpeg', 'png', 'gif', 'webp',
  'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
];

String _formatBytes(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
  final _focus  = FocusNode();
  String? _reactionPickerFor;
  bool _uploading = false;
  bool _showEmojiPicker = false;

  void _toggleEmojiPicker() {
    if (!_showEmojiPicker) _focus.unfocus();
    setState(() => _showEmojiPicker = !_showEmojiPicker);
  }

  @override
  void initState() {
    super.initState();
    context.read<RoomProvider>().markChatOpened();
  }

  @override
  void dispose() {
    context.read<RoomProvider>().markChatClosed();
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToEndSoon() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    context.read<RoomProvider>().sendChatMessage(
      text,
      senderId:   widget.selfId.toString(),
      senderName: widget.selfName,
    );
    _ctrl.clear();
    _scrollToEndSoon();
  }

  Future<void> _sendFile(String filePath, String fileName) async {
    setState(() => _uploading = true);
    final ok = await context.read<RoomProvider>().sendFileMessage(
      filePath: filePath, fileName: fileName,
      senderId: widget.selfId.toString(), senderName: widget.selfName,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Please try again.')));
      return;
    }
    _scrollToEndSoon();
  }

  Future<void> _pickPhoto() async {
    Navigator.pop(context);
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    await _sendFile(file.path, file.name);
  }

  Future<void> _pickFile() async {
    Navigator.pop(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom, allowedExtensions: _allowedFileExtensions);
    final f = result?.files.single;
    if (f?.path == null) return;
    await _sendFile(f!.path!, f.name);
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VtColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_rounded, color: VtColors.primary),
            title: const Text('Photo', style: TextStyle(color: VtColors.text)),
            onTap: _pickPhoto,
          ),
          ListTile(
            leading: const Icon(Icons.attach_file_rounded, color: VtColors.primary),
            title: const Text('File', style: TextStyle(color: VtColors.text)),
            onTap: _pickFile,
          ),
        ]),
      ),
    );
  }

  Widget _pollField(TextEditingController c, String hint) {
    return TextField(
      controller: c,
      style: const TextStyle(fontSize: 13, color: VtColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: VtColors.text3, fontSize: 13),
        filled: true, fillColor: VtColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  void _showPollSheet() {
    final qCtrl = TextEditingController();
    final optCtrls = List.generate(4, (_) => TextEditingController());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VtColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom > 0
                ? 16
                : MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(alignment: Alignment.centerLeft,
                child: Text('Create a Poll',
                    style: TextStyle(color: VtColors.text, fontWeight: FontWeight.bold, fontSize: 15))),
            const SizedBox(height: 12),
            _pollField(qCtrl, 'Ask a question…'),
            const SizedBox(height: 8),
            _pollField(optCtrls[0], 'Option 1'),
            const SizedBox(height: 8),
            _pollField(optCtrls[1], 'Option 2'),
            const SizedBox(height: 8),
            _pollField(optCtrls[2], 'Option 3 (optional)'),
            const SizedBox(height: 8),
            _pollField(optCtrls[3], 'Option 4 (optional)'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final question = qCtrl.text.trim();
                    final opts = optCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
                    if (question.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a question.')));
                      return;
                    }
                    if (opts.length < 2) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Add at least 2 options.')));
                      return;
                    }
                    context.read<RoomProvider>().createPoll(question, opts, creatorName: widget.selfName);
                    Navigator.pop(ctx);
                    _scrollToEndSoon();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: VtColors.primary, elevation: 0),
                  child: const Text('Send Poll'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ]),
          ]),
        ),
      ),
    );
  }

  void _toggleReactionPicker(String messageId) {
    setState(() => _reactionPickerFor = _reactionPickerFor == messageId ? null : messageId);
  }

  void _pickEmoji(String messageId, String emoji) {
    context.read<RoomProvider>().reactToMessage(messageId, emoji);
    setState(() => _reactionPickerFor = null);
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>();
    final messages = room.messages;
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
        if (_uploading) const LinearProgressIndicator(minHeight: 2, color: VtColors.primary),
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
                    if (m.pollId != null) {
                      return _PollCard(
                        poll: room.pollFor(m.pollId!),
                        isSelf: isSelf,
                        onVote: (idx) => room.votePoll(m.pollId!, idx),
                      );
                    }
                    return _Bubble(
                      msg: m, isSelf: isSelf, tf: tf,
                      reactions: m.messageId != null ? room.reactionsFor(m.messageId!) : const {},
                      selfSocketId: room.selfSocketId,
                      pickerOpen: m.messageId != null && _reactionPickerFor == m.messageId,
                      onToggleReactionPicker: m.messageId != null
                          ? () => _toggleReactionPicker(m.messageId!) : null,
                      onPickEmoji: m.messageId != null
                          ? (emoji) => _pickEmoji(m.messageId!, emoji) : null,
                    );
                  },
                ),
        ),
        Container(
          padding: EdgeInsets.only(
            left: 8, right: 8, top: 8,
            // Scaffold already resizes the body to clear the keyboard, so
            // once it's open a flat 8 is enough — adding viewInsets.bottom
            // again on top of that double-counts it and overflows the
            // Column. When the keyboard is closed, add the system nav
            // bar/gesture-pill safe area instead so the bar isn't hidden
            // under it.
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? 8
                : MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: const BoxDecoration(
            color: VtColors.surface,
            border: Border(top: BorderSide(color: VtColors.border))),
          child: Row(children: [
            IconButton(
              tooltip: 'Attach',
              onPressed: _uploading ? null : _showAttachSheet,
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: VtColors.text2,
            ),
            IconButton(
              tooltip: 'Emoji',
              onPressed: _toggleEmojiPicker,
              icon: Icon(_showEmojiPicker
                  ? Icons.keyboard_alt_outlined
                  : Icons.emoji_emotions_outlined),
              color: VtColors.text2,
            ),
            IconButton(
              tooltip: 'Create poll',
              onPressed: _showPollSheet,
              icon: const Icon(Icons.bar_chart_rounded),
              color: VtColors.text2,
            ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                style: const TextStyle(fontSize: 14, color: VtColors.text),
                minLines: 1, maxLines: 4,
                onTap: () {
                  if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                },
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
        Offstage(
          offstage: !_showEmojiPicker,
          child: SizedBox(
            height: 250,
            child: EmojiPicker(
              textEditingController: _ctrl,
              config: const Config(
                emojiViewConfig: EmojiViewConfig(backgroundColor: VtColors.surface),
                bottomActionBarConfig: BottomActionBarConfig(backgroundColor: VtColors.surface),
                categoryViewConfig: CategoryViewConfig(backgroundColor: VtColors.surface),
                searchViewConfig: SearchViewConfig(backgroundColor: VtColors.surface),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.msg,
    required this.isSelf,
    required this.tf,
    required this.reactions,
    required this.selfSocketId,
    required this.pickerOpen,
    this.onToggleReactionPicker,
    this.onPickEmoji,
  });

  final ChatMessage msg;
  final bool isSelf;
  final DateFormat tf;
  final Map<String, Set<String>> reactions;
  final String? selfSocketId;
  final bool pickerOpen;
  final VoidCallback? onToggleReactionPicker;
  final void Function(String emoji)? onPickEmoji;

  bool get _isImage => (msg.fileType ?? '').startsWith('image/');

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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isSelf) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: VtColors.primary.withValues(alpha: 0.15),
                  child: Text(avatarInitials(msg.senderName),
                      style: const TextStyle(color: VtColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7),
                  padding: msg.fileUrl != null && _isImage
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelf ? VtColors.primary : VtColors.surface2,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isSelf ? 12 : 2),
                      bottomRight: Radius.circular(isSelf ? 2 : 12),
                    ),
                  ),
                  child: _buildContent(isSelf),
                ),
              ),
              if (onToggleReactionPicker != null) ...[
                const SizedBox(width: 2),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onToggleReactionPicker,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.add_reaction_outlined, size: 16, color: VtColors.text3),
                  ),
                ),
              ],
            ],
          ),
          if (pickerOpen)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VtColors.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VtColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final e in _reactionEmojis)
                    InkWell(
                      onTap: () => onPickEmoji?.call(e),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(e, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                ]),
              ),
            ),
          if (reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 4, runSpacing: 4, children: [
                for (final entry in reactions.entries)
                  if (entry.value.isNotEmpty)
                    _ReactionPill(
                      emoji: entry.key,
                      count: entry.value.length,
                      mine: selfSocketId != null && entry.value.contains(selfSocketId),
                      onTap: () => onPickEmoji?.call(entry.key),
                    ),
              ]),
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

  Widget _buildContent(bool isSelf) {
    if (msg.decryptFailed) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline_rounded, size: 14,
            color: isSelf ? Colors.white70 : VtColors.text3),
        const SizedBox(width: 6),
        Text('Encrypted message',
            style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic,
                color: isSelf ? Colors.white70 : VtColors.text3)),
      ]);
    }
    if (msg.fileUrl != null && _isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(msg.fileUrl!), mode: LaunchMode.externalApplication),
          child: CachedNetworkImage(
            imageUrl: msg.fileUrl!,
            width: 200, fit: BoxFit.cover,
            placeholder: (_, __) => const SizedBox(
                width: 200, height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorWidget: (_, __, ___) => const SizedBox(
                width: 200, height: 80, child: Icon(Icons.broken_image_rounded, color: VtColors.text3)),
          ),
        ),
      );
    }
    if (msg.fileUrl != null) {
      return InkWell(
        onTap: () => launchUrl(Uri.parse(msg.fileUrl!), mode: LaunchMode.externalApplication),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.insert_drive_file_rounded, size: 20,
              color: isSelf ? Colors.white : VtColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(msg.fileName ?? 'File',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: isSelf ? Colors.white : VtColors.text)),
              if (msg.fileSize != null)
                Text(_formatBytes(msg.fileSize),
                    style: TextStyle(fontSize: 10,
                        color: isSelf ? Colors.white70 : VtColors.text3)),
            ]),
          ),
        ]),
      );
    }
    return Text(msg.text,
      style: TextStyle(fontSize: 13, color: isSelf ? Colors.white : VtColors.text));
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({required this.emoji, required this.count, required this.mine, required this.onTap});
  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: mine ? VtColors.primaryBg : VtColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: mine ? VtColors.primary : VtColors.border),
        ),
        child: Text('$emoji $count', style: const TextStyle(fontSize: 11, color: VtColors.text)),
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll, required this.isSelf, required this.onVote});
  final PollInfo? poll;
  final bool isSelf;
  final void Function(int optionIndex) onVote;

  @override
  Widget build(BuildContext context) {
    final p = poll;
    if (p == null) return const SizedBox.shrink();
    final total = p.options.fold<int>(0, (s, o) => s + o.votes);
    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VtColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VtColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (p.creatorName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(p.creatorName!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VtColors.text2)),
            ),
          Row(children: [
            const Icon(Icons.bar_chart_rounded, size: 15, color: VtColors.primary),
            const SizedBox(width: 4),
            Flexible(child: Text(p.question,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: VtColors.text))),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < p.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _PollOptionBar(
                text: p.options[i].text,
                votes: p.options[i].votes,
                percent: total > 0 ? p.options[i].votes / total : 0,
                selected: p.votedIndex == i,
                disabled: p.votedIndex >= 0,
                onTap: () => onVote(i),
              ),
            ),
          Text('$total vote${total != 1 ? 's' : ''}${p.votedIndex >= 0 ? ' · You voted' : ''}',
              style: const TextStyle(fontSize: 10, color: VtColors.text3)),
        ]),
      ),
    );
  }
}

class _PollOptionBar extends StatelessWidget {
  const _PollOptionBar({
    required this.text, required this.votes, required this.percent,
    required this.selected, required this.disabled, required this.onTap,
  });
  final String text;
  final int votes;
  final double percent;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: disabled ? null : onTap,
      child: Stack(children: [
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: VtColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? VtColors.primary : VtColors.border),
          ),
        ),
        FractionallySizedBox(
          widthFactor: percent.clamp(0, 1),
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: VtColors.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(text, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: VtColors.text))),
              Text('${(percent * 100).round()}% ($votes)',
                  style: const TextStyle(fontSize: 11, color: VtColors.text2)),
            ]),
          ),
        ),
      ]),
    );
  }
}
