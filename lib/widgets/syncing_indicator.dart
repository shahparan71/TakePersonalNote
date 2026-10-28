import 'package:flutter/material.dart';

class SyncingIndicator extends StatefulWidget {
  final double size;
  final Color color;

  const SyncingIndicator({super.key, this.size = 20, this.color = Colors.green});

  @override
  State<SyncingIndicator> createState() => _SyncingIndicatorState();
}

class _SyncingIndicatorState extends State<SyncingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.sync, color: widget.color, size: widget.size),
    );
  }
}