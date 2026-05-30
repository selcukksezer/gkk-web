class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    final cell = 20.0;
    for (var x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CratePromoBanner extends StatelessWidget {
  const _CratePromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.only(top: 30, right: 15, left: 5, bottom: 5),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background layer
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const RadialGradient(
                  center: Alignment(0.6, 0.0),
                  radius: 1.5,
                  colors: [
                    Color(0xFF8B0000),
                    Color(0xFF1A0000),
                  ],
                ),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: _GridPainter(),
                ),
              ),
            ),
          ),
          // Image escaping bounds
          Positioned(
            right: -20,
            top: -45,
            bottom: 30,
            width: 180,
            child: Image.asset(
              'assets/elements/redcase512px.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          // Left Content
          Positioned(
            left: 20,
            top: 24,
            bottom: 24,
            right: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'KASA AÇ',
                  style: GoogleFonts.urbanist(
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sınırlı bir süre için.\nEfsanevi hediyeler seni bekliyor.',
                  style: GoogleFonts.urbanist(
                    textStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF20000), Color(0xFFA60000)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '500',
                        style: GoogleFonts.urbanist(
                          textStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Colors.yellow, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'ile Aç',
                        style: GoogleFonts.urbanist(
                          textStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Timer Right Bottom
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimeBlock('06', 'Sa'),
                  _buildTimeDivider(),
                  _buildTimeBlock('32', 'Dk'),
                  _buildTimeDivider(),
                  _buildTimeBlock('12', 'Sn'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBlock(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: GoogleFonts.urbanist(textStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
        Text(label, style: GoogleFonts.urbanist(textStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10))),
      ],
    );
  }

  Widget _buildTimeDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(':', style: GoogleFonts.urbanist(textStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 16, fontWeight: FontWeight.bold))),
    );
  }
}
