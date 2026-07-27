import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class DesignHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const DesignHeader({super.key, required this.title, this.actions, this.leading});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppBar(
      elevation: 0,
      backgroundColor: colors.scaffoldBg,
      leading: leading,
      title: Text(
        title,
        style: GoogleFonts.caveat(fontSize: 32, fontWeight: FontWeight.w600, color: colors.textPrimary),
      ),
      actions: actions,
    );
  }
}

class DesignSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const DesignSearchField({super.key, required this.controller, this.hint = 'Search...', this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 14),
        filled: true,
        fillColor: colors.cardSurface,
        prefixIcon: Icon(Icons.search, size: 20, color: colors.textSecondary.withValues(alpha: 0.8)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.border)),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
    );
  }
}

class DesignFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String? heroTag;

  const DesignFab({super.key, required this.onPressed, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      backgroundColor: context.appColors.fabDark,
      elevation: 4,
      onPressed: onPressed,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}

class CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final double size;

  const CircleActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.45),
        ),
      ),
    );
  }
}

class DesignSectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const DesignSectionTitle({super.key, required this.title, this.trailing, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(trailing!, style: GoogleFonts.outfit(fontSize: 13, color: colors.textSecondary)),
            ),
        ],
      ),
    );
  }
}
