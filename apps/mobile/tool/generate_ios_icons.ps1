# Deterministic asset sizing from the existing ASTHA logo; no new artwork.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$mobileRoot = Split-Path -Parent $PSScriptRoot
$source = [System.Drawing.Image]::FromFile((Join-Path $mobileRoot 'assets/logo.png'))
$target = Join-Path $mobileRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
try {
    $catalog = Get-Content -LiteralPath (Join-Path $target 'Contents.json') -Raw | ConvertFrom-Json
    foreach ($entry in $catalog.images | Sort-Object filename -Unique) {
        $points = [double]::Parse(($entry.size -split 'x')[0], [Globalization.CultureInfo]::InvariantCulture)
        $scale = [int]($entry.scale -replace 'x', '')
        $pixels = [int]($points * $scale)
        $bitmap = [System.Drawing.Bitmap]::new($pixels, $pixels, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($source, 0, 0, $pixels, $pixels)
            $bitmap.Save((Join-Path $target $entry.filename), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
} finally { $source.Dispose() }
