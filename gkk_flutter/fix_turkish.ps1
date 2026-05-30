$bytes = [System.IO.File]::ReadAllBytes('f:\gkk-web\gkk_flutter\lib\screens\home\home_screen.dart')
$text = [System.Text.Encoding]::UTF8.GetString($bytes)

$text = $text -replace 'S\u00C3\u0192\u00C2\u00B1n\u00C3\u0192\u00C2\u00B1rl\u00C3\u0192\u00C2\u00B1', 'Sýnýrlý'
$text = $text -replace 's\u00C3\u0192\u00C2\u00BCre', 'süre'
$text = $text -replace 'i\u00C3\u0192\u00C2\u00A7in', 'için'
$text = $text -replace 'A\u00C3\u0192\u00C2\u00AF\u00C2\u00BF\u00C2\u00BD', 'AÇ'
$text = $text -replace 'S\u00C3\u0192\u00C2\u00A2\u00C3\u00A2\u00C2\u0082\u00C2\u00AC\u00C3\u00A2\u00C2\u0080\u00C2\u00A0n\u00C3\u0192\u00C2\u00A2\u00C3\u00A2\u00C2\u0082\u00C2\u00AC\u00C3\u00A2\u00C2\u0080\u00C2\u00A0rl\u00C3\u0192\u00C2\u00A2\u00C3\u00A2\u00C2\u0082\u00C2\u00AC\u00C3\u00A2\u00C2\u0080\u00C2\u00A0', 'Sýnýrlý'
$text = $text -replace 's\u00C3\u0192\u00C3\u201A\u00C2\u00BCre', 'süre'
$text = $text -replace 'i\u00C3\u0192\u00C3\u201A\u00C2\u00A7in', 'için'
$text = $text -replace 'KASA A\u00C3\u2021', 'KASA AÇ'

[System.IO.File]::WriteAllText('f:\gkk-web\gkk_flutter\lib\screens\home\home_screen.dart', $text, [System.Text.Encoding]::UTF8)
