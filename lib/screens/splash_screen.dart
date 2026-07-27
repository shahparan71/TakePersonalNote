import 'package:flutter/material.dart';
import 'package:take_personal_note/services/preference_service.dart';
import 'package:take_personal_note/services/reminder_permission_service.dart';
import 'package:take_personal_note/theme/app_colors.dart';
import 'lock_screen.dart';
import 'home_screen.dart';

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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LockScreen()),
      );
      return;
    }

    final shouldShowPrompt = await ReminderPermissionService.instance.shouldShowStartupReminderPrompt();
    if (!mounted) return;

    if (shouldShowPrompt) {
      await ReminderPermissionService.instance.showReminderPermissionDialog(
        context: context,
        hasExistingReminders: true,
        markAsSeen: true,
      );
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
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
