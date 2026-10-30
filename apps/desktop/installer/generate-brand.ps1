param([string]$OutputDirectory = "$PSScriptRoot")
Add-Type -AssemblyName System.Drawing
$ink=[Drawing.ColorTranslator]::FromHtml('#111318')
$muted=[Drawing.ColorTranslator]::FromHtml('#65738A')
$blue=[Drawing.ColorTranslator]::FromHtml('#2148FF')
function Text($g,$value,$size,$style,$color,$x,$y){
  $font=[Drawing.Font]::new('Segoe UI',$size,$style,[Drawing.GraphicsUnit]::Pixel)
  $brush=[Drawing.SolidBrush]::new($color)
  $g.DrawString($value,$font,$brush,[single]$x,[single]$y)
  $brush.Dispose(); $font.Dispose()
}
foreach($name in @('installer-sidebar','uninstaller-sidebar','header')){
 $header=$name -eq 'header'; $w=328; $h=628
 if($header){$w=300;$h=114}
 $bmp=[Drawing.Bitmap]::new($w,$h,[Drawing.Imaging.PixelFormat]::Format24bppRgb)
 $g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.Color]::White)
 $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
 $g.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit
 $dot=[Drawing.SolidBrush]::new($blue);$g.FillEllipse($dot,24,30,10,10);$dot.Dispose()
 Text $g 'ASTHA' 42 ([Drawing.FontStyle]::Bold) $ink 40 17
 Text $g 'R A V E N' 13 ([Drawing.FontStyle]::Regular) $muted 45 68
 if(-not $header){
   $line=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#E4E8F0'),2)
   $g.DrawLine($line,26,124,296,124);$line.Dispose()
   Text $g 'SEU ESPAÇO.' 16 ([Drawing.FontStyle]::Bold) $muted 27 155
   Text $g 'Uma visão' 32 ([Drawing.FontStyle]::Bold) $ink 23 194
   Text $g 'mais clara.' 32 ([Drawing.FontStyle]::Bold) $ink 23 234
   Text $g 'Materiais, ambientes' 19 ([Drawing.FontStyle]::Regular) $muted 27 303
   Text $g 'e ideias conectados.' 19 ([Drawing.FontStyle]::Regular) $muted 27 330
   $pen=[Drawing.Pen]::new($ink,2)
   $accent=[Drawing.Pen]::new($blue,3)
   $g.DrawPolygon($pen,[Drawing.Point[]]@([Drawing.Point]::new(45,439),[Drawing.Point]::new(164,380),[Drawing.Point]::new(283,439),[Drawing.Point]::new(164,499)))
   $g.DrawLine($pen,45,439,45,476);$g.DrawLine($pen,45,476,164,536);$g.DrawLine($pen,164,499,164,536)
   $g.DrawLine($accent,164,536,283,476);$g.DrawLine($accent,283,476,283,439)
   $g.DrawLine($pen,105,410,224,469);$g.DrawLine($pen,105,469,224,410)
   $pen.Dispose();$accent.Dispose()
   if($name -eq 'uninstaller-sidebar'){$label='DESINSTALAÇÃO'}else{$label='DESKTOP / WINDOWS'}
   Text $g $label 13 ([Drawing.FontStyle]::Bold) $muted 27 582
 }
 $g.Dispose();$bmp.Save((Join-Path $OutputDirectory ($name+'.bmp')),[Drawing.Imaging.ImageFormat]::Bmp);$bmp.Dispose()
}
