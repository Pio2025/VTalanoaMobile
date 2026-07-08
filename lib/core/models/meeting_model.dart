import 'package:flutter/material.dart';

import '../constants/api_constants.dart';
import '../theme/app_theme.dart';

class MeetingModel {
  final int meetingId;
  final String uuid;
  final String token;
  final String title;
  final String? description;
  final String status;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int? hostUserId;
  final String? hostName;
  final String? hostPhotoUrl;
  final int? maxParticipants;
  final bool waitingRoom;
  final String joinUrl;

  const MeetingModel({
    required this.meetingId,
    required this.uuid,
    required this.token,
    required this.title,
    this.description,
    required this.status,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.hostUserId,
    this.hostName,
    this.hostPhotoUrl,
    this.maxParticipants,
    required this.waitingRoom,
    required this.joinUrl,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> j) {
    final token = j['meeting_token'] ?? j['token'] ?? '';
    return MeetingModel(
      meetingId:     _asInt(j['meeting_id']),
      uuid:          j['meeting_uuid'] ?? j['uuid'] ?? '',
      token:         token,
      title:         j['title'] ?? '',
      description:   j['description'],
      status:        j['status'] ?? 'Scheduled',
      scheduledStart: DateTime.tryParse(j['scheduled_start'] ?? '') ?? DateTime.now(),
      scheduledEnd:   DateTime.tryParse(j['scheduled_end'] ?? '') ?? DateTime.now().add(const Duration(hours: 1)),
      hostUserId:     j['host_user_id'] != null ? _asInt(j['host_user_id']) : null,
      hostName:       j['host_name'] ?? j['name'],
      hostPhotoUrl:   j['host_photo_url'] ?? j['photo_url'],
      maxParticipants: j['max_participants'] != null ? _asInt(j['max_participants']) : null,
      waitingRoom:    _asBool(j['waiting_room']),
      // The backend only includes `join_url` in the create-meeting response,
      // not in list/show — derive it client-side so it's always populated.
      joinUrl:        (j['join_url'] as String?)?.isNotEmpty == true
          ? j['join_url']
          : '${ApiConstants.baseUrl}/join/$token',
    );
  }

  bool get isLive => status.toLowerCase() == 'active';
  bool get isScheduled => status.toLowerCase() == 'scheduled';
  bool get isEnded => status.toLowerCase() == 'ended';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  Color get statusColor {
    if (isLive) return VtColors.success;
    if (isEnded) return VtColors.authInkMuted;
    if (isCancelled) return VtColors.danger;
    return VtColors.primary;
  }

  String get statusLabel {
    if (isLive) return 'Live';
    if (isEnded) return 'Ended';
    if (isCancelled) return 'Cancelled';
    return 'Scheduled';
  }
}

/// The API's MySQLi driver sometimes returns numeric/boolean columns as
/// strings (a known shared-hosting quirk when mysqlnd isn't compiled in),
/// so these fields must tolerate both JSON numbers/booleans and their
/// stringified equivalents.
int _asInt(dynamic v) => v is num ? v.toInt() : int.parse(v.toString());

bool _asBool(dynamic v) => v == 1 || v == true || v == '1';
