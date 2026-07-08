class MeetingChatMessage {
  const MeetingChatMessage({
    required this.id,
    required this.senderName,
    required this.message,
    required this.sentAt,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMime,
    this.attachmentSize,
  });

  final int id;
  final String senderName;
  final String message;
  final DateTime sentAt;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMime;
  final int? attachmentSize;

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;

  factory MeetingChatMessage.fromJson(Map<String, dynamic> j) => MeetingChatMessage(
    id: j['message_id'] is num ? (j['message_id'] as num).toInt() : int.parse(j['message_id'].toString()),
    senderName: j['sender_name'] ?? '',
    message: j['message'] ?? '',
    sentAt: DateTime.tryParse(j['sent_at'] ?? '') ?? DateTime.now(),
    attachmentUrl: j['file_url'],
    attachmentName: j['file_name'],
    attachmentMime: j['mime_type'],
    attachmentSize: j['file_size'] != null ? int.tryParse(j['file_size'].toString()) : null,
  );
}
