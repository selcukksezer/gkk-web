import 'dart:ui';

import 'package:flutter/material.dart';

class LiveTicker extends StatefulWidget {
  const LiveTicker({super.key});

  @override
  State<LiveTicker> createState() => _LiveTickerState();
}

class _LiveTickerState extends State<LiveTicker> with SingleTickerProviderStateMixin {
  late AnimationController _scrollController;

  final List<String> _feedItems = [
    "🔥 Ahmet Efsanevi Kılıç düşürdü!",
    "⚔️ Klan X Zindanı temizledi",
    "📈 Pazarda Altın fiyatları arttı",
    "💀 Shadow23 arenada namağlup",
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A glassmorphism horizontal bar
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF161E34).withOpacity(0.4),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  AnimatedBuilder(
                    animation: _scrollController,
                    builder: (context, child) {
                      // Move from right to left
                      final offset = (1.0 - _scrollController.value) * constraints.maxWidth * 2 - constraints.maxWidth;
                      return Positioned(
                        left: offset,
                        top: 6,
                        child: Row(
                          children: _feedItems.map((item) => Padding(
                            padding: const EdgeInsets.only(right: 40),
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.white, Color(0xFFFFD700), Colors.white],
                                stops: [0.0, 0.5, 1.0],
                              ).createShader(bounds),
                              child: Text(
                                item,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                            ),
                          )).toList(),
                        ),
                      );
                    },
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}
