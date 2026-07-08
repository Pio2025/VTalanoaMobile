import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/vt_button.dart';
import '../widgets/guest_join_sheet.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is coming soon')),
    );
  }

  void _openJoinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VtColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const GuestJoinSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.settings_outlined),
                color: VtColors.authInk,
                iconSize: 26,
                onPressed: () => _comingSoon(context, 'Settings'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  Center(
                    child: Image.asset('assets/logos/logo-web.png', width: 220),
                  ),
                  const Spacer(flex: 2),
                  const Text('Welcome',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: VtColors.authInk,
                          fontSize: 28,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Get started with your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: VtColors.authInkMuted, fontSize: 15)),
                  const Spacer(flex: 3),
                  VtButton(
                    label: 'Join a Meeting',
                    icon: Icons.videocam_rounded,
                    onPressed: () => _openJoinSheet(context),
                  ),
                  const SizedBox(height: 14),
                  VtButton(
                    label: 'Sign In',
                    outlined: true,
                    onPressed: () => context.go('/login'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?",
                          style: TextStyle(color: VtColors.authInkMuted, fontSize: 14)),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Sign Up',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
