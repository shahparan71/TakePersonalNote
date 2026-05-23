import 'package:flutter/material.dart';

/// Wraps bottom sheet content so it clears the home [NavigationBar].
class SheetSafeArea extends StatelessWidget {
  final Widget child;
  final bool includeNavBar;

  const SheetSafeArea({super.key, required this.child, this.includeNavBar = true});

  static double bottomInset(BuildContext context, {bool includeNavBar = true}) {
    final padding = MediaQuery.paddingOf(context).bottom;
    return padding + (includeNavBar ? kBottomNavigationBarHeight : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset(context, includeNavBar: includeNavBar)),
      child: child,
    );
  }
}
