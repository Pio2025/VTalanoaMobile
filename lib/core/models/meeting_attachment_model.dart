class MeetingAttachment {
  const MeetingAttachment({
    required this.id,
    required this.fileUrl,
    required this.fileName,
    this.mimeType,
    this.fileSize,
    this.createdAt,
  });

  final int id;
  final String fileUrl;
  final String fileName;
  final String? mimeType;
  final int? fileSize;
  final DateTime? createdAt;

  factory MeetingAttachment.fromJson(Map<String, dynamic> j) => MeetingAttachment(
    id: j['attachment_id'] is num ? (j['attachment_id'] as num).toInt() : int.parse(j['attachment_id'].toString()),
    fileUrl: j['file_url'] ?? '',
    fileName: j['file_name'] ?? '',
    mimeType: j['mime_type'],
    fileSize: j['file_size'] != null ? int.tryParse(j['file_size'].toString()) : null,
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
  );
}
