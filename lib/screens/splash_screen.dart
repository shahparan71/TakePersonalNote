import 'package:flutter/material.dart';
import 'package:take_personal_note/services/preference_service.dart';
import 'package:take_personal_note/theme/app_colors.dart';
import 'package:take_personal_note/theme/app_colors.dart';
import '../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Artificial delay to show the splash screen
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Check session using PreferenceService which uses SharedPreferences
    final prefs = PreferenceService();
    final isLocked = await prefs.isAppLockEnabled();

    if (isLocked) {
      Navigator.pushReplacementNamed(context, AppRoutes.lock);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.scaffoldBg,
      body: Center(
        child: Image.asset(
          'assets/app_icon_2.png',
          width: 150,
          height: 150,
        ),
      ),
    );
  }
}
