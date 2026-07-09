import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/schedule_meeting_sheet.dart';
import '../widgets/join_by_code_dialog.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _service = MeetingService();
  bool _starting = false;
  bool _statsLoading = true;
  int _liveCount = 0;
  int _upcomingCount = 0;
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final page = await _service.listMeetings(perPage: 50);
      if (!mounted) return;
      setState(() {
        _liveCount = page.meetings.where((m) => m.isLive).length;
        _upcomingCount = page.meetings.where((m) => m.isScheduled).length;
        _completedCount = page.meetings.where((m) => m.isEnded).length;
        _statsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is coming soon')),
    );
  }

  Future<void> _startInstantMeeting() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final now = DateTime.now();
      final meeting = await _service.createMeeting(
        title: 'Instant Meeting',
        scheduledStart: now,
        scheduledEnd: now.add(const Duration(hours: 1)),
      );
      await _service.startMeeting(meeting.token);
      if (mounted) {
        context.push('/room/${meeting.token}', extra: {'startWithVideo': true});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not start meeting: $e'),
          backgroundColor: VtColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _starting = false);
  }

  void _openJoinDialog() {
    showDialog(context: context, builder: (_) => const JoinByCodeDialog());
  }

  void _openScheduleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ScheduleMeetingSheet(onCreated: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting scheduled!'), backgroundColor: VtColors.success),
        );
        _loadStats();
      }),
    );
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
          title: const Text('Home',
              style: TextStyle(color: VtColors.authInk, fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          child: _starting
              ? const Center(child: CircularProgressIndicator(color: VtColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                      children: [
                        _HomeTile(
                          icon: Icons.videocam_rounded,
                          label: 'Start Meeting',
                          color: const Color(0xFFFF9F43),
                          onTap: _startInstantMeeting,
                        ),
                        _HomeTile(
                          icon: Icons.add_rounded,
                          label: 'Join',
                          color: VtColors.primary,
                          onTap: _openJoinDialog,
                        ),
                        _HomeTile(
                          icon: Icons.event_rounded,
                          label: 'Schedule',
                          color: VtColors.primary,
                          onTap: _openScheduleSheet,
                        ),
                        _HomeTile(
                          icon: Icons.screen_share_rounded,
                          label: 'Share screen',
                          color: VtColors.primary,
                          onTap: () => _comingSoon('Share screen'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text('Your meetings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: VtColors.authInk)),
                    const SizedBox(height: 12),
                    _statsLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                                child: CircularProgressIndicator(color: VtColors.primary, strokeWidth: 2)))
                        : Row(children: [
                            Expanded(
                                child: _StatCard(
                                    label: 'Live now', value: '$_liveCount', color: VtColors.success)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _StatCard(
                                    label: 'Upcoming', value: '$_upcomingCount', color: VtColors.primary)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _StatCard(
                                    label: 'Completed',
                                    value: '$_completedCount',
                                    color: VtColors.authInkMuted)),
                          ]),
                  ]),
                ),
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: VtColors.authFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VtColors.authBorder),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: VtColors.authInkMuted, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
