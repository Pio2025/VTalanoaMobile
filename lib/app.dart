import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/vt_log.dart';
import 'features/auth/screens/join_landing_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/dashboard/screens/meeting_detail_screen.dart';
import 'features/home/screens/main_shell.dart';
import 'features/room/screens/room_screen.dart';
import 'features/splash/screens/splash_screen.dart';

class VtApp extends StatefulWidget {
  const VtApp({super.key});

  @override
  State<VtApp> createState() => _VtAppState();
}

class _VtAppState extends State<VtApp> {
  final _auth = AuthProvider();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  late final GoRouter _router;

  // `checkSession()` can resolve almost instantly (e.g. no stored token),
  // which otherwise fires the redirect before the splash screen ever paints
  // a frame. Hold the splash route up for a minimum duration so the logo
  // and loader are actually visible on every app launch.
  bool _minSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    _auth.checkSession();
    _router = _buildRouter();
    _initDeepLinks();
    Future.delayed(const Duration(milliseconds: 900), () {
      _minSplashElapsed = true;
      _router.refresh();
    });
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/splash',
      // Re-runs `redirect` whenever auth state changes, without recreating
      // this GoRouter instance — required so the deep-link listener below
      // can keep calling `.go()` on a stable router reference.
      refreshListenable: _auth,
      redirect: (ctx, state) {
        final status = auth.status;
        final loc = state.matchedLocation;
        vtLog('router', 'redirect check loc=$loc authStatus=$status');
        final onSplash = loc == '/splash';
        if (status == AuthStatus.unknown || !_minSplashElapsed) {
          return onSplash ? null : '/splash';
        }

        final goingToAuth = loc == '/welcome' || loc == '/login' || loc == '/register';
        final isRoomRoute = loc.startsWith('/room/');
        final isJoinLink = loc.startsWith('/join/');

        if (status == AuthStatus.authenticated) {
          if (isJoinLink) {
            final token = state.pathParameters['token'];
            if (token != null) {
              vtLog('router', 'authenticated join-link -> /room/$token');
              return '/room/$token';
            }
          }
          if (goingToAuth || onSplash) return '/meetings';
          return null;
        }

        // Unauthenticated: allow the auth screens, /join/ links (handled by
        // JoinLandingScreen), and /room/ links directly. Meetings never
        // require an account — only a valid meeting ID and password (if
        // set) — so RoomScreen itself collects a guest name/password when
        // it's reached without a completed guest handshake or a session.
        if (onSplash) return '/welcome';
        if (!goingToAuth && !isRoomRoute && !isJoinLink) return '/login';
        return null;
      },
      routes: [
        GoRoute(path: '/splash',    builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/welcome',   builder: (_, __) => const WelcomeScreen()),
        GoRoute(path: '/login',     builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register',  builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/meetings', builder: (_, __) => const MainShell()),
        GoRoute(
          path: '/meetings/:token',
          builder: (_, state) => MeetingDetailScreen(token: state.pathParameters['token']!),
        ),
        GoRoute(
          path: '/join/:token',
          builder: (_, state) => JoinLandingScreen(token: state.pathParameters['token']!),
        ),
        GoRoute(
          path: '/room/:token',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return RoomScreen(
              token: state.pathParameters['token']!,
              guestName:  extra?['guestName'] as String?,
              guestToken: extra?['guestToken'] as String?,
              guestWaitingRoom: extra?['waiting'] as bool? ?? false,
              guestMeetingId: extra?['guestMeetingId'] as String?,
              startWithVideo: extra?['startWithVideo'] as bool? ?? true,
              meetingPassword: extra?['meetingPassword'] as String?,
            );
          },
        ),
      ],
    );
  }

  AuthProvider get auth => _auth;

  Future<void> _initDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      vtLog('deeplink', 'cold-start initial link: $initial');
      if (initial != null) _handleLink(initial);
    } catch (e) {
      vtLog('deeplink', 'getInitialLink() failed: $e');
    }
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (Object e) => vtLog('deeplink', 'uriLinkStream error: $e'),
    );
  }

  void _handleLink(Uri uri) {
    vtLog('deeplink', 'received link: $uri (pathSegments=${uri.pathSegments})');
    final segments = uri.pathSegments;
    if (segments.length >= 2 && (segments[0] == 'join' || segments[0] == 'room')) {
      final token = segments[1];
      vtLog('deeplink', 'routing to /join/$token');
      _router.go('/join/$token');
    } else {
      vtLog('deeplink', 'unrecognized link shape, ignoring');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _auth,
      child: MaterialApp.router(
        title: 'VTalano',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: _router,
      ),
    );
  }
}
