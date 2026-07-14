import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/meeting_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/join_meeting_sheet.dart';
import '../widgets/meeting_card.dart';
import '../widgets/schedule_meeting_sheet.dart';

enum _ViewMode { list, calendar }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _pageSize = 20;

  final _service = MeetingService();
  final _scrollController = ScrollController();
  List<MeetingModel> _meetings = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  final _joinCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _search = '';
  _ViewMode _view = _ViewMode.list;
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMeetings();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _joinCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_view != _ViewMode.list) return;
    if (_loading || _loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMoreMeetings();
    }
  }

  Future<void> _loadMeetings() async {
    setState(() { _loading = true; _error = null; _page = 1; _hasMore = true; });
    try {
      final result = await _service.listMeetings(page: 1, perPage: _pageSize);
      setState(() {
        _meetings = result.meetings;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      setState(() => _error = 'Could not load meetings. Pull down to retry.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreMeetings() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await _service.listMeetings(page: nextPage, perPage: _pageSize);
      setState(() {
        _page = nextPage;
        _meetings.addAll(result.meetings);
        _hasMore = result.hasMore;
      });
    } catch (_) {
      // silent — user can scroll again to retry
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<MeetingModel> get _filteredMeetings {
    if (_search.trim().isEmpty) return _meetings;
    final q = _search.trim().toLowerCase();
    return _meetings.where((m) => m.title.toLowerCase().contains(q)).toList();
  }

  List<MeetingModel> get _meetingsForSelectedDay {
    return _filteredMeetings.where((m) =>
      m.scheduledStart.year == _selectedDay.year &&
      m.scheduledStart.month == _selectedDay.month &&
      m.scheduledStart.day == _selectedDay.day
    ).toList();
  }

  void _openScheduleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ScheduleMeetingSheet(onCreated: (m) {
        setState(() => _meetings.insert(0, m));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting created!'),
              backgroundColor: VtColors.success),
        );
      }),
    );
  }

  void _joinByToken() {
    final token = _joinCtrl.text.trim();
    final knownName = context.read<AuthProvider>().user?.name;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => JoinMeetingSheet(
        prefillMeetingId: token.isEmpty ? null : token,
        knownName: knownName,
      ),
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
          title: const Text('Meetings',
              style: TextStyle(color: VtColors.authInk, fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        body: RefreshIndicator(
          color: VtColors.primary,
          onRefresh: _loadMeetings,
          child: CustomScrollView(controller: _scrollController, slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _buildSearchAndToggleRow()),
            ),
            SliverToBoxAdapter(child: _buildJoinBanner()),
            if (_loading)
              const SliverFillRemaining(child: Center(
                child: CircularProgressIndicator(color: VtColors.primary)))
            else if (_error != null)
              SliverFillRemaining(child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 48, color: VtColors.authInkMuted),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: VtColors.authInkMuted),
                      textAlign: TextAlign.center),
                ])))
            else if (_view == _ViewMode.calendar)
              ..._buildCalendarSlivers()
            else
              ..._buildListSlivers(),
          ]),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openScheduleSheet,
          backgroundColor: VtColors.primary,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSearchAndToggleRow() {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 14, color: VtColors.authInk),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search meetings',
            hintStyle: const TextStyle(color: VtColors.authInkMuted, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: VtColors.authInkMuted, size: 20),
            filled: true, fillColor: VtColors.authFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: VtColors.authBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: VtColors.authBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: VtColors.primary, width: 1.5)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      _ViewToggleButton(
        icon: Icons.view_list_rounded,
        selected: _view == _ViewMode.list,
        onTap: () => setState(() => _view = _ViewMode.list),
      ),
      const SizedBox(width: 4),
      _ViewToggleButton(
        icon: Icons.calendar_month_rounded,
        selected: _view == _ViewMode.calendar,
        onTap: () => setState(() => _view = _ViewMode.calendar),
      ),
    ]);
  }

  List<Widget> _buildListSlivers() {
    final meetings = _filteredMeetings;
    if (meetings.isEmpty) {
      return [const SliverFillRemaining(child: Center(child: _EmptyState()))];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MeetingCard(meeting: meetings[i]),
            ),
            childCount: meetings.length,
          ),
        ),
      ),
      if (_loadingMore)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator(color: VtColors.primary, strokeWidth: 2)),
          ),
        )
      else
        const SliverPadding(padding: EdgeInsets.only(bottom: 24), sliver: SliverToBoxAdapter(child: SizedBox.shrink())),
    ];
  }

  List<Widget> _buildCalendarSlivers() {
    final dayMeetings = _meetingsForSelectedDay;
    return [
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            border: Border.all(color: VtColors.authBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CalendarDatePicker(
            initialDate: _selectedDay,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            onDateChanged: (d) => setState(() => _selectedDay = d),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverToBoxAdapter(
          child: Text(DateFormat('EEEE, MMM d').format(_selectedDay),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: VtColors.authInk)),
        ),
      ),
      if (dayMeetings.isEmpty)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Text('No meetings on this day', style: TextStyle(color: VtColors.authInkMuted)),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MeetingCard(meeting: dayMeetings[i]),
              ),
              childCount: dayMeetings.length,
            ),
          ),
        ),
    ];
  }

  Widget _buildJoinBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VtColors.authFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VtColors.authBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Join a meeting',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: VtColors.authInk)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _joinCtrl,
              style: const TextStyle(fontSize: 14, color: VtColors.authInk),
              decoration: InputDecoration(
                hintText: 'Enter meeting ID or link',
                hintStyle: const TextStyle(color: VtColors.authInkMuted, fontSize: 14),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VtColors.authBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VtColors.authBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: VtColors.primary, width: 1.5)),
              ),
              onSubmitted: (_) => _joinByToken(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            height: 48,
            child: ElevatedButton(
              onPressed: _joinByToken,
              style: ElevatedButton.styleFrom(
                backgroundColor: VtColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Join', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({required this.icon, required this.selected, required this.onTap});
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: selected ? VtColors.primaryBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? VtColors.primary : VtColors.authBorder),
        ),
        child: Icon(icon, size: 20, color: selected ? VtColors.primary : VtColors.authInkMuted),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: VtColors.primaryBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.video_call_rounded, size: 36, color: VtColors.primary),
      ),
      const SizedBox(height: 16),
      const Text('No meetings yet',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: VtColors.authInk)),
      const SizedBox(height: 6),
      const Text('Schedule your first meeting to get started',
        style: TextStyle(color: VtColors.authInkMuted)),
    ],
  );
}
