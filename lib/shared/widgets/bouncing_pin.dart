import 'package:flutter/material.dart';

class BouncingPin extends StatefulWidget {
  final bool isPlacing;

  const BouncingPin({Key? key, required this.isPlacing}) : super(key: key);

  @override
  _BouncingPinState createState() => _BouncingPinState();
}

class _BouncingPinState extends State<BouncingPin>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: -15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });

    if (widget.isPlacing) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(BouncingPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlacing) {
      _controller.forward();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: Image.asset(
        'assets/icons/pin_marker.png',
        width: 48,
        height: 48,
      ),
    );
  }
}
