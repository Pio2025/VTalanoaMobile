import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ComingSoonView extends StatelessWidget {
  const ComingSoonView({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 56, color: VtColors.authInkMuted),
      const SizedBox(height: 16),
      Text(label, style: const TextStyle(color: VtColors.authInkMuted, fontSize: 15)),
    ]),
  );
}
