import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/coming_soon_view.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

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
          title: const Text('Chats', style: TextStyle(color: VtColors.authInk)),
        ),
        body: const ComingSoonView(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Chats are coming soon',
        ),
      ),
    );
  }
}
