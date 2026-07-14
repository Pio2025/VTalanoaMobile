import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/vt_button.dart';
import '../../../shared/widgets/join_meeting_sheet.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openJoinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const JoinMeetingSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
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
                // push (not go) so the back button returns here instead of
                // minimising the app — go() replaces the whole nav stack,
                // leaving /login with nothing beneath it to pop to.
                onPressed: () => context.push('/login'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?",
                      style: TextStyle(color: VtColors.authInkMuted, fontSize: 14)),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Sign Up',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
