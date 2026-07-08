import '../constants/api_constants.dart';
import '../models/meeting_model.dart';
import '../models/meeting_attachment_model.dart';
import '../models/meeting_chat_message_model.dart';
import '../models/meeting_participant_model.dart';
import '../models/meeting_stats_model.dart';
import 'api_service.dart';

class MeetingService {
  final _api = ApiService();

  Future<MeetingListPage> listMeetings({int page = 1, int perPage = 20}) async {
    final resp = await _api.dio.get(ApiConstants.meetings,
        queryParameters: {'page': page, 'per_page': perPage});
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List? ?? [];
    final meetings = data.map((j) => MeetingModel.fromJson(j as Map<String, dynamic>)).toList();
    final hasMore = body['has_more'] as bool? ?? (meetings.length >= perPage);
    return MeetingListPage(meetings: meetings, hasMore: hasMore);
  }

  Future<MeetingModel> createMeeting({
    required String title,
    String? description,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    bool waitingRoom = false,
    int maxParticipants = 300,
    String? password,
  }) async {
    final resp = await _api.dio.post(ApiConstants.meetings, data: {
      'title': title,
      'description': description ?? '',
      'scheduled_start': scheduledStart.toIso8601String(),
      'scheduled_end': scheduledEnd.toIso8601String(),
      'waiting_room': waitingRoom ? 1 : 0,
      'max_participants': maxParticipants,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return MeetingModel.fromJson(resp.data['meeting'] ?? resp.data);
  }

  Future<Map<String, dynamic>> getMeetingRoom(String token) async {
    final resp = await _api.dio.get(ApiConstants.meeting(token));
    return resp.data['data'] ?? resp.data;
  }

  Future<MeetingModel> getMeeting(String token) async {
    final resp = await _api.dio.get(ApiConstants.meeting(token));
    return MeetingModel.fromJson(resp.data['data'] ?? resp.data);
  }

  Future<MeetingStats> getMeetingStats(String token) async {
    final resp = await _api.dio.get(ApiConstants.meetingStats(token));
    return MeetingStats.fromJson(resp.data['data'] as Map<String, dynamic>);
  }

  Future<ParticipantListPage> getParticipants(String token, {int page = 1, int perPage = 10}) async {
    final resp = await _api.dio.get(ApiConstants.meetingParticipants(token),
        queryParameters: {'page': page, 'per_page': perPage});
    final body = resp.data as Map<String, dynamic>;
    final data = body['data'] as List? ?? [];
    final participants = data.map((j) => MeetingParticipant.fromJson(j as Map<String, dynamic>)).toList();
    return ParticipantListPage(
      participants: participants,
      total: body['total'] as int? ?? participants.length,
      hasMore: body['has_more'] as bool? ?? false,
    );
  }

  Future<List<MeetingChatMessage>> getMeetingChat(String token) async {
    final resp = await _api.dio.get(ApiConstants.chatMessages(token));
    final data = resp.data['data'] as List? ?? [];
    return data.map((j) => MeetingChatMessage.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<MeetingAttachment>> getMeetingFiles(String token) async {
    final resp = await _api.dio.get(ApiConstants.meetingFiles(token));
    final data = resp.data['data'] as List? ?? [];
    return data.map((j) => MeetingAttachment.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> startMeeting(String token) =>
      _api.dio.post(ApiConstants.startMeeting(token));

  Future<void> endMeeting(String token) =>
      _api.dio.post(ApiConstants.endMeeting(token));

  /// Resolves a meeting UUID or token (whatever a user typed/pasted) to its
  /// canonical meeting token.
  Future<String> resolveMeeting(String idOrToken) async {
    final resp = await _api.dio.get(ApiConstants.resolveMeeting(idOrToken));
    return resp.data['token'] as String;
  }

  /// Joins a meeting without an account. Works for both signed-in users
  /// (their bearer token is attached automatically) and guests (no token
  /// stored, so the backend treats the request as a guest join).
  Future<GuestJoinResult> joinAsGuest(
    String token, {
    required String displayName,
    String? password,
  }) async {
    final resp = await _api.dio.post(ApiConstants.joinMeeting(token), data: {
      'display_name': displayName,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    final data = resp.data as Map<String, dynamic>;
    return GuestJoinResult(
      meetingToken: data['meeting_token'] as String? ?? token,
      roomToken:    data['token'] as String,
      waiting:      data['waiting'] == true,
    );
  }
}

class MeetingListPage {
  const MeetingListPage({required this.meetings, required this.hasMore});

  final List<MeetingModel> meetings;
  final bool hasMore;
}

class GuestJoinResult {
  const GuestJoinResult({
    required this.meetingToken,
    required this.roomToken,
    required this.waiting,
  });

  final String meetingToken;
  final String roomToken;
  final bool waiting;
}
