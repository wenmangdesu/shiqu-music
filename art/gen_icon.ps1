# 识曲应用图标 — 笔记本涂鸦风（P3同款）
Add-Type -AssemblyName System.Drawing
$outEntry = 'D:\HarmonyOS\Harmonymusic\entry\src\main\resources\base\media'
$outScope = 'D:\HarmonyOS\Harmonymusic\AppScope\resources\base\media'

function HexColor([string]$c) { return [System.Drawing.ColorTranslator]::FromHtml($c) }
function New-Solid([string]$c, [int]$a) {
    $col = HexColor $c
    if ($a -lt 255) { return New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, $col.R, $col.G, $col.B)) }
    return New-Object System.Drawing.SolidBrush($col)
}
function New-PenC([System.Drawing.Brush]$b, [float]$w) {
    $p = New-Object System.Drawing.Pen($b, $w)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    return $p
}
$ink = '#2B3A55'

# ============ foreground.png 1024 透明底：涂鸦音符（居中安全区） ============
$bmp = New-Object System.Drawing.Bitmap(1024, 1024)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$bInk = New-Solid $ink 255
# 红笔小爱心
$bRed = New-Solid '#E5484D' 255
$g.FillEllipse($bRed, 224, 300, 56, 48)
$g.FillEllipse($bRed, 274, 300, 56, 48)
$hpts = @(
    (New-Object System.Drawing.PointF(220, 340)),
    (New-Object System.Drawing.PointF(334, 340)),
    (New-Object System.Drawing.PointF(277, 410))
)
$g.FillPolygon($bRed, $hpts)
# 音符：符头 + 符干 + 符尾
$state = $g.Save()
$g.ResetTransform()
$g.TranslateTransform(500, 570)
$g.RotateTransform(-12)
$g.FillEllipse($bInk, -190, -150, 380, 300)
$g.Restore($state)
$pStem = New-PenC $bInk 46
$g.DrawLine($pStem, 640, 545, 620, 190)
$g.DrawBezier($pStem, 620, 190, 758, 222, 780, 332, 700, 408)
# 脸
$g.FillEllipse((New-Solid '#FDFBF6' 255), 438, 548, 62, 66)
$g.FillEllipse((New-Solid '#FDFBF6' 255), 566, 548, 62, 66)
$g.FillEllipse((New-Solid '#FDFBF6' 255), 500, 606, 60, 70)
$g.FillEllipse((New-Solid '#FF8FA5' 210), 380, 618, 92, 48)
$g.FillEllipse((New-Solid '#FF8FA5' 210), 628, 618, 92, 48)
# 墨色星星
$pSp = New-PenC $bInk 13
$g.DrawLine($pSp, 762, 268, 762, 320)
$g.DrawLine($pSp, 736, 294, 788, 294)
$g.DrawLine($pSp, 348, 210, 348, 252)
$g.DrawLine($pSp, 327, 231, 369, 231)
$bmp.Save("$outEntry\foreground.png")
$bmp.Save("$outScope\foreground.png")
$g.Dispose(); $bmp.Dispose()

# ============ background.png 1024：作业本纸张 ============
$bmp = New-Object System.Drawing.Bitmap(1024, 1024)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.FillRectangle((New-Solid '#FDFBF6' 255), 0, 0, 1024, 1024)
$pLine = New-PenC (New-Solid '#C7DCEC' 255) 6
foreach ($y in 150, 246, 342, 438, 534, 630, 726, 822, 918) {
    $g.DrawLine($pLine, 0, $y, 1024, $y)
}
$g.DrawLine((New-PenC (New-Solid '#F2A9A9' 255) 8), 150, 0, 150, 1024)
$bmp.Save("$outEntry\background.png")
$bmp.Save("$outScope\background.png")
$g.Dispose(); $bmp.Dispose()

# ============ startIcon.png 144：组合小图标 ============
$bmp = New-Object System.Drawing.Bitmap(144, 144)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.FillRectangle((New-Solid '#FDFBF6' 255), 0, 0, 144, 144)
$pLine2 = New-PenC (New-Solid '#C7DCEC' 255) 2
foreach ($y in 40, 72, 104, 136) { $g.DrawLine($pLine2, 0, $y, 144, $y) }
$g.DrawLine((New-PenC (New-Solid '#F2A9A9' 255) 3), 20, 0, 20, 144)
$bInk2 = New-Solid $ink 255
$state = $g.Save()
$g.ResetTransform()
$g.TranslateTransform(66, 78)
$g.RotateTransform(-12)
$g.FillEllipse($bInk2, -30, -24, 60, 46)
$g.Restore($state)
$pStem2 = New-PenC $bInk2 8
$g.DrawLine($pStem2, 94, 72, 91, 22)
$g.DrawBezier($pStem2, 91, 22, 112, 27, 116, 46, 102, 58)
$g.FillEllipse((New-Solid '#FDFBF6' 255), 56, 70, 10, 11)
$g.FillEllipse((New-Solid '#FDFBF6' 255), 74, 70, 10, 11)
$g.FillEllipse((New-Solid '#FDFBF6' 255), 64, 84, 12, 13)
$g.FillEllipse((New-Solid '#FF8FA5' 210), 42, 88, 15, 8)
$g.FillEllipse((New-Solid '#FF8FA5' 210), 88, 88, 15, 8)
$bmp.Save("$outEntry\startIcon.png")
$g.Dispose(); $bmp.Dispose()

Write-Output 'ICON DONE'
