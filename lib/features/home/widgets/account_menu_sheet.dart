import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

void showAccountMenu(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => const AccountMenuSheet(),
  );
}

class AccountMenuSheet extends StatelessWidget {
  const AccountMenuSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Theme(
      data: AppTheme.light,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _Avatar(user: user),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Guest',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: VtColors.authInk)),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '',
                          style: const TextStyle(fontSize: 13, color: VtColors.authInkMuted)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1, color: VtColors.authBorder),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile is coming soon')),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings is coming soon')),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Help & Support is coming soon')),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: VtColors.authBorder),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.logout_rounded,
                label: 'Logout',
                color: VtColors.danger,
                onTap: () {
                  Navigator.pop(context);
                  context.read<AuthProvider>().logout().then((_) {
                    if (context.mounted) context.go('/login');
                  });
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final photo = user?.photoUrl;
    return CircleAvatar(
      radius: 28,
      backgroundColor: VtColors.primaryBg,
      backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
      child: (photo == null || photo.isEmpty)
          ? Text(user?.initials ?? '?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: VtColors.primary))
          : null,
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? VtColors.authInk;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: tint),
      title: Text(label, style: TextStyle(color: tint, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
