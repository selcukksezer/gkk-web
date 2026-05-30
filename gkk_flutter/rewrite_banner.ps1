$content = Get-Content 'f:\gkk-web\gkk_flutter\lib\screens\home\home_screen.dart' -Raw
$pattern = 'class _CratePromoBanner extends StatelessWidget \{[\s\S]*?class _GridPainter'
$newClass = @'
class _CratePromoBanner extends StatelessWidget {
  const _CratePromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Sýnýr taþmasýna izin verecek þekilde dýþarýdan biraz boþluk býrakýyoruz
    // ve yüksekliðini 200 yapýyoruz ki overflow (RenderFlex) sorunu olmasýn.
    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.only(top: 25, right: 15), 
      child: Stack(
        clipBehavior: Clip.none, // Resmin kutudan dýþarý taþmasýný saðlar!
        children: [
          // 1. Arkaplan Kutusu (Kýrmýzý Radial Gradient ve Grid)
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
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              // Grid çizgilerini borderRadius'a uygun kesmek (ClipRRect)
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Opacity(
                  opacity: 0.05,
                  child: CustomPaint(
                    painter: _GridPainter(),
                  ),
                ),
              ),
            ),
          ),

          // 2. Kutu/Sandýk Görseli (Ekteki Kasa - Timer'ýn arkasýnda kalacak, yani timer'dan önce eklenmeli)
          // "uçlarý görseldeki gibi taþsýn" isteði -> bottom ve top deðerlerini geniþ veriyoruz.
          Positioned(
            right: -10, // Biraz saða doðru taþsýn
            top: -40,   // Üste doðru epeyce taþsýn
            bottom: -5,
            width: 200,
            child: Image.asset(
              'assets/items/mystic_crate.png', // Kasa resmini buraya kaydedin!
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Resim yoksa yer tutucu (Image.asset hatasýný görmezden gelmek için)
                return const Center(child: Icon(Icons.inventory_2, size: 80, color: Colors.white24));
              },
            ),
          ),

          // 3. çerik (Sola Yaslý Yazýlar ve Buton)
          Positioned(
             left: 20,
             top: 24,
             bottom: 24,
             right: 170, // Resmin altýnda kalmamasý için saðdan daralttýk
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
                    'Sýnýrlý bir süre için.\nEfsanevi hediyeler seni bekliyor.',
                    style: GoogleFonts.urbanist(
                      textStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16), // Spacer yerine SizedBox ile overflow engellendi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF20000), Color(0xFFA60000)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '500 ile Aç',
                          style: GoogleFonts.urbanist(
                            textStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.star, color: Colors.yellow, size: 20),
                      ],
                    ),
                  ),
                ],
             ),
          ),

          // 4. Sayaç (Timer) Kasa resminin üzerinde olacak (Aþaðýda ve saðda)
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
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
        Text(value, style: GoogleFonts.urbanist(textStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
        Text(label, style: GoogleFonts.urbanist(textStyle: const TextStyle(color: Colors.white60, fontSize: 10))),
      ],
    );
  }

  Widget _buildTimeDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(':', style: GoogleFonts.urbanist(textStyle: const TextStyle(color: Colors.white30, fontSize: 18, fontWeight: FontWeight.bold))),
    );
  }
}

class _GridPainter
'@
$content = [regex]::Replace($content, $pattern, $newClass)

# Encoding utf8 zorlamasý, BOM (Byte Order Mark) olmadan.
[IO.File]::WriteAllText('f:\gkk-web\gkk_flutter\lib\screens\home\home_screen.dart', $content)
