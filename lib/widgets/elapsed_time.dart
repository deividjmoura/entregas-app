import 'dart:async';
import 'package:flutter/material.dart';

class ElapsedTime extends StatefulWidget {
  final DateTime desde;
  final TextStyle? style;

  const ElapsedTime({super.key, required this.desde, this.style});

  @override
  State<ElapsedTime> createState() => _ElapsedTimeState();
}

class _ElapsedTimeState extends State<ElapsedTime> {
  Timer? _t;
  Duration _d = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _d = DateTime.now().difference(widget.desde));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String get _label {
    final m = _d.inMinutes;
    final s = _d.inSeconds % 60;
    if (_d.inHours > 0) {
      return '${_d.inHours}h ${m % 60}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(_label, style: widget.style ?? const TextStyle(fontSize: 12));
  }
}
