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

  RemotePeer({
    required this.socketId,
    required this.displayName,
    required this.stream,
    this.speaking = false,
    this.isMuted = false,
    this.isCamOff = false,
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
    );
  }

  MediaStream? get localStream => _svc.localStream;
  bool get camEnabled          => _svc.camEnabled;
  bool get micEnabled          => _svc.micEnabled;

  final List<RemotePeer> _peers        = [];
  final List<ChatMessage> _messages    = [];
  bool _chatOpen  = false;
  bool _isLoading = true;
  String? _error;
  List<WaitingParticipant> _waitingList = [];
  bool _isWaitingForAdmission;
  bool _wasRemoved = false;
  bool _wasSessionReplaced = false;

  List<RemotePeer> get peers    => List.unmodifiable(_peers);
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get chatOpen             => _chatOpen;
  bool get isLoading            => _isLoading;
  String? get error             => _error;
  List<WaitingParticipant> get waitingList => List.unmodifiable(_waitingList);
  bool get isWaitingForAdmission => _isWaitingForAdmission;
  bool get wasRemoved            => _wasRemoved;
  bool get wasSessionReplaced    => _wasSessionReplaced;

  void admitParticipant(String socketId) => _svc.admitParticipant(socketId);
  void admitAll() => _svc.admitAll();
  void removeParticipant(String socketId) => _svc.removeParticipant(socketId);

  void _onWaitingRoomUpdate(List<WaitingParticipant> waiting) {
    vtLog('room', 'waitingList updated: ${waiting.length} waiting');
    _waitingList = waiting;
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
  void toggleChat()   { _chatOpen = !_chatOpen; notifyListeners(); }

  void sendChatMessage(String text, {required String senderId, required String senderName}) {
    _svc.sendChatMessage(text);
    _messages.add(ChatMessage(senderId: senderId, senderName: senderName, text: text, time: DateTime.now()));
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _svc.dispose();
    super.dispose();
  }
}
