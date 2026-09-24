# 识曲头像 v2 — 田字格里的音符（被批了个"优"）
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

function New-Pen([string]$color, [float]$w, [bool]$dash) {
    $p = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($color), $w)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    if ($dash) { $p.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash }
    return $p
}

function Draw-Grid([System.Drawing.Graphics]$g, [string]$color) {
    # 田字格：实线外框 + 虚线十字与对角线
    $x = 86; $y = 86; $s = 340
    $pOut = New-Pen $color 6 $false
    $g.DrawRectangle($pOut, $x, $y, $s, $s)
    $pDash = New-Pen $color 4 $true
    $g.DrawLine($pDash, ($x + 170), $y, ($x + 170), ($y + $s))       # 竖中线
    $g.DrawLine($pDash, $x, ($y + 170), ($x + $s), ($y + 170))       # 横中线
    $g.DrawLine($pDash, $x, $y, ($x + $s), ($y + $s))                # 对角线
    $g.DrawLine($pDash, ($x + $s), $y, $x, ($y + $s))
}

function Draw-Note([System.Drawing.Graphics]$g, [string]$color, [string]$stampColor) {
    # 八分音符：符头(斜椭圆) + 符干 + 符尾(贝塞尔飘带)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($color))
    $state = $g.Save()
    $g.ResetTransform()
    $g.TranslateTransform(224, 318)
    $g.RotateTransform(-18)
    $g.FillEllipse($brush, -58, -44, 116, 88)     # 符头
    $g.Restore($state)
    $pStem = New-Pen $color 20 $false
    $g.DrawLine($pStem, 274, 312, 274, 150)       # 符干
    # 符尾
    $pFlag = New-Pen $color 20 $false
    $g.DrawBezier($pFlag, 274, 150, 348, 172, 362, 224, 322, 262)
    # 老师批改：红圈 + "优"（略歪）
    $state2 = $g.Save()
    $g.ResetTransform()
    $g.TranslateTransform(396, 396)
    $g.RotateTransform(-8)
    $pSt = New-Pen $stampColor 7 $false
    $g.DrawEllipse($pSt, -46, -46, 92, 92)
    $fYou = New-Object System.Drawing.Font('Microsoft YaHei UI', 52, [System.Drawing.FontStyle]::Bold)
    $bSt = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($stampColor))
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString([string][char]0x4F18, $fYou, $bSt, (New-Object System.Drawing.RectangleF(-46, -48, 92, 92)), $sf)
    $g.Restore($state2)
}

$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center

# ===== V1 奶油底：红田字格 + 墨色音符 + 红笔"优" =====
$items = New-Canvas '#FAF3E7' ''
$g = $items[0]
Draw-Grid $g '#E58F8F'
Draw-Note $g '#22252E' '#E5484D'
$items[1].Save("$outDir\avatar_v1_cream.png")

# ===== V2 品牌粉紫：白田字格 + 白音符 + 白"优" =====
$items = New-Canvas '#F3536C' '#B15CE0'
$g = $items[0]
Draw-Grid $g '#FFFFFF'
Draw-Note $g '#FFFFFF' '#FFFFFF'
$items[1].Save("$outDir\avatar_v2_pink.png")

# ===== V3 深色：暗格 + 白音符 + 薄荷绿"优" =====
$items = New-Canvas '#171A21' ''
$g = $items[0]
Draw-Grid $g '#454B57'
Draw-Note $g '#FFFFFF' '#33CCAB'
$items[1].Save("$outDir\avatar_v3_dark.png")

Write-Output 'DONE'
