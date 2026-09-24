# 识曲头像 v4 — 果冻质感团子（贴纸白边 + 高光 + 三表情）
Add-Type -AssemblyName System.Drawing

$size = 512
$outDir = 'D:\HarmonyOS\Harmonymusic\art'

function New-Canvas([string]$c1, [string]$c2) {
    $bmp = New-Object System.Drawing.Bitmap($script:size, $script:size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    if ($c2 -eq '') {
        $bg = New-Solid $c1 255
        $g.FillRectangle($bg, 0, 0, $size, $size)
    } else {
        $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
        $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,
            (HexColor $c1), (HexColor $c2), 55.0)
        $g.FillRectangle($bg, 0, 0, $size, $size)
    }
    return @($g, $bmp)
}

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

# 表情: happy=眯眼陶醉 / cool=墨镜 / wink=眨眼吐舌
function Draw-Mascot4([System.Drawing.Graphics]$g, [string]$body, [string]$bodyHi, [string]$bodyEdge,
    [string]$band, [string]$blush, [string]$ink, [string]$deco, [string]$noteC,
    [string]$eyeMode, [bool]$tongue, [bool]$sparkle) {

    # 地面阴影
    $g.FillEllipse((New-Solid '#000000' 34), 146, 426, 220, 32)

    # ===== 贴纸白边：整体轮廓先铺一层白 =====
    $white = New-Solid '#FFFFFF' 255
    $g.FillEllipse($white, 88, 127, 336, 316)                       # 身体白边
    $pAhogeW = New-PenC $white 40
    $g.DrawLine($pAhogeW, 208, 180, 197, 78)                        # 呆毛白边
    $g.DrawBezier($pAhogeW, 197, 78, 262, 92, 276, 142, 234, 172)
    $pBandW = New-PenC $white 40
    $g.DrawArc($pBandW, 100, 156, 312, 260, 180, 180)               # 耳机梁白边
    $g.FillEllipse($white, 66, 246, 82, 124)                        # 耳罩白边
    $g.FillEllipse($white, 364, 246, 82, 124)

    # ===== 呆毛（音符符干+符尾）=====
    $bNote = New-Solid $noteC 255
    $pNote = New-PenC $bNote 20
    $g.DrawLine($pNote, 208, 180, 197, 78)
    $g.DrawBezier($pNote, 197, 78, 262, 92, 276, 142, 234, 172)

    # ===== 身体：果冻渐变 =====
    $g.FillEllipse((New-Solid $body 255), 104, 143, 304, 284)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(104, 143, 304, 284)
    $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $pgb.CenterPoint = New-Object System.Drawing.PointF(202, 232)
    $pgb.CenterColor = HexColor $bodyHi
    $pgb.SurroundColors = [System.Drawing.Color[]]@((HexColor $bodyEdge))
    $g.FillEllipse($pgb, 104, 143, 304, 284)
    # 左上高光
    $state = $g.Save()
    $g.ResetTransform()
    $g.TranslateTransform(214, 224)
    $g.RotateTransform(-22)
    $g.FillEllipse((New-Solid '#FFFFFF' 95), -50, -26, 100, 52)
    $g.Restore($state)

    # ===== 耳机 =====
    $bBand = New-Solid $band 255
    $pBand = New-PenC $bBand 20
    $g.DrawArc($pBand, 100, 156, 312, 260, 180, 180)
    $g.FillEllipse($bBand, 78, 258, 58, 100)
    $g.FillEllipse($bBand, 376, 258, 58, 100)

    # ===== 表情 =====
    $bInk = New-Solid $ink 255
    if ($eyeMode -eq 'happy') {
        $pEye = New-PenC $bInk 13
        $g.DrawArc($pEye, 186, 264, 48, 44, 15, 150)
        $g.DrawArc($pEye, 274, 264, 48, 44, 15, 150)
    } elseif ($eyeMode -eq 'cool') {
        $bShade = New-Solid '#10131A' 255
        $g.FillEllipse($bShade, 182, 264, 60, 50)
        $g.FillEllipse($bShade, 270, 264, 60, 50)
        $pBr = New-PenC $bShade 11
        $g.DrawArc($pBr, 232, 262, 46, 36, 190, 160)
        $pSh = New-PenC (New-Solid '#FFFFFF' 230) 6
        $g.DrawLine($pSh, 196, 274, 210, 296)
        $g.DrawLine($pSh, 284, 274, 298, 296)
    } elseif ($eyeMode -eq 'wink') {
        $g.FillEllipse($bInk, 196, 280, 32, 36)
        $g.FillEllipse((New-Solid '#FFFFFF' 240), 204, 286, 11, 11)
        $pW = New-PenC $bInk 13
        $g.DrawArc($pW, 274, 264, 48, 44, 15, 150)
    } else {
        $g.FillEllipse($bInk, 196, 280, 32, 36)
        $g.FillEllipse($bInk, 284, 280, 32, 36)
        $g.FillEllipse((New-Solid '#FFFFFF' 240), 204, 286, 11, 11)
        $g.FillEllipse((New-Solid '#FFFFFF' 240), 292, 286, 11, 11)
    }

    # 嘴
    if ($eyeMode -eq 'cool') {
        $pM = New-PenC $bInk 12
        $g.DrawArc($pM, 234, 314, 46, 32, 10, 140)
    } else {
        $g.FillEllipse($bInk, 237, 314, 40, 46)
        if ($tongue) {
            $g.FillEllipse((New-Solid '#FF8FA5' 255), 245, 342, 24, 17)
        }
    }

    # 腮红
    $g.FillEllipse((New-Solid $blush 200), 148, 330, 46, 24)
    $g.FillEllipse((New-Solid $blush 200), 318, 330, 46, 24)

    # ===== 飘浮音符 + 星光 =====
    $bDeco = New-Solid $deco 235
    $sfL = New-Object System.Drawing.StringFormat
    $sfL.Alignment = [System.Drawing.StringAlignment]::Center
    $sfL.LineAlignment = [System.Drawing.StringAlignment]::Center
    $n = [string][char]0x266A
    $g.DrawString($n, (New-Object System.Drawing.Font('Segoe UI Symbol', 46)), $bDeco,
        (New-Object System.Drawing.RectangleF(50, 82, 90, 90)), $sfL)
    $g.DrawString($n, (New-Object System.Drawing.Font('Segoe UI Symbol', 32)), $bDeco,
        (New-Object System.Drawing.RectangleF(410, 116, 70, 70)), $sfL)
    if ($sparkle) {
        $pSp = New-PenC (New-Solid '#FFFFFF' 220) 5
        $g.DrawLine($pSp, 148, 92, 148, 124)
        $g.DrawLine($pSp, 132, 108, 164, 108)
    }
}

# ===== N1 眯眼陶醉（品牌粉底）=====
$items = New-Canvas '#F3536C' '#B15CE0'
Draw-Mascot4 $items[0] '#FFF6E9' '#FFFFFF' '#FFE9CF' '#22252E' '#FF8FA5' '#22252E' '#FFFFFF' '#FFF6E9' 'happy' $false $true
$items[1].Save("$outDir\avatar_n1_joy.png")

# ===== N2 墨镜装酷（奶油底 + 墨青团子）=====
$items = New-Canvas '#FFF3DF' ''
Draw-Mascot4 $items[0] '#232733' '#3D4557' '#151922' '#FFFFFF' '#F3536C' '#FFFFFF' '#F3536C' '#232733' 'cool' $false $false
$items[1].Save("$outDir\avatar_n2_cool.png")

# ===== N3 眨眼吐舌（深夜底 + 白团子）=====
$items = New-Canvas '#171A21' ''
Draw-Mascot4 $items[0] '#FFFFFF' '#FFFFFF' '#DFE5F0' '#F3536C' '#FF8FA5' '#171A21' '#33CCAB' '#FFFFFF' 'wink' $true $false
$items[1].Save("$outDir\avatar_n3_wink.png")

Write-Output 'DONE'
