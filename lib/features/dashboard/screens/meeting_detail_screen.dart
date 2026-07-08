import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/meeting_attachment_model.dart';
import '../../../core/models/meeting_chat_message_model.dart';
import '../../../core/models/meeting_model.dart';
import '../../../core/models/meeting_participant_model.dart';
import '../../../core/models/meeting_stats_model.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/theme/app_theme.dart';

class MeetingDetailScreen extends StatefulWidget {
  const MeetingDetailScreen({super.key, required this.token});
  final String token;

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final _service = MeetingService();

  bool _loading = true;
  String? _error;
  MeetingModel? _meeting;
  MeetingStats? _stats;
  List<MeetingChatMessage> _chat = [];
  List<MeetingAttachment> _files = [];
  late final _ParticipantDataSource _participantSource;

  @override
  void initState() {
    super.initState();
    _participantSource = _ParticipantDataSource(token: widget.token, service: _service);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final meeting = await _service.getMeeting(widget.token);
      MeetingStats? stats;
      List<MeetingChatMessage> chat = [];
      List<MeetingAttachment> files = [];

      if (!meeting.isScheduled) {
        final results = await Future.wait([
          _service.getMeetingStats(widget.token),
          _service.getMeetingChat(widget.token),
          _service.getMeetingFiles(widget.token),
        ]);
        stats = results[0] as MeetingStats;
        chat = results[1] as List<MeetingChatMessage>;
        files = results[2] as List<MeetingAttachment>;
      }

      if (!mounted) return;
      setState(() {
        _meeting = meeting;
        _stats = stats;
        _chat = chat;
        _files = files;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Could not load meeting: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: VtColors.authInk,
          title: Text(_meeting?.title ?? 'Meeting',
              style: const TextStyle(color: VtColors.authInk, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: VtColors.primary))
              : _error != null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, style: const TextStyle(color: VtColors.authInkMuted), textAlign: TextAlign.center),
                    ))
                  : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final meeting = _meeting!;
    final df = DateFormat('EEE, MMM d, y · h:mm a');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(meeting: meeting, df: df),
        const SizedBox(height: 16),
        if (meeting.isScheduled)
          const _EmptyNotice(text: 'This meeting hasn\'t started yet.')
        else ...[
          _StatsRow(stats: _stats),
          const SizedBox(height: 16),
          if (_stats != null && _stats!.timeline.isNotEmpty) ...[
            _TimelineChart(stats: _stats!),
            const SizedBox(height: 16),
          ],
          if (_stats == null || _stats!.totalParticipants > 0) ...[
            _SectionCard(
              title: 'Participants',
              child: PaginatedDataTable(
                rowsPerPage: 10,
                availableRowsPerPage: const [10],
                showEmptyRows: false,
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Joined At')),
                  DataColumn(label: Text('Left At')),
                ],
                source: _participantSource,
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SectionCard(
            title: 'Chat',
            child: _chat.isEmpty
                ? const _EmptyNotice(text: 'No chat messages for this meeting.')
                : Column(children: _chat.map((m) => _ChatTile(message: m)).toList()),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Files & Resources',
            child: _files.isEmpty
                ? const _EmptyNotice(text: 'No files were shared in this meeting.')
                : Column(children: _files.map((f) => _FileTile(file: f)).toList()),
          ),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.meeting, required this.df});
  final MeetingModel meeting;
  final DateFormat df;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VtColors.authFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VtColors.authBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(meeting.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: VtColors.authInk)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: meeting.statusColor.withOpacity(meeting.isLive ? 1 : 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(meeting.isLive ? 'LIVE' : meeting.statusLabel,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .4,
                  color: meeting.isLive ? Colors.white : meeting.statusColor,
                )),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.schedule_rounded, size: 15, color: VtColors.authInkMuted),
          const SizedBox(width: 6),
          Text(df.format(meeting.scheduledStart), style: const TextStyle(fontSize: 13, color: VtColors.authInkMuted)),
        ]),
        if (meeting.hostName != null && meeting.hostName!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.person_rounded, size: 15, color: VtColors.authInkMuted),
            const SizedBox(width: 6),
            Text('Host: ${meeting.hostName}', style: const TextStyle(fontSize: 13, color: VtColors.authInkMuted)),
          ]),
        ],
        if (meeting.description != null && meeting.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(meeting.description!, style: const TextStyle(fontSize: 13, color: VtColors.authInk)),
        ],
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final MeetingStats? stats;

  String _formatDuration(int? seconds) {
    if (seconds == null) return '—';
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${d.inSeconds.remainder(60)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(icon: Icons.groups_rounded, label: 'Participants', value: '${stats?.totalParticipants ?? 0}')),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(icon: Icons.timer_rounded, label: 'Duration', value: _formatDuration(stats?.durationSeconds))),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(icon: Icons.hourglass_bottom_rounded, label: 'Avg Attendance', value: _formatDuration(stats?.avgAttendanceSeconds))),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: VtColors.primaryBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Icon(icon, color: VtColors.primary, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: VtColors.authInk)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: VtColors.authInkMuted)),
      ]),
    );
  }
}

class _TimelineChart extends StatelessWidget {
  const _TimelineChart({required this.stats});
  final MeetingStats stats;

  @override
  Widget build(BuildContext context) {
    final points = stats.timeline;
    final maxCount = points.map((p) => p.count).fold<int>(0, (a, b) => a > b ? a : b);

    return _SectionCard(
      title: 'Attendance over time',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: (maxCount + 1).toDouble(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: 1)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (points.length / 4).clamp(1, points.length).toDouble(),
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= points.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(points[i].label, style: const TextStyle(fontSize: 9, color: VtColors.authInkMuted)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: points[i].count.toDouble(), color: VtColors.primary, width: 10,
                      borderRadius: BorderRadius.circular(3)),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VtColors.authBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: VtColors.authInk)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, color: VtColors.authInkMuted)),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.message});
  final MeetingChatMessage message;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, h:mm a');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(message.senderName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: VtColors.authInk)),
          ),
          Text(df.format(message.sentAt), style: const TextStyle(fontSize: 11, color: VtColors.authInkMuted)),
        ]),
        if (message.message.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(message.message, style: const TextStyle(fontSize: 13, color: VtColors.authInk)),
        ],
        if (message.hasAttachment) ...[
          const SizedBox(height: 6),
          _FileChip(url: message.attachmentUrl!, name: message.attachmentName ?? 'Attachment'),
        ],
        const Divider(height: 16, color: VtColors.authBorder),
      ]),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file});
  final MeetingAttachment file;

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, h:mm a');
    return InkWell(
      onTap: () => launchUrl(Uri.parse(file.fileUrl), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const Icon(Icons.insert_drive_file_rounded, color: VtColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(file.fileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: VtColors.authInk),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                [
                  if (file.fileSize != null) _formatSize(file.fileSize),
                  if (file.createdAt != null) df.format(file.createdAt!),
                ].join(' · '),
                style: const TextStyle(fontSize: 11, color: VtColors.authInkMuted),
              ),
            ]),
          ),
          const Icon(Icons.open_in_new_rounded, size: 16, color: VtColors.authInkMuted),
        ]),
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.url, required this.name});
  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: VtColors.primaryBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.attach_file_rounded, size: 14, color: VtColors.primary),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(fontSize: 12, color: VtColors.primary)),
        ]),
      ),
    );
  }
}

class _ParticipantDataSource extends DataTableSource {
  _ParticipantDataSource({required this.token, required this.service}) {
    _fetchPage(1);
  }

  final String token;
  final MeetingService service;
  final Map<int, MeetingParticipant> _cache = {};
  final Set<int> _fetchingPages = {};
  int _total = 0;
  bool _rowCountApproximate = true;

  Future<void> _fetchPage(int page) async {
    if (_fetchingPages.contains(page)) return;
    _fetchingPages.add(page);
    try {
      final result = await service.getParticipants(token, page: page, perPage: 10);
      for (var i = 0; i < result.participants.length; i++) {
        _cache[(page - 1) * 10 + i] = result.participants[i];
      }
      _total = result.total;
      _rowCountApproximate = false;
      notifyListeners();
    } catch (_) {
      // leave the row(s) for this page in a permanent loading state on failure
    } finally {
      _fetchingPages.remove(page);
    }
  }

  static final _df = DateFormat('MMM d, h:mm a');

  @override
  DataRow? getRow(int index) {
    final participant = _cache[index];
    if (participant == null) {
      _fetchPage((index ~/ 10) + 1);
      return const DataRow(cells: [
        DataCell(SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        DataCell(Text('')),
        DataCell(Text('')),
        DataCell(Text('')),
      ]);
    }
    return DataRow(cells: [
      DataCell(Text(participant.name)),
      DataCell(Text(participant.role)),
      DataCell(Text(participant.joinedAt != null ? _df.format(participant.joinedAt!) : '—')),
      DataCell(Text(participant.leftAt != null ? _df.format(participant.leftAt!) : '—')),
    ]);
  }

  @override
  bool get isRowCountApproximate => _rowCountApproximate;

  @override
  int get rowCount => _rowCountApproximate ? _cache.length : _total;

  @override
  int get selectedRowCount => 0;
}
