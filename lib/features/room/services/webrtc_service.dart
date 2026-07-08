import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/vt_log.dart';

typedef TrackCallback = void Function(String socketId, MediaStream stream, String displayName);
typedef PeerCallback  = void Function(String socketId, String displayName);
typedef SpeakCallback = void Function(String socketId, bool speaking);
typedef WaitingListCallback = void Function(List<WaitingParticipant> waiting);
typedef ChatCallback  = void Function(String socketId, String senderName, String message, DateTime time);
typedef MuteStatusCallback = void Function(String socketId, bool isMuted);
typedef CamStatusCallback  = void Function(String socketId, bool isCamOff);

class WaitingParticipant {
  const WaitingParticipant({required this.socketId, required this.displayName, this.photoUrl});

  factory WaitingParticipant.fromJson(Map<String, dynamic> j) => WaitingParticipant(
    socketId: j['socketId'] as String? ?? '',
    displayName: j['displayName'] as String? ?? 'Participant',
    photoUrl: j['photoUrl'] as String?,
  );

  final String socketId;
  final String displayName;
  final String? photoUrl;
}

class WebRtcService {
  WebRtcService({
    required this.meetingToken,
    required this.meetingUuid,
    required this.displayName,
    required this.userId,
    required this.isHost,
    required this.waitingRoom,
    required this.apiToken,
    required this.onRemoteTrack,
    required this.onPeerLeft,
    required this.onPeerJoined,
    required this.onSpeaking,
    this.onWaitingRoomUpdate,
    this.onYouAreWaiting,
    this.onAdmitted,
    this.onChatMessage,
    this.onPeerMuteStatus,
    this.onPeerCamStatus,
    this.startWithVideo = true,
  });

  final String meetingToken;
  final String meetingUuid;
  final String displayName;
  final int userId;
  final bool isHost;
  final bool waitingRoom;
  final String apiToken;
  final bool startWithVideo;
  final TrackCallback onRemoteTrack;
  final PeerCallback  onPeerLeft;
  final PeerCallback  onPeerJoined;
  final SpeakCallback onSpeaking;
  final WaitingListCallback? onWaitingRoomUpdate;
  final VoidCallback? onYouAreWaiting;
  final VoidCallback? onAdmitted;
  final ChatCallback? onChatMessage;
  final MuteStatusCallback? onPeerMuteStatus;
  final CamStatusCallback? onPeerCamStatus;

  sio.Socket? _socket;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _sessionId;

  final Map<String, String> _peerNames   = {};
  final Map<String, String> _midToPeer   = {};
  final Map<String, String> _midToKind   = {};
  final Map<String, MediaStream> _peers  = {};

  late bool _camEnabled = startWithVideo;
  bool _micEnabled = true;

  MediaStream? get localStream  => _localStream;
  bool get camEnabled           => _camEnabled;
  bool get micEnabled           => _micEnabled;

  // ── Init ───────────────────────────────────────────────────
  Future<void> init() async {
    vtLog('rtc', 'init() meetingUuid=$meetingUuid userId=$userId isHost=$isHost waitingRoom=$waitingRoom startWithVideo=$startWithVideo');
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user', 'width': 640, 'height': 480},
    });
    vtLog('rtc', 'getUserMedia OK: ${_localStream?.getTracks().map((t) => t.kind).toList()}');
    if (!startWithVideo) {
      _localStream!.getVideoTracks().forEach((t) => t.enabled = false);
    }
    await _createPeerConnection();
    _connectSocket();
  }

  // ── RTCPeerConnection ─────────────────────────────────────
  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.cloudflare.com:3478'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
    });

    _localStream?.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));

    _pc!.onTrack = _handleTrack;
    _pc!.onIceConnectionState = (state) => vtLog('rtc', 'iceConnectionState -> $state');
    _pc!.onConnectionState = (state) => vtLog('rtc', 'peerConnectionState -> $state');
    vtLog('rtc', 'RTCPeerConnection created');
  }

  void _handleTrack(RTCTrackEvent e) {
    final mid = e.transceiver?.mid;
    if (mid == null) return;
    final socketId = _midToPeer[mid];
    if (socketId == null) return;
    final name = _peerNames[socketId] ?? 'Participant';

    // Use the stream from the track event directly; skip if no stream attached
    final stream = e.streams.firstOrNull;
    if (stream == null) return;
    vtLog('rtc', 'onTrack mid=$mid socketId=$socketId name=$name kind=${e.track.kind}');
    _peers[socketId] = stream;
    onRemoteTrack(socketId, stream, name);
  }

  // ── Socket.IO ─────────────────────────────────────────────
  void _connectSocket() {
    vtLog('socket', 'connecting to ${ApiConstants.signalingUrl} (hasToken=${apiToken.isNotEmpty})');
    _socket = sio.io(ApiConstants.signalingUrl, sio.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .setAuth({'token': apiToken})
        .enableReconnection()
        .setReconnectionDelay(1500)
        .setReconnectionDelayMax(8000)
        .build());

    _socket!
      ..on('connect', (_) { vtLog('socket', 'connected id=${_socket?.id}'); _joinRoom(); })
      ..on('connect_error', (e) => vtLog('socket', 'connect_error: $e'))
      ..on('disconnect', (reason) => vtLog('socket', 'disconnected: $reason'))
      ..on('reconnect_attempt', (n) => vtLog('socket', 'reconnect_attempt #$n'))
      ..on('error', (e) => vtLog('socket', 'error event: $e'))
      ..on('admitted', (_) { vtLog('socket', 'admitted'); onAdmitted?.call(); _startSfu(); })
      ..on('you-are-waiting', (_) { vtLog('socket', 'you-are-waiting'); onYouAreWaiting?.call(); })
      ..on('waiting-room-update', _onWaitingRoomUpdate)
      ..on('peer-joined', _onPeerJoined)
      ..on('peer-left', _onPeerLeft)
      ..on('sfu-offer', _onSfuOffer)
      ..on('speaking', _onSpeaking)
      ..on('chat-message', _onChatMessage)
      ..on('peer-mute-status', _onPeerMuteStatus)
      ..on('peer-cam-status', _onPeerCamStatus);
  }

  void _joinRoom() {
    vtLog('socket', 'emit join-room meetingUuid=$meetingUuid userId=$userId displayName=$displayName isHost=$isHost waitingRoom=$waitingRoom');
    _socket!.emit('join-room', {
      'meetingUuid': meetingUuid,
      'userId': userId,
      'displayName': displayName,
      'isHost': isHost,
      'waitingRoom': waitingRoom,
      'maxParticipants': 300,
    });
  }

  void _onWaitingRoomUpdate(dynamic data) {
    final d = data is Map ? data : {};
    final waiting = (d['waiting'] as List? ?? [])
        .map((p) => WaitingParticipant.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    vtLog('socket', 'waiting-room-update: ${waiting.length} waiting (${waiting.map((w) => w.displayName).join(', ')})');
    onWaitingRoomUpdate?.call(waiting);
  }

  // ── Host controls ─────────────────────────────────────────
  void admitParticipant(String socketId) {
    vtLog('socket', 'emit admit-participant socketId=$socketId');
    _socket?.emit('admit-participant', {'socketId': socketId});
  }

  void admitAll() {
    vtLog('socket', 'emit admit-all');
    _socket?.emit('admit-all', {});
  }

  void _onPeerJoined(dynamic data) {
    final d = data is Map ? data : {};
    final sid  = d['socketId'] as String? ?? '';
    final name = d['displayName'] as String? ?? 'Participant';
    vtLog('socket', 'peer-joined socketId=$sid name=$name');
    _peerNames[sid] = name;
    onPeerJoined(sid, name);
    // Subscribe to their tracks
    if (_sessionId != null) _subscribeToTracks(sid, Map<String, dynamic>.from(d));
  }

  void _onPeerLeft(dynamic data) {
    final d = data is Map ? data : {};
    final sid = d['socketId'] as String? ?? '';
    vtLog('socket', 'peer-left socketId=$sid');
    _peers.remove(sid);
    _peerNames.remove(sid);
    onPeerLeft(sid, d['displayName'] as String? ?? '');
  }

  void _onSfuOffer(dynamic data) async {
    if (_pc == null) return;
    vtLog('sfu', 'sfu-offer received, renegotiating');
    final d = data is Map ? data : {};
    final sdp = d['sdp'] as String? ?? '';
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    await _sfuFetch('PUT', '/sessions/$_sessionId/renegotiate', {
      'sessionDescription': {'type': 'answer', 'sdp': answer.sdp},
    });
    vtLog('sfu', 'sfu-offer renegotiation complete');
  }

  void _onSpeaking(dynamic data) {
    final d = data is Map ? data : {};
    final sid      = d['socketId'] as String? ?? '';
    final speaking = d['speaking'] == true;
    onSpeaking(sid, speaking);
  }

  void _onChatMessage(dynamic data) {
    final d = data is Map ? data : {};
    final sid     = d['socketId'] as String? ?? '';
    final name    = d['senderName'] as String? ?? 'Participant';
    final message = d['message'] as String? ?? '';
    final ts      = d['timestamp'] as String?;
    final time    = ts != null ? (DateTime.tryParse(ts) ?? DateTime.now()) : DateTime.now();
    vtLog('socket', 'chat-message from=$sid name=$name');
    onChatMessage?.call(sid, name, message, time);
  }

  void _onPeerMuteStatus(dynamic data) {
    final d = data is Map ? data : {};
    final sid = d['socketId'] as String? ?? '';
    onPeerMuteStatus?.call(sid, d['isMuted'] == true);
  }

  void _onPeerCamStatus(dynamic data) {
    final d = data is Map ? data : {};
    final sid = d['socketId'] as String? ?? '';
    onPeerCamStatus?.call(sid, d['isCamOff'] == true);
  }

  /// Broadcasts a chat message to the room; the sender shows it locally via its own echo.
  void sendChatMessage(String message) {
    vtLog('socket', 'emit chat-message message="$message"');
    _socket?.emit('chat-message', {'message': message});
  }

  // ── SFU session ───────────────────────────────────────────
  Future<void> _startSfu() async {
    if (_pc == null) return;
    vtLog('sfu', 'starting SFU session');
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    final resp = await _sfuFetch('POST', '/sessions/new', {
      'sessionDescription': {'type': 'offer', 'sdp': offer.sdp},
    });
    _sessionId = resp['sessionId'] as String?;
    vtLog('sfu', 'sessions/new -> sessionId=$_sessionId');
    if (_sessionId == null) return;

    final answer = resp['sessionDescription'];
    await _pc!.setRemoteDescription(
      RTCSessionDescription(answer['sdp'], answer['type']));

    // Publish local tracks
    final transceivers = await _pc!.getTransceivers();
    final tracks = <Map<String, dynamic>>[];
    for (final t in transceivers) {
      final track = t.sender.track;
      if (track == null) continue;
      final mid = t.mid;
      if (mid == null) continue;
      tracks.add({'location': 'local', 'trackName': '${track.kind}-$_sessionId', 'mid': mid});
    }
    if (tracks.isNotEmpty) {
      vtLog('sfu', 'publishing ${tracks.length} local track(s)');
      final tracksResp = await _sfuFetch(
          'POST', '/sessions/$_sessionId/tracks/new', {'tracks': tracks});
      await _handleRenegotiation(tracksResp);
    }
  }

  Future<void> _subscribeToTracks(String socketId, Map<String, dynamic> peerData) async {
    final videoTrackName = peerData['videoTrackName'] as String?;
    final audioTrackName = peerData['audioTrackName'] as String?;
    if (videoTrackName == null && audioTrackName == null) return;
    vtLog('sfu', 'subscribing to tracks of socketId=$socketId video=$videoTrackName audio=$audioTrackName');

    final tracks = <Map<String, dynamic>>[];
    if (videoTrackName != null) {
      tracks.add({'location': 'remote', 'trackName': videoTrackName, 'sessionId': peerData['sfuSessionId']});
    }
    if (audioTrackName != null) {
      tracks.add({'location': 'remote', 'trackName': audioTrackName, 'sessionId': peerData['sfuSessionId']});
    }

    final resp = await _sfuFetch(
        'POST', '/sessions/$_sessionId/tracks/new', {'tracks': tracks});

    // Map MIDs
    if (resp['tracks'] is List) {
      for (final t in resp['tracks'] as List) {
        final mid = t['mid'] as String?;
        if (mid == null) continue;
        final name = t['trackName'] as String? ?? '';
        _midToPeer[mid] = socketId;
        _midToKind[mid] = name.startsWith('video') ? 'video' : 'audio';
      }
    }
    await _handleRenegotiation(resp);
  }

  Future<void> _handleRenegotiation(Map<String, dynamic> resp) async {
    if (resp['requiresImmediateRenegotiation'] != true) return;
    final desc = resp['sessionDescription'];
    if (desc == null) return;
    if (desc['type'] == 'offer') {
      await _pc!.setRemoteDescription(
          RTCSessionDescription(desc['sdp'], desc['type']));
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      await _sfuFetch('PUT', '/sessions/$_sessionId/renegotiate', {
        'sessionDescription': {'type': 'answer', 'sdp': answer.sdp},
      });
    } else {
      await _pc!.setRemoteDescription(
          RTCSessionDescription(desc['sdp'], desc['type']));
    }
  }

  // ── SFU HTTP proxy ────────────────────────────────────────
  Future<Map<String, dynamic>> _sfuFetch(String method, String path, [Map<String, dynamic>? body]) async {
    final url = '${ApiConstants.baseUrl}/api/meetings/$meetingToken/sfu-proxy$path';
    vtLog('sfu-http', '$method $url');
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Authorization': 'Bearer $apiToken', 'Content-Type': 'application/json'},
    ));
    try {
      final Response resp;
      if (method == 'GET') {
        resp = await dio.get(url);
      } else if (method == 'PUT') {
        resp = await dio.put(url, data: body);
      } else {
        resp = await dio.post(url, data: body);
      }
      vtLog('sfu-http', '$method $path -> ${resp.statusCode}');
      return resp.data is Map ? Map<String, dynamic>.from(resp.data) : {};
    } on DioException catch (e) {
      vtLog('sfu-http', '$method $path FAILED status=${e.response?.statusCode} error=${e.message}');
      rethrow;
    }
  }

  // ── Controls ──────────────────────────────────────────────
  void toggleCam() {
    _camEnabled = !_camEnabled;
    vtLog('rtc', 'toggleCam -> $_camEnabled');
    _localStream?.getVideoTracks().forEach((t) => t.enabled = _camEnabled);
    _socket?.emit('cam-status', {'isCamOff': !_camEnabled});
  }

  void toggleMic() {
    _micEnabled = !_micEnabled;
    vtLog('rtc', 'toggleMic -> $_micEnabled');
    _localStream?.getAudioTracks().forEach((t) => t.enabled = _micEnabled);
    _socket?.emit('mute-status', {'isMuted': !_micEnabled});
  }

  Future<void> switchCamera() async {
    final vt = _localStream?.getVideoTracks();
    if (vt != null && vt.isNotEmpty) await Helper.switchCamera(vt.first);
    vtLog('rtc', 'switchCamera done');
  }

  // ── Cleanup ───────────────────────────────────────────────
  Future<void> dispose() async {
    vtLog('rtc', 'dispose()');
    _socket?.disconnect();
    _socket?.dispose();
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    await _pc?.close();
    _peers.clear();
  }
}
