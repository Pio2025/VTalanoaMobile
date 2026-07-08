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
      backgroundColor: VtColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ScheduleMeetingSheet(onCreated: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting scheduled!'), backgroundColor: VtColors.success),
        );
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
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: _HomeTile(
                          icon: Icons.videocam_rounded,
                          label: 'Start Meeting',
                          color: const Color(0xFFFF9F43),
                          onTap: _startInstantMeeting,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HomeTile(
                          icon: Icons.add_rounded,
                          label: 'Join',
                          color: VtColors.primary,
                          onTap: _openJoinDialog,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _HomeTile(
                          icon: Icons.event_rounded,
                          label: 'Schedule',
                          color: VtColors.primary,
                          onTap: _openScheduleSheet,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HomeTile(
                          icon: Icons.screen_share_rounded,
                          label: 'Share screen',
                          color: VtColors.primary,
                          onTap: () => _comingSoon('Share screen'),
                        ),
                      ),
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
        child: Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
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
