import 'package:flutter/material.dart';

/// Animations for message send and receive effects.
class MessageAnimations {
  /// Creates a fade-in animation for messages.
  static Animation<double> createFadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeIn),
    );
  }

  /// Creates a slide-in animation for messages.
  /// [isSent] determines direction: true for sent (right to left), false for received (left to right).
  static Animation<Offset> createSlideAnimation(AnimationController controller, bool isSent) {
    return Tween<Offset>(
      begin: isSent ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );
  }

  /// Creates a combined fade and slide animation for messages.
  static Animation<Offset> createFadeSlideAnimation(AnimationController controller, bool isSent) {
    return Tween<Offset>(
      begin: isSent ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );
  }

  /// Creates a scale animation for message appearance.
  static Animation<double> createScaleAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );
  }
}

/// A widget that applies send/receive animations to a message container.
class AnimatedMessage extends StatelessWidget {
  const AnimatedMessage({
    Key? key,
    required this.child,
    required this.animationController,
    required this.isSent,
  }) : super(key: key);

  final Widget child;
  final AnimationController animationController;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    final fadeAnimation = MessageAnimations.createFadeAnimation(animationController);
    final slideAnimation = MessageAnimations.createSlideAnimation(animationController, isSent);

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }
}