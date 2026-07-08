import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Row of "continue with" identity provider buttons shown on the
/// login/register screens. [onSelect] receives the provider id
/// ('google' | 'facebook' | 'microsoft' | 'apple' | 'navuli').
class SocialAuthRow extends StatelessWidget {
  const SocialAuthRow({super.key, required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _SocialButton(
        tooltip: 'Continue with Google',
        onTap: () => onSelect('google'),
        child: const Text('G',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4285F4),
            )),
      ),
      _SocialButton(
        tooltip: 'Continue with Facebook',
        onTap: () => onSelect('facebook'),
        child: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 26),
      ),
      _SocialButton(
        tooltip: 'Continue with Microsoft',
        onTap: () => onSelect('microsoft'),
        child: const _MicrosoftGlyph(),
      ),
      _SocialButton(
        tooltip: 'Continue with Apple',
        onTap: () => onSelect('apple'),
        child: const Icon(Icons.apple, color: Colors.black, size: 24),
      ),
      _SocialButton(
        tooltip: 'Continue with Navuli',
        onTap: () => onSelect('navuli'),
        child: Image.asset('assets/navuli/favicon-16x16.png', width: 22, height: 22),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: AspectRatio(aspectRatio: 1, child: buttons[i])),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.child, required this.onTap, required this.tooltip});

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: VtColors.authBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _MicrosoftGlyph extends StatelessWidget {
  const _MicrosoftGlyph();

  @override
  Widget build(BuildContext context) {
    Widget square(Color color) => Container(width: 10, height: 10, color: color);
    return SizedBox(
      width: 22,
      height: 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            square(const Color(0xFFF25022)),
            square(const Color(0xFF7FBA00)),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            square(const Color(0xFF00A4EF)),
            square(const Color(0xFFFFB900)),
          ]),
        ],
      ),
    );
  }
}
