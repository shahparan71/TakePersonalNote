import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class DeleteAnimationDialog extends StatefulWidget {
  final Future<void> Function() onDelete;
  final String? message;

  const DeleteAnimationDialog({
    super.key,
    required this.onDelete,
    this.message,
  });

  /// Displays the deletion animation dialog, executes [onDelete] during the animation,
  /// and automatically closes the dialog once the animation finishes.
  static Future<void> show(
    BuildContext context, {
    required Future<void> Function() onDelete,
    String? message,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (_) => DeleteAnimationDialog(
        onDelete: onDelete,
        message: message,
      ),
    );
  }

  @override
  State<DeleteAnimationDialog> createState() => _DeleteAnimationDialogState();
}

class _DeleteAnimationDialogState extends State<DeleteAnimationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _operationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_operationStarted) {
        _operationStarted = true;
        widget.onDelete().catchError((_) {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/delete.json',
                controller: _controller,
                width: 110,
                height: 110,
                fit: BoxFit.contain,
                onLoaded: (composition) {
                  _controller.duration = composition.duration;
                  _controller.forward();
                },
              ),
              if (widget.message != null && widget.message!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
