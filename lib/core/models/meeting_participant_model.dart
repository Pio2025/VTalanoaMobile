class MeetingParticipant {
  final int id;
  final String name;
  final String role;
  final String status;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  const MeetingParticipant({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    this.joinedAt,
    this.leftAt,
  });

  factory MeetingParticipant.fromJson(Map<String, dynamic> j) {
    final fname = (j['fname'] ?? '').toString().trim();
    final lname = (j['lname'] ?? '').toString().trim();
    final fullName = [fname, lname].where((s) => s.isNotEmpty).join(' ');
    final name = fullName.isNotEmpty
        ? fullName
        : ((j['guest_name'] ?? '').toString().trim().isNotEmpty ? j['guest_name'] : 'Guest');

    return MeetingParticipant(
      id: j['participant_id'] is num ? (j['participant_id'] as num).toInt() : int.parse(j['participant_id'].toString()),
      name: name,
      role: j['role'] ?? 'Attendee',
      status: j['status'] ?? 'Admitted',
      joinedAt: j['joined_at'] != null ? DateTime.tryParse(j['joined_at']) : null,
      leftAt: j['left_at'] != null ? DateTime.tryParse(j['left_at']) : null,
    );
  }
}

class ParticipantListPage {
  const ParticipantListPage({required this.participants, required this.total, required this.hasMore});

  final List<MeetingParticipant> participants;
  final int total;
  final bool hasMore;
}
