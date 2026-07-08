import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Centered brand logo + title + subtitle used at the top of the
/// login and register screens.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/logos/logo-web.png', height: 40),
        const SizedBox(height: 32),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: VtColors.authInk,
            )),
        const SizedBox(height: 8),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: VtColors.authInkMuted)),
      ],
    );
  }
}

/// Plain white/near-white backdrop for the auth screens.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(color: VtColors.authBg, child: child);
  }
}

/// Divider with centered "or continue with" style label.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key, this.label = 'or continue with'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: Divider(color: VtColors.authBorder)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label, style: const TextStyle(fontSize: 12.5, color: VtColors.authInkMuted)),
      ),
      const Expanded(child: Divider(color: VtColors.authBorder)),
    ]);
  }
}
