import 'package:flutter/material.dart';

class BadgeNaoLidas extends StatelessWidget {
  final int quantidade;
  final Widget child;

  const BadgeNaoLidas({
    super.key,
    required this.quantidade,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (quantidade <= 0) return child;
    final label = quantidade > 99 ? '99+' : '$quantidade';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 18),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
