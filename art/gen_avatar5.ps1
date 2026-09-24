# 识曲头像 v5 — 三种新画风：霓虹灯牌 / 像素团子 / 笔记本涂鸦
Add-Type -AssemblyName System.Drawing

$size = 512
$outDir = 'D:\HarmonyOS\Harmonymusic\art'

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
function New-Bg([string]$c1, [string]$c2) {
    $bmp = New-Object System.Drawing.Bitmap($script:size, $script:size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    if ($c2 -eq '') { $g.FillRectangle((New-Solid $c1 255), 0, 0, $size, $size) }
    else {
        $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
        $g.FillRectangle((New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (HexColor $c1), (HexColor $c2), 55.0)), 0, 0, $size, $size)
    }
    return @($g, $bmp)
}
# 霓虹描线：三次描边模拟发光
function Draw-NeonStroke([System.Drawing.Graphics]$g, [string]$core, [System.Drawing.Drawing2D.GraphicsPath]$path) {
    $g.DrawPath((New-Object System.Drawing.Pen((New-Solid $core 30), 24)), $path)
    $g.DrawPath((New-Object System.Drawing.Pen((New-Solid $core 70), 13)), $path)
    $g.DrawPath((New-Object System.Drawing.Pen((New-Solid '#FFFFFF' 240), 5)), $path)
}

$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center

# ================= P1 霓虹灯牌 =================
$items = New-Bg '#0D0F1A' '#1C1133'
$g = $items[0]
# 外框霓虹蓝
$framePath = New-Object System.Drawing.Drawing2D.GraphicsPath
$r = 70; $w = 440; $h = 440; $ox = 36; $oy = 36
$framePath.AddArc($ox, $oy, $r, $r, 180, 90)
$framePath.AddArc($ox + $w - $r, $oy, $r, $r, 270, 90)
$framePath.AddArc($ox + $w - $r, $oy + $h - $r, $r, $r, 0, 90)
$framePath.AddArc($ox, $oy + $h - $r, $r, $r, 90, 90)
$framePath.CloseFigure()
Draw-NeonStroke $g '#3FB6FF' $framePath
# 音符霓虹粉
$notePath = New-Object System.Drawing.Drawing2D.GraphicsPath
$notePath.AddEllipse(150, 262, 158, 122)
$notePath.AddLine(308, 318, 308, 138)
$pFlag = New-PenC (New-Solid '#000000' 255) 5
$notePath.AddBezier(308, 138, 386, 158, 398, 214, 352, 256)
Draw-NeonStroke $g '#FF4D88' $notePath
# 霓虹文字：多次偏移画光晕，再画亮芯
$fNeon = New-Object System.Drawing.Font('Microsoft YaHei UI', 88, [System.Drawing.FontStyle]::Bold)
$rectTxt = New-Object System.Drawing.RectangleF(0, 342, 512, 100)
foreach ($pt in @(@(-4, 0), @(4, 0), @(0, -4), @(0, 4), @(-3, -3), @(3, 3), @(-3, 3), @(3, -3))) {
    $rx = 0 + $pt[0]; $ry = 342 + $pt[1]
    $g.DrawString('识曲', $fNeon, (New-Solid '#FF4D88' 60), (New-Object System.Drawing.RectangleF($rx, $ry, 512, 100)), $sf)
}
$g.DrawString('识曲', $fNeon, (New-Solid '#FFE9F2' 255), $rectTxt, $sf)
# 星光
$pSp = New-PenC (New-Solid '#FFE45C' 235) 5
$g.DrawLine($pSp, 100, 148, 130, 148)
$g.DrawLine($pSp, 115, 133, 115, 163)
$g.DrawLine($pSp, 408, 108, 432, 108)
$g.DrawLine($pSp, 420, 96, 420, 120)
$items[1].Save("$outDir\avatar_p1_neon.png")

# ================= P2 像素团子 =================
$items = New-Bg '#14171F' '#221A38'
$g = $items[0]
$map = @(
    '......SS........'
    '......SSFF......'
    '......SSFF......'
    '......SS........'
    '....BBBBBB......'
    '...BBBBBBBB.....'
    '..BBBBBBBBBB....'
    '.BBBBBBBBBBBB...'
    '.BBEEBBBBEEBB...'
    '.BBEEBBBBEEBB...'
    '.BBBBBBBBBBBB...'
    '.BCCBBMMBBCCB...'
    '.BCCBBMMBBCCB...'
    '.BBBBBBBBBBBB...'
    '..BBBBBBBBBB....'
    '....BBBBBB......'
)
$colors = @{ 'B' = '#FFF6E9'; 'S' = '#FFF6E9'; 'F' = '#FFF6E9'; 'E' = '#14171F'; 'M' = '#14171F'; 'C' = '#FF8FA5' }
$cell = 32
for ($row = 0; $row -lt 16; $row++) {
    $line = $map[$row]
    for ($col = 0; $col -lt 16; $col++) {
        $ch = $line.Substring($col, 1)
        if ($ch -ne '.') {
            $g.FillRectangle((New-Solid $colors[$ch] 255), ($col * $cell), ($row * $cell), $cell, $cell)
        }
    }
}
$items[1].Save("$outDir\avatar_p2_pixel.png")

# ================= P3 笔记本涂鸦 =================
$items = New-Bg '#FDFBF6' ''
$g = $items[0]
# 横线 + 红边线
$pLine = New-PenC (New-Solid '#C7DCEC' 255) 2
foreach ($y in 96, 140, 184, 228, 272, 316, 360, 404, 448) {
    $g.DrawLine($pLine, 0, $y, 512, $y)
}
$g.DrawLine((New-PenC (New-Solid '#F2A9A9' 255) 3), 62, 0, 62, 512)
$ink = '#2B3A55'
# 涂鸦音符（歪歪扭扭的手绘感）
$bInk = New-Solid $ink 255
$pD = New-PenC $bInk 9
$state = $g.Save()
$g.ResetTransform()
$g.TranslateTransform(258, 240)
$g.RotateTransform(-12)
$g.FillEllipse($bInk, -58, -44, 116, 88)
$g.Restore($state)
$g.DrawLine($pD, 310, 236, 300, 118)
$g.DrawBezier($pD, 300, 118, 352, 128, 364, 172, 328, 204)
# 脸
$g.FillEllipse($bInk, 232, 226, 15, 15)
$g.FillEllipse($bInk, 272, 226, 15, 15)
$g.DrawArc((New-PenC $bInk 7), 240, 240, 44, 32, 20, 140)
# 粉色小爱心
$bHeart = New-Solid '#F3536C' 255
$g.FillEllipse($bHeart, 104, 128, 24, 20)
$g.FillEllipse($bHeart, 122, 128, 24, 20)
$pts = @(
    (New-Object System.Drawing.PointF(102, 144)),
    (New-Object System.Drawing.PointF(148, 144)),
    (New-Object System.Drawing.PointF(125, 172))
)
$g.FillPolygon($bHeart, $pts)
# 星星涂鸦
$pSt = New-PenC $bInk 6
$g.DrawLine($pSt, 396, 150, 396, 182)
$g.DrawLine($pSt, 380, 166, 412, 166)
$g.DrawLine($pSt, 430, 250, 430, 274)
$g.DrawLine($pSt, 418, 262, 442, 262)
# 写不出的"识曲"被划掉 + 拼音
$fHan = New-Object System.Drawing.Font('Microsoft YaHei UI', 60, [System.Drawing.FontStyle]::Bold)
$g.DrawString('识曲', $fHan, (New-Solid '#9AA3B2' 255), (New-Object System.Drawing.RectangleF(56, 366, 220, 110)), $sf)
$pScr = New-PenC (New-Solid '#E5484D' 255) 6
$g.DrawBezier($pScr, 70, 396, 150, 412, 190, 392, 252, 408)
$g.DrawBezier($pScr, 70, 424, 150, 408, 190, 430, 252, 414)
$fPin = New-Object System.Drawing.Font('Segoe Print', 46, [System.Drawing.FontStyle]::Bold)
$g.DrawString('shi qu', $fPin, $bInk, (New-Object System.Drawing.RectangleF(286, 372, 220, 100)), $sf)
$items[1].Save("$outDir\avatar_p3_doodle.png")

Write-Output 'DONE'
