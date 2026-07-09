import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter's default ErrorWidget renders a blank grey box in release/profile
  // mode when a build() throws — that makes real bugs look like "nothing
  // displays". Show the actual error text instead so failures are visible.
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
    color: const Color(0xFF0F172A),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          '${details.exception}',
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ),
    ),
  );

  // Force portrait on phones; allow all on tablets/desktop
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const VtApp());
}
