import 'package:flutter/material.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../widgets/account_menu_sheet.dart';
import 'chats_tab.dart';
import 'home_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    HomeTab(),
    DashboardScreen(),
    ChatsTab(),
  ];

  void _onTap(int i) {
    if (i == 3) {
      showAccountMenu(context);
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF262262),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        selectedLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(color: Colors.white70),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time_rounded), label: 'Meetings'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_rounded), label: 'Menu'),
        ],
      ),
    );
  }
}
