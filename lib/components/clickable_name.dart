import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class ClickableName extends StatefulWidget {
  final String name;
  final String? userId;
  final bool showPrefix;
  final String prefix;
  final TextStyle? textStyle;
  final VoidCallback? onPress;

  const ClickableName({
    super.key,
    required this.name,
    this.userId,
    this.showPrefix = false,
    this.prefix = 'by ',
    this.textStyle,
    this.onPress,
  });

  @override
  State<ClickableName> createState() => _ClickableNameState();
}

class _ClickableNameState extends State<ClickableName>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  Future<void> _handleTap() async {
    HapticFeedback.lightImpact();
    
    if (widget.onPress != null) {
      widget.onPress!();
    } else if (widget.userId != null) {
      context.push('/public-profile/${widget.userId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Text(
            '${widget.showPrefix ? widget.prefix : ''}${widget.name}',
            style: widget.textStyle ??
                const TextStyle(
                  color: Color(0xFF8b5cf6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

