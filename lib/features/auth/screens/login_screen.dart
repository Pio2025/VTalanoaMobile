import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/vt_button.dart';
import '../../../shared/widgets/vt_text_field.dart';
import '../widgets/auth_header.dart';
import '../widgets/social_auth_row.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form     = GlobalKey<FormState>();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  bool _obscure   = true;
  bool _loading   = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().login(
      _email.text.trim(),
      _password.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.go('/meetings');
    } else {
      final err = context.read<AuthProvider>().error ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: VtColors.danger),
      );
    }
  }

  void _socialLogin(String provider) {
    final label = provider[0].toUpperCase() + provider.substring(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label sign-in is coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: VtColors.authBg,
        body: SafeArea(
          child: AuthBackdrop(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      const AuthHeader(
                        title: 'Welcome back',
                        subtitle: 'Sign in to continue to your meetings',
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: VtColors.authBorder),
                          boxShadow: [
                            BoxShadow(
                              color: VtColors.authInk.withOpacity(0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Form(
                              key: _form,
                              child: Column(children: [
                                VtTextField(
                                  controller: _email,
                                  label: 'Email',
                                  hint: 'you@example.com',
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Email is required';
                                    if (!v.contains('@')) return 'Enter a valid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                VtTextField(
                                  controller: _password,
                                  label: 'Password',
                                  obscure: _obscure,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined, size: 20),
                                    color: VtColors.authInkMuted,
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Password is required';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {},
                                    child: const Text('Forgot password?',
                                        style: TextStyle(fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                VtButton(label: 'Sign In', onPressed: _submit, loading: _loading),
                              ]),
                            ),
                            const SizedBox(height: 24),
                            const AuthOrDivider(),
                            const SizedBox(height: 20),
                            SocialAuthRow(onSelect: _socialLogin),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text("Don't have an account? ",
                            style: TextStyle(color: VtColors.authInkMuted)),
                        TextButton(
                          onPressed: () => context.go('/register'),
                          child: const Text('Sign Up'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
