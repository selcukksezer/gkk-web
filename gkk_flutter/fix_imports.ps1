$content = Get-Content 'f:\gkk-web\gkk_flutter\lib\screens\home\home_screen.dart' -Raw
$content = $content -replace "import 'package:google_fonts/google_fonts.dart';\r?\n\r?\nclass _CratePromoBanner", "class _CratePromoBanner"
$content = "import 'package:google_fonts/google_fonts.dart';
" + $content
Set-Content -Path 'f:\gkk-web\gkk_flutter\lib\screens\home\home_screen.dart' -Value $content
