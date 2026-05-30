import 'package:flutter/material.dart';

class PantheonBoard extends StatefulWidget {
  const PantheonBoard({super.key});

  @override
  State<PantheonBoard> createState() => _PantheonBoardState();
}

class _PantheonBoardState extends State<PantheonBoard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Row for 2nd and 3rd place
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildPodiumColumn(
                rank: 2,
                height: 140,
                name: "GariVudi",
                color: Colors.blueGrey.shade300,
              ),
              const SizedBox(width: 100), // Space for 1st place in the middle
              _buildPodiumColumn(
                rank: 3,
                height: 110,
                name: "Shadow",
                color: Colors.brown.shade400,
              ),
            ],
          ),
          // 1st Place (Center front)
          Positioned(
            bottom: 0,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double glowIntensity = 10 + (_pulseController.value * 20);
                return _buildPodiumColumn(
                  rank: 1,
                  height: 180,
                  name: "Lider_TR",
                  color: const Color(0xFFFFB800),
                  isGold: true,
                  glowIntensity: glowIntensity,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required int rank,
    required double height,
    required String name,
    required Color color,
    bool isGold = false,
    double glowIntensity = 0,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Name and Guild
        Text(
          name,
          style: TextStyle(
            color: isGold ? color : Colors.white70,
            fontWeight: FontWeight.bold,
            shadows: isGold ? [Shadow(color: color, blurRadius: 10)] : [],
          ),
        ),
        const SizedBox(height: 8),
        // Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              if (isGold)
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: glowIntensity,
                ),
            ],
            gradient: RadialGradient(
              colors: [color.withOpacity(0.3), Colors.transparent],
            ),
          ),
          child: CircleAvatar(
            radius: isGold ? 35 : 30, // Larger for 1st place
            backgroundColor: const Color(0xFF161E34),
            child: Icon(Icons.person, color: color, size: isGold ? 40 : 35),
          ),
        ),
        const SizedBox(height: 10),
        // Podium Column
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color.withOpacity(0.1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          child: Center(
            child: Text(
              "#$rank",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
