# 识曲头像 v3 — 音符团子吉祥物（唱歌中）
Add-Type -AssemblyName System.Drawing

$size = 512
$outDir = 'D:\HarmonyOS\Harmonymusic\art'

function New-Canvas([string]$c1, [string]$c2) {
    $bmp = New-Object System.Drawing.Bitmap($script:size, $script:size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    if ($c2 -eq '') {
        $bg = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($c1))
        $g.FillRectangle($bg, 0, 0, $size, $size)
    } else {
        $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
        $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,
            [System.Drawing.ColorTranslator]::FromHtml($c1),
            [System.Drawing.ColorTranslator]::FromHtml($c2), 55.0)
        $g.FillRectangle($bg, 0, 0, $size, $size)
    }
    return @($g, $bmp)
}

function New-SolidBrush([string]$color, [int]$alpha) {
    if ($alpha -lt 255) {
        $c = [System.Drawing.ColorTranslator]::FromHtml($color)
        return New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alpha, $c.R, $c.G, $c.B))
    }
    return New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($color))
}

function New-Pen2([System.Drawing.Brush]$b, [float]$w) {
    $p = New-Object System.Drawing.Pen($b, $w)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    return $p
}

# 吉祥物：参数化配色
# $body 身体  $band 耳机  $blush 腮红  $ink 眼嘴  $deco 飘浮音符  $noteC 呆毛
function Draw-Mascot([System.Drawing.Graphics]$g, [string]$body, [string]$band,
    [string]$blush, [string]$ink, [string]$deco, [string]$noteC, [string]$bgForDeco) {
    # 地面阴影
    $shadow = New-SolidBrush '#000000' 36
    $g.FillEllipse($shadow, 146, 424, 220, 34)
    # ===== 呆毛：头顶的音符符干+符尾 =====
    $bNote = New-SolidBrush $noteC 255
    $pNote = New-Pen2 $bNote 20
    $g.DrawLine($pNote, 208, 180, 197, 78)
    $g.DrawBezier($pNote, 197, 78, 262, 92, 276, 142, 234, 172)
    # ===== 身体：胖团子 =====
    $bBody = New-SolidBrush $body 255
    $g.FillEllipse($bBody, 104, 143, 304, 284)
    # ===== 头戴式耳机：弧形梁 + 两侧耳罩 =====
    $bBand = New-SolidBrush $band 255
    $pBand = New-Pen2 $bBand 20
    $g.DrawArc($pBand, 100, 156, 312, 260, 180, 180)
    $g.FillEllipse($bBand, 78, 258, 58, 100)
    $g.FillEllipse($bBand, 376, 258, 58, 100)
    # ===== 脸：眼睛 / 张嘴唱歌 / 腮红 =====
    $bInk = New-SolidBrush $ink 255
    $g.FillEllipse($bInk, 198, 278, 30, 32)
    $g.FillEllipse($bInk, 286, 278, 30, 32)
    # 张开的唱歌嘴（小椭圆）
    $g.FillEllipse($bInk, 239, 314, 36, 42)
    $bBlush = New-SolidBrush $blush 200
    $g.FillEllipse($bBlush, 150, 330, 46, 24)
    $g.FillEllipse($bBlush, 316, 330, 46, 24)
    # ===== 飘浮的小音符 =====
    $bDeco = New-SolidBrush $deco 235
    $fN1 = New-Object System.Drawing.Font('Segoe UI Symbol', 46)
    $fN2 = New-Object System.Drawing.Font('Segoe UI Symbol', 32)
    $sfL = New-Object System.Drawing.StringFormat
    $sfL.Alignment = [System.Drawing.StringAlignment]::Center
    $sfL.LineAlignment = [System.Drawing.StringAlignment]::Center
    $n = [string][char]0x266A
    $g.DrawString($n, $fN1, $bDeco, (New-Object System.Drawing.RectangleF(52, 84, 90, 90)), $sfL)
    $g.DrawString($n, $fN2, $bDeco, (New-Object System.Drawing.RectangleF(408, 118, 70, 70)), $sfL)
}

# ===== M1 品牌粉底 + 奶白团子（官方主打）=====
$items = New-Canvas '#F3536C' '#B15CE0'
Draw-Mascot $items[0] '#FFF6E9' '#22252E' '#FF8FA5' '#22252E' '#FFFFFF' '#FFF6E9' ''
$items[1].Save("$outDir\avatar_m1_pink.png")

# ===== M2 奶油底 + 墨青团子（反差萌）=====
$items = New-Canvas '#FFF3DF' ''
Draw-Mascot $items[0] '#232733' '#FFFFFF' '#F3536C' '#FFFFFF' '#F3536C' '#232733' ''
$items[1].Save("$outDir\avatar_m2_cream.png")

# ===== M3 深夜底 + 白团子（克制耐看）=====
$items = New-Canvas '#171A21' ''
Draw-Mascot $items[0] '#FFFFFF' '#F3536C' '#FF8FA5' '#171A21' '#33CCAB' '#FFFFFF' ''
$items[1].Save("$outDir\avatar_m3_dark.png")

Write-Output 'DONE'
