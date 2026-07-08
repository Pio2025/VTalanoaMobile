class TimelinePoint {
  const TimelinePoint({required this.label, required this.count});

  final String label;
  final int count;

  factory TimelinePoint.fromJson(Map<String, dynamic> j) => TimelinePoint(
    label: j['t'] ?? '',
    count: j['count'] is num ? (j['count'] as num).toInt() : int.parse(j['count'].toString()),
  );
}

class MeetingStats {
  const MeetingStats({
    required this.totalParticipants,
    this.durationSeconds,
    this.avgAttendanceSeconds,
    required this.timeline,
  });

  final int totalParticipants;
  final int? durationSeconds;
  final int? avgAttendanceSeconds;
  final List<TimelinePoint> timeline;

  factory MeetingStats.fromJson(Map<String, dynamic> j) => MeetingStats(
    totalParticipants: j['total_participants'] is num ? (j['total_participants'] as num).toInt() : int.parse(j['total_participants'].toString()),
    durationSeconds: j['duration_seconds'] != null ? (j['duration_seconds'] as num).toInt() : null,
    avgAttendanceSeconds: j['avg_attendance_seconds'] != null ? (j['avg_attendance_seconds'] as num).toInt() : null,
    timeline: (j['timeline'] as List? ?? []).map((e) => TimelinePoint.fromJson(e as Map<String, dynamic>)).toList(),
  );
}
