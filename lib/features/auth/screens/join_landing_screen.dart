import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/vt_log.dart';
import '../widgets/guest_join_sheet.dart';

/// Landing screen for `https://vtalanoa.com/join/:token` and `/room/:token`
/// deep links. Authenticated users are redirected straight to `/room/:token`
/// by [VtApp]'s router `redirect` before this screen ever builds — this
/// screen only handles the guest (not signed in) case, opening the
/// name-entry sheet pre-filled with the token from the link.
class JoinLandingScreen extends StatefulWidget {
  const JoinLandingScreen({super.key, required this.token});
  final String token;

  @override
  State<JoinLandingScreen> createState() => _JoinLandingScreenState();
}

class _JoinLandingScreenState extends State<JoinLandingScreen> {
  bool _sheetShown = false;

  void _showGuestSheet() {
    if (_sheetShown) return;
    _sheetShown = true;
    vtLog('deeplink', 'opening GuestJoinSheet prefill=${widget.token}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GuestJoinSheet(prefillMeetingId: widget.token),
    ).then((_) {
      if (mounted) context.go('/welcome');
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    vtLog('deeplink', 'JoinLandingScreen build token=${widget.token} authStatus=${auth.status}');
    if (auth.status != AuthStatus.unknown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGuestSheet();
      });
    }
    return const Scaffold(
      backgroundColor: VtColors.bg,
      body: Center(child: CircularProgressIndicator(color: VtColors.primary)),
    );
  }
}
