import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/utils/vt_log.dart';
import '../services/webrtc_service.dart';

class RemotePeer {
  final String socketId;
  final String displayName;
  final MediaStream stream;
  bool speaking;
  bool isMuted;
  bool isCamOff;
  bool isCoHost;
  bool handRaised;

  RemotePeer({
    required this.socketId,
    required this.displayName,
    required this.stream,
    this.speaking = false,
    this.isMuted = false,
    this.isCamOff = false,
    this.isCoHost = false,
    this.handRaised = false,
  });
}

class ChatMessage {
  final String senderId;
  final String senderName;
  final String text;
  final DateTime time;
  final String? imageUrl;

  const ChatMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.time,
    this.imageUrl,
  });
}

class RoomProvider extends ChangeNotifier {
  late final WebRtcService _svc;
  final bool isHost;

  RoomProvider({
    required String meetingToken,
    required String meetingUuid,
    required String displayName,
    required int userId,
    required this.isHost,
    required bool waitingRoom,
    required String apiToken,
    bool startWithVideo = true,
  }) : _isWaitingForAdmission = waitingRoom && !isHost {
    _svc = WebRtcService(
      meetingToken: meetingToken,
      meetingUuid:  meetingUuid,
      displayName:  displayName,
      userId:       userId,
      isHost:       isHost,
      waitingRoom:  waitingRoom,
      apiToken:     apiToken,
      startWithVideo: startWithVideo,
      onRemoteTrack: _onRemoteTrack,
      onPeerLeft:    _onPeerLeft,
      onPeerJoined:  _onPeerJoined,
      onSpeaking:    _onSpeaking,
      onWaitingRoomUpdate: _onWaitingRoomUpdate,
      onYouAreWaiting: _onYouAreWaiting,
      onAdmitted: _onAdmitted,
      onRemoved: _onRemoved,
      onSessionReplaced: _onSessionReplaced,
      onChatMessage: _onChatMessage,
      onPeerMuteStatus: _onPeerMuteStatus,
      onPeerCamStatus: _onPeerCamStatus,
      onCoHostSelf: _onCoHostSelf,
      onPeerCoHost: _onPeerCoHost,
      onForceMuted: _onForceMuted,
      onForceCamOff: _onForceCamOff,
      onUnmuteRequest: _onUnmuteRequestReceived,
      onRecordingStatus: _onRecordingStatus,
      onPeerRaiseHand: _onPeerRaiseHand,
      onWbStroke: _onWbStroke,
      onWbClear: _onWbClear,
      onWbState: _onWbState,
    );
  }

  MediaStream? get localStream => _svc.localStream;
  bool get camEnabled          => _svc.camEnabled;
  bool get micEnabled          => _svc.micEnabled;

  final List<RemotePeer> _peers        = [];
  final List<ChatMessage> _messages    = [];
  final List<Map<String, dynamic>> _wbStrokes = [];
  bool _isLoading = true;
  String? _error;
  List<WaitingParticipant> _waitingList = [];
  bool _isWaitingForAdmission;
  bool _wasRemoved = false;
  bool _wasSessionReplaced = false;
  bool _isCoHost = false;
  bool _isRecording = false;
  bool _handRaised = false;
  bool _disposed = false;

  /// Assigned by the UI (RoomScreen) so the provider can trigger navigation
  /// to the full-screen waiting room from a flash-message action, without
  /// the provider needing a BuildContext of its own.
  VoidCallback? onOpenWaitingRoom;

  String? _flashMessage;
  String? _flashActionLabel;
  VoidCallback? _flashAction;
  int _flashToken = 0;

  List<RemotePeer> get peers    => List.unmodifiable(_peers);
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading            => _isLoading;
  String? get error             => _error;
  List<WaitingParticipant> get waitingList => List.unmodifiable(_waitingList);
  bool get isWaitingForAdmission => _isWaitingForAdmission;
  bool get wasRemoved            => _wasRemoved;
  bool get wasSessionReplaced    => _wasSessionReplaced;
  bool get isCoHost              => _isCoHost;
  bool get isRecording           => _isRecording;
  bool get handRaised            => _handRaised;
  List<Map<String, dynamic>> get wbStrokes => List.unmodifiable(_wbStrokes);
  String? get flashMessage       => _flashMessage;
  String? get flashActionLabel   => _flashActionLabel;
  VoidCallback? get flashAction  => _flashAction;

  void admitParticipant(String socketId) => _svc.admitParticipant(socketId);
  void admitAll() => _svc.admitAll();
  void removeParticipant(String socketId) => _svc.removeParticipant(socketId);
  void muteParticipant(String socketId) => _svc.muteParticipant(socketId);
  void requestUnmute(String socketId) => _svc.requestUnmute(socketId);
  void requestCamOff(String socketId) => _svc.requestCamOff(socketId);
  void assignCohost(String socketId) => _svc.assignCohost(socketId);
  void revokeCohost(String socketId) => _svc.revokeCohost(socketId);

  void _showFlash(String message, {String? actionLabel, VoidCallback? action}) {
    final token = ++_flashToken;
    _flashMessage = message;
    _flashActionLabel = actionLabel;
    _flashAction = action;
    notifyListeners();
    Future.delayed(const Duration(seconds: 5), () {
      if (_disposed || token != _flashToken) return;
      _flashMessage = null;
      _flashActionLabel = null;
      _flashAction = null;
      notifyListeners();
    });
  }

  void dismissFlash() {
    _flashToken++;
    _flashMessage = null;
    _flashActionLabel = null;
    _flashAction = null;
    notifyListeners();
  }

  void _onCoHostSelf(bool isCoHost) {
    vtLog('room', 'isCoHost -> $isCoHost');
    _isCoHost = isCoHost;
    _showFlash(isCoHost ? 'You are now a co-host' : 'Co-host access was revoked');
    notifyListeners();
  }

  void _onPeerCoHost(String socketId, bool isCoHost) {
    final idx = _peers.indexWhere((p) => p.socketId == socketId);
    if (idx >= 0) {
      _peers[idx].isCoHost = isCoHost;
      notifyListeners();
    }
  }

  void _onForceMuted() {
    _showFlash('The host muted your microphone');
  }

  void _onForceCamOff() {
    _showFlash('The host turned off your camera');
  }

  void _onUnmuteRequestReceived() {
    _showFlash(
      'The host asked you to unmute',
      actionLabel: 'Unmute',
      action: () {
        if (!micEnabled) toggleMic();
        dismissFlash();
      },
    );
  }

  void _onWaitingRoomUpdate(List<WaitingParticipant> waiting) {
    vtLog('room', 'waitingList updated: ${waiting.length} waiting');
    final grew = waiting.length > _waitingList.length;
    _waitingList = waiting;
    if (grew && waiting.isNotEmpty) {
      final latest = waiting.last;
      _showFlash(
        '${latest.displayName} is waiting to join the meeting',
        actionLabel: 'View',
        action: () {
          dismissFlash();
          onOpenWaitingRoom?.call();
        },
      );
    }
    notifyListeners();
  }

  void _onYouAreWaiting() {
    vtLog('room', 'isWaitingForAdmission -> true');
    _isWaitingForAdmission = true;
    notifyListeners();
  }

  void _onAdmitted() {
    vtLog('room', 'isWaitingForAdmission -> false (admitted)');
    _isWaitingForAdmission = false;
    notifyListeners();
  }

  void _onRemoved() {
    vtLog('room', 'wasRemoved -> true');
    _isWaitingForAdmission = false;
    _wasRemoved = true;
    notifyListeners();
  }

  void _onSessionReplaced() {
    vtLog('room', 'wasSessionReplaced -> true');
    _isWaitingForAdmission = false;
    _wasSessionReplaced = true;
    notifyListeners();
  }

  Future<void> init() async {
    vtLog('room', 'RoomProvider.init() isHost=$isHost');
    try {
      await _svc.init();
      vtLog('room', 'RoomProvider.init() succeeded');
    } catch (e) {
      vtLog('room', 'RoomProvider.init() FAILED: $e');
      _error = 'Could not access camera/microphone: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  void _onRemoteTrack(String sid, MediaStream stream, String name) {
    final idx = _peers.indexWhere((p) => p.socketId == sid);
    if (idx >= 0) {
      _peers[idx] = RemotePeer(socketId: sid, displayName: name, stream: stream);
    } else {
      _peers.add(RemotePeer(socketId: sid, displayName: name, stream: stream));
    }
    notifyListeners();
  }

  void _onPeerLeft(String sid, String name) {
    _peers.removeWhere((p) => p.socketId == sid);
    notifyListeners();
  }

  void _onPeerJoined(String sid, String name) {
    notifyListeners();
  }

  void _onChatMessage(String socketId, String senderName, String message, DateTime time) {
    _messages.add(ChatMessage(senderId: socketId, senderName: senderName, text: message, time: time));
    notifyListeners();
  }

  void _onPeerMuteStatus(String sid, bool isMuted) {
    final idx = _peers.indexWhere((p) => p.socketId == sid);
    if (idx >= 0) {
      _peers[idx].isMuted = isMuted;
      notifyListeners();
    }
  }

  void _onPeerCamStatus(String sid, bool isCamOff) {
    final idx = _peers.indexWhere((p) => p.socketId == sid);
    if (idx >= 0) {
      _peers[idx].isCamOff = isCamOff;
      notifyListeners();
    }
  }

  void _onSpeaking(String sid, bool speaking) {
    final idx = _peers.indexWhere((p) => p.socketId == sid);
    if (idx >= 0 && _peers[idx].speaking != speaking) {
      _peers[idx].speaking = speaking;
      notifyListeners();
    }
  }

  void toggleCam()    { _svc.toggleCam();  notifyListeners(); }
  void toggleMic()    { _svc.toggleMic();  notifyListeners(); }
  void switchCamera() { _svc.switchCamera(); }

  void toggleRecording() {
    if (_isRecording) {
      _svc.stopRecording();
    } else {
      _svc.startRecording();
    }
    _isRecording = !_isRecording;
    notifyListeners();
  }

  void _onRecordingStatus(bool recording) {
    if (_isRecording == recording) return;
    _isRecording = recording;
    _showFlash(recording ? 'Recording started' : 'Recording stopped');
    notifyListeners();
  }

  void toggleHandRaise() {
    _handRaised = !_handRaised;
    if (_handRaised) {
      _svc.raiseHand();
    } else {
      _svc.lowerHand();
    }
    notifyListeners();
  }

  void _onPeerRaiseHand(String socketId, bool raised) {
    final idx = _peers.indexWhere((p) => p.socketId == socketId);
    if (idx >= 0) {
      _peers[idx].handRaised = raised;
      notifyListeners();
    }
  }

  void requestWbState() => _svc.requestWbState();

  void sendWbStroke(Map<String, dynamic> stroke) {
    _wbStrokes.add(stroke);
    _svc.sendWbStroke(stroke);
    notifyListeners();
  }

  void clearWhiteboard() {
    _wbStrokes.clear();
    _svc.clearWhiteboard();
    notifyListeners();
  }

  void _onWbStroke(Map<String, dynamic> stroke) {
    _wbStrokes.add(stroke);
    notifyListeners();
  }

  void _onWbClear() {
    _wbStrokes.clear();
    notifyListeners();
  }

  void _onWbState(List<Map<String, dynamic>> strokes) {
    _wbStrokes
      ..clear()
      ..addAll(strokes);
    notifyListeners();
  }

  void sendChatMessage(String text, {required String senderId, required String senderName}) {
    _svc.sendChatMessage(text);
    _messages.add(ChatMessage(senderId: senderId, senderName: senderName, text: text, time: DateTime.now()));
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _svc.dispose();
    super.dispose();
  }
}
