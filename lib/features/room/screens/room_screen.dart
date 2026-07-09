import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/vt_log.dart';
import '../../../shared/widgets/vt_button.dart';
import '../../../shared/widgets/vt_text_field.dart';
import '../providers/room_provider.dart';
import '../widgets/controls_bar.dart';
import '../widgets/chat_panel.dart';
import '../widgets/video_tile.dart';
import '../widgets/participants_sheet.dart';
import 'waiting_room_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.token,
    this.guestName,
    this.guestToken,
    this.guestWaitingRoom = false,
    this.guestMeetingId,
    this.startWithVideo = true,
  });
  final String token;

  /// When joining as a guest (no account), [guestName] is the display name
  /// entered on the join sheet and [guestToken] is the room JWT already
  /// issued by `POST /api/meetings/:token/join`. Both are null for the
  /// normal signed-in flow.
  final String? guestName;
  final String? guestToken;

  /// Whether the meeting has a waiting room enabled, as reported by the
  /// join response. Only meaningful when [guestName] is set — signed-in
  /// users look this up from the meeting itself instead.
  final bool guestWaitingRoom;

  /// The meeting ID/token the guest actually typed or had pre-filled from a
  /// shared link — shown at the top of the room screen. A guest's JWT can't
  /// call the authenticated endpoint that resolves the numeric meeting UUID,
  /// so this is the best identifier available for guests.
  final String? guestMeetingId;
  final bool startWithVideo;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  RoomProvider? _room;
  String _displayId = '';

  // Set when the room is reached without a completed guest handshake
  // (widget.guestName) and without a signed-in session — e.g. a direct
  // link tap, cold start, or a lost navigation `extra`. Rather than
  // bouncing to /login (meetings never require an account), we collect
  // a display name (and password, if the meeting needs one) right here.
  bool _needsGuestInfo = false;
  bool _needsPassword = false;
  bool _joining = false;
  String? _joinError;
  final _guestNameCtrl = TextEditingController();
  final _guestPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displayId = widget.guestMeetingId ?? widget.token;
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final isCompletedGuest = widget.guestName != null;
    final isSignedIn = auth.status == AuthStatus.authenticated && auth.user != null;
    vtLog('room', 'RoomScreen._init() token=${widget.token} isCompletedGuest=$isCompletedGuest isSignedIn=$isSignedIn');

    if (!isCompletedGuest && !isSignedIn) {
      vtLog('room', 'no guest handshake and not signed in -> prompting for guest info inline');
      setState(() => _needsGuestInfo = true);
      return;
    }

    final RoomProvider provider;
    if (isCompletedGuest) {
      vtLog('room', 'guest flow: name=${widget.guestName} waitingRoom=${widget.guestWaitingRoom} displayId=$_displayId');
      provider = RoomProvider(
        meetingToken: widget.token,
        meetingUuid:  widget.token,
        displayName:  widget.guestName!,
        userId:       0,
        isHost:       false,
        waitingRoom:  widget.guestWaitingRoom,
        apiToken:     widget.guestToken ?? '',
        startWithVideo: widget.startWithVideo,
      );
    } else {
      final token = await ApiService.getToken() ?? '';
      final user  = auth.user!;

      bool isHost = false;
      bool waitingRoom = false;
      try {
        final meeting = await MeetingService().getMeeting(widget.token);
        isHost = meeting.hostUserId == user.userId;
        waitingRoom = meeting.waitingRoom;
        if (meeting.uuid.isNotEmpty) _displayId = meeting.uuid;
        vtLog('room', 'signed-in flow: userId=${user.userId} hostUserId=${meeting.hostUserId} isHost=$isHost waitingRoom=$waitingRoom meetingUuid=${meeting.uuid}');
      } catch (e) {
        // If the lookup fails, fall back to treating the user as a regular
        // attendee with no waiting room — the socket layer is still the
        // source of truth and will emit 'you-are-waiting' if needed.
        vtLog('room', 'signed-in flow: getMeeting FAILED, defaulting to non-host: $e');
      }

      provider = RoomProvider(
        meetingToken: widget.token,
        meetingUuid:  widget.token,
        displayName:  user.name,
        userId:       user.userId,
        isHost:       isHost,
        waitingRoom:  waitingRoom,
        apiToken:     token,
        startWithVideo: widget.startWithVideo,
      );
    }
    provider.onOpenWaitingRoom = () {
      if (mounted) openWaitingRoomScreen(context);
    };
    setState(() => _room = provider);
    await provider.init();
  }

  Future<void> _submitInlineGuestJoin() async {
    final name = _guestNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _joinError = 'Please enter your name.');
      return;
    }
    setState(() { _joining = true; _joinError = null; });
    try {
      vtLog('room', 'inline guest join: token=${widget.token} name="$name"');
      final result = await MeetingService().joinAsGuest(
        widget.token,
        displayName: name,
        password: _guestPasswordCtrl.text.trim(),
      );
      vtLog('room', 'inline guest join OK -> waiting=${result.waiting}');
      final provider = RoomProvider(
        meetingToken: result.meetingToken,
        meetingUuid:  result.meetingToken,
        displayName:  name,
        userId:       0,
        isHost:       false,
        waitingRoom:  result.waiting,
        apiToken:     result.roomToken,
        startWithVideo: widget.startWithVideo,
      );
      if (!mounted) return;
      provider.onOpenWaitingRoom = () {
        if (mounted) openWaitingRoomScreen(context);
      };
      setState(() {
        _needsGuestInfo = false;
        _displayId = widget.token;
        _room = provider;
      });
      await provider.init();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final serverError = e.response?.data is Map
          ? (e.response?.data['error'] as String?)
          : null;
      vtLog('room', 'inline guest join FAILED status=$status error="$serverError"');
      if (status == 403 && !_needsPassword) {
        setState(() => _needsPassword = true);
      }
      if (mounted) {
        setState(() => _joinError = serverError ??
            (status == 404 ? 'Meeting not found.' : 'Could not join meeting.'));
      }
    } catch (e) {
      vtLog('room', 'inline guest join FAILED unexpected: $e');
      if (mounted) {
        setState(() => _joinError = 'Could not join meeting. Check your connection and try again.');
      }
    }
    if (mounted) setState(() => _joining = false);
  }

  void _leave() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: VtColors.surface,
        title: const Text('Leave meeting?'),
        content: const Text('You will be disconnected from this meeting.',
            style: TextStyle(color: VtColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/meetings');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VtColors.danger, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _room?.dispose();
    _guestNameCtrl.dispose();
    _guestPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_needsGuestInfo) {
      return _InlineGuestJoinScaffold(
        meetingId: _displayId,
        nameController: _guestNameCtrl,
        passwordController: _guestPasswordCtrl,
        needsPassword: _needsPassword,
        loading: _joining,
        error: _joinError,
        onSubmit: _submitInlineGuestJoin,
        onBack: () => context.go('/welcome'),
      );
    }

    if (_room == null) {
      return const Scaffold(
        backgroundColor: VtColors.bg,
        body: Center(child: CircularProgressIndicator(color: VtColors.primary)),
      );
    }

    return ChangeNotifierProvider.value(
      value: _room!,
      child: Scaffold(
        backgroundColor: VtColors.bg,
        body: Consumer<RoomProvider>(
          builder: (context, room, _) {
            if (room.isLoading) {
              return const Center(child: CircularProgressIndicator(color: VtColors.primary));
            }
            if (room.error != null) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, size: 56, color: VtColors.danger),
                const SizedBox(height: 16),
                Text(room.error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: VtColors.text2)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.go('/meetings'),
                    child: const Text('Back to Meetings')),
              ]));
            }

            if (room.wasRemoved) {
              return _RemovedView(onLeave: () => context.go('/meetings'));
            }

            if (room.wasSessionReplaced) {
              return _RemovedView(
                onLeave: () => context.go('/meetings'),
                icon: Icons.sync_problem_rounded,
                iconColor: VtColors.text2,
                message: "This meeting was opened on another device or tab, so you've been disconnected here",
              );
            }

            if (room.isWaitingForAdmission) {
              return _WaitingForHostView(onLeave: _leave);
            }

            return Column(children: [
              // Top bar
              _TopBar(meetingId: _displayId),
              // Main area
              Expanded(
                child: Stack(children: [
                  Row(children: [
                    // Video grid
                    Expanded(child: _VideoGrid(room: room)),
                    // Chat panel (slide in)
                    if (room.chatOpen)
                      SizedBox(
                        width: MediaQuery.of(context).size.width < 600 ? double.infinity : 300,
                        child: ChatPanel(
                          selfName: context.read<AuthProvider>().user?.name ?? 'You',
                          selfId:   context.read<AuthProvider>().user?.userId ?? 0,
                        ),
                      ),
                  ]),
                  if (room.flashMessage != null)
                    Positioned(
                      top: 12, left: 12, right: 12,
                      child: _FlashBanner(
                        message: room.flashMessage!,
                        actionLabel: room.flashActionLabel,
                        onAction: room.flashAction,
                        onDismiss: room.dismissFlash,
                      ),
                    ),
                ]),
              ),
              // Controls
              ControlsBar(onLeave: _leave),
            ]);
          },
        ),
      ),
    );
  }
}

class _InlineGuestJoinScaffold extends StatelessWidget {
  const _InlineGuestJoinScaffold({
    required this.meetingId,
    required this.nameController,
    required this.passwordController,
    required this.needsPassword,
    required this.loading,
    required this.error,
    required this.onSubmit,
    required this.onBack,
  });

  final String meetingId;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final bool needsPassword;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VtColors.bg,
      appBar: AppBar(
        backgroundColor: VtColors.bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: onBack),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.videocam_rounded, size: 48, color: VtColors.primary),
              const SizedBox(height: 16),
              const Text('Join Meeting',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: VtColors.text)),
              const SizedBox(height: 6),
              Text('Meeting ID: $meetingId',
                  style: const TextStyle(fontSize: 13, color: VtColors.text2)),
              const SizedBox(height: 24),
              Theme(
                data: ThemeData.dark().copyWith(
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: true,
                    fillColor: VtColors.surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide.none),
                  ),
                ),
                child: Column(children: [
                  VtTextField(
                    controller: nameController,
                    label: 'Your name',
                    prefixIcon: Icons.person_outline_rounded,
                    autofocus: true,
                    textInputAction: needsPassword ? TextInputAction.next : TextInputAction.done,
                    onFieldSubmitted: (_) => needsPassword ? null : onSubmit(),
                  ),
                  if (needsPassword) ...[
                    const SizedBox(height: 14),
                    VtTextField(
                      controller: passwordController,
                      label: 'Meeting password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => onSubmit(),
                    ),
                  ],
                ]),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: VtColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              VtButton(label: 'Join', onPressed: onSubmit, loading: loading,
                  icon: Icons.arrow_forward_rounded),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.meetingId});
  final String meetingId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16, right: 12,
      ),
      color: VtColors.surface,
      child: Row(children: [
        const Icon(Icons.fiber_manual_record_rounded, size: 10, color: VtColors.success),
        const SizedBox(width: 6),
        Expanded(
          child: Text('ID: $meetingId',
            style: const TextStyle(fontSize: 13, color: VtColors.text2),
            overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Consumer<RoomProvider>(
          builder: (_, room, __) => GestureDetector(
            onTap: () => showParticipantsSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_outline_rounded, size: 20, color: VtColors.text2),
                const SizedBox(width: 6),
                Text(
                  '${room.peers.length + 1} participant${room.peers.isNotEmpty ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: VtColors.text3)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _FlashBanner extends StatelessWidget {
  const _FlashBanner({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VtColors.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: VtColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, color: VtColors.text)),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: VtColors.text3),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }
}

class _WaitingForHostView extends StatelessWidget {
  const _WaitingForHostView({required this.onLeave});
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: VtColors.primary),
          const SizedBox(height: 24),
          const Text('Waiting for the host to let you in',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: VtColors.text)),
          const SizedBox(height: 8),
          const Text("You'll join automatically once the host admits you.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: VtColors.text2)),
          const SizedBox(height: 24),
          OutlinedButton(onPressed: onLeave, child: const Text('Cancel')),
        ]),
      ),
    );
  }
}

class _RemovedView extends StatelessWidget {
  const _RemovedView({
    required this.onLeave,
    this.icon = Icons.block_rounded,
    this.iconColor = VtColors.danger,
    this.message = "You've been removed from the meeting",
  });
  final VoidCallback onLeave;
  final IconData icon;
  final Color iconColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: iconColor),
          const SizedBox(height: 24),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: VtColors.text)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onLeave, child: const Text('Back to Meetings')),
        ]),
      ),
    );
  }
}

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({required this.room});
  final RoomProvider room;

  @override
  Widget build(BuildContext context) {
    final peers = room.peers;
    final localStream = room.localStream;
    final auth = context.read<AuthProvider>();

    // Determine grid layout
    final total = peers.length + 1; // +1 for self
    final cols  = total == 1 ? 1 : total <= 4 ? 2 : total <= 9 ? 3 : 4;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 16 / 9,
        ),
        itemCount: total,
        itemBuilder: (_, i) {
          if (i == 0) {
            // Self tile (always first)
            return localStream != null
                ? VideoTile(
                    stream: localStream,
                    name: auth.user?.name ?? 'You',
                    isSelf: true,
                    camEnabled: room.camEnabled,
                    isHost: room.isHost,
                  )
                : const _LoadingTile();
          }
          final peer = peers[i - 1];
          return VideoTile(
            stream: peer.stream,
            name: peer.displayName,
            speaking: peer.speaking,
            camEnabled: !peer.isCamOff,
            isMuted: peer.isMuted,
          );
        },
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: VtColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: VtColors.border),
    ),
    child: const Center(
      child: CircularProgressIndicator(color: VtColors.primary, strokeWidth: 2)),
  );
}
