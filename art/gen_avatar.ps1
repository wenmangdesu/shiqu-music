# 生成"识曲"应用头像（3个候选）— GDI+绘制
Add-Type -AssemblyName System.Drawing

$size = 512
$outDir = 'D:\HarmonyOS\Harmonymusic\art'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function New-RoundedCanvas([string]$c1, [string]$c2, [int]$radius) {
    $bmp = New-Object System.Drawing.Bitmap($script:size, $script:size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = $radius; $w = $bmp.Width; $h = $bmp.Height
    $path.AddArc(0, 0, $r, $r, 180, 90)
    $path.AddArc($w - $r, 0, $r, $r, 270, 90)
    $path.AddArc($w - $r, $h - $r, $r, $r, 0, 90)
    $path.AddArc(0, $h - $r, $r, $r, 90, 90)
    $path.CloseFigure()
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,
        [System.Drawing.ColorTranslator]::FromHtml($c1),
        [System.Drawing.ColorTranslator]::FromHtml($c2), 55.0)
    $g.FillPath($brush, $path)
    return @($g, $path, $brush, $bmp)
}

function New-Pen([string]$color, [float]$width) {
    $p = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($color), $width)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    return $p
}

$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center
$note = [string][char]0x266A  # ♪
$white = [System.Drawing.Brushes]::White

# ========== A：粉紫渐变 + 戴圆框眼镜假装识字的胖音符 + 识曲 ==========
$items = New-RoundedCanvas '#F3536C' '#B15CE0' 96
$g = $items[0]
$fNote = New-Object System.Drawing.Font('Segoe UI Symbol', 300)
$g.DrawString($note, $fNote, $white, (New-Object System.Drawing.RectangleF(30, -30, 452, 420)), $sf)
$pen = New-Pen '#FFFFFF' 13
# 眼镜：两个圆镜片 + 鼻梁 + 镜腿
$g.DrawEllipse($pen, 118, 246, 96, 96)
$g.DrawEllipse($pen, 252, 246, 96, 96)
$g.DrawArc($pen, 190, 258, 88, 66, 195, 150)
$g.DrawLine($pen, 118, 282, 84, 260)
$g.DrawLine($pen, 348, 282, 384, 258)
$fText = New-Object System.Drawing.Font('Microsoft YaHei UI', 64, [System.Drawing.FontStyle]::Bold)
$g.DrawString('识曲', $fText, $white, (New-Object System.Drawing.RectangleF(0, 400, 512, 104)), $sf)
$items[3].Save("$outDir\avatar_a_glasses.png")

# ========== B：明黄底 + 大字识曲 + 蹲在字上的粉色小音符 ==========
$items = New-RoundedCanvas '#FFD93D' '#FF9F43' 96
$g = $items[0]
$fBig = New-Object System.Drawing.Font('Microsoft YaHei UI', 128, [System.Drawing.FontStyle]::Bold)
$black = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#1A1F2B'))
$g.DrawString('识曲', $fBig, $black, (New-Object System.Drawing.RectangleF(0, 185, 512, 230)), $sf)
# 歪头小音符（旋转-12度）蹲在"曲"字右肩上
$g.ResetTransform()
$g.TranslateTransform(392, 92)
$g.RotateTransform(-14)
$fSmall = New-Object System.Drawing.Font('Segoe UI Symbol', 150)
$pink = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#F3536C'))
$g.DrawString($note, $fSmall, $pink, (New-Object System.Drawing.RectangleF(-75, -95, 150, 150)), $sf)
$g.ResetTransform()
# 小音符的黑框眼镜（傲娇感）
$penB = New-Pen '#1A1F2B' 7
$g.DrawEllipse($penB, 336, 62, 42, 42)
$g.DrawEllipse($penB, 392, 58, 42, 42)
$g.DrawArc($penB, 368, 64, 34, 30, 200, 140)
$items[3].Save("$outDir\avatar_b_yellow.png")

# ========== C：深夜底 + 墨镜酷音符 + 标语"不识字，但识曲" ==========
$items = New-RoundedCanvas '#171A21' '#3D1B4E' 96
$g = $items[0]
$fCool = New-Object System.Drawing.Font('Segoe UI Symbol', 280)
$g.DrawString($note, $fCool, $white, (New-Object System.Drawing.RectangleF(0, -50, 512, 400)), $sf)
# 墨镜：填充深色镜片 + 白描边 + 高光线
$lensFill = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#171A21'))
$g.FillRectangle($lensFill, 116, 232, 112, 74)
$g.FillRectangle($lensFill, 264, 232, 112, 74)
$penW = New-Pen '#FFFFFF' 11
$g.DrawRectangle($penW, 116, 232, 112, 74)
$g.DrawRectangle($penW, 264, 232, 112, 74)
$g.DrawLine($penW, 228, 250, 264, 250)
$g.DrawLine($penW, 116, 252, 86, 232)
$g.DrawLine($penW, 376, 252, 408, 232)
$penShine = New-Pen '#FFFFFF' 6
$g.DrawLine($penShine, 138, 252, 158, 284)
$g.DrawLine($penShine, 286, 252, 306, 284)
# 标语
$fTag = New-Object System.Drawing.Font('Microsoft YaHei UI', 46, [System.Drawing.FontStyle]::Bold)
$g.DrawString('不识字，但识曲', $fTag, $white, (New-Object System.Drawing.RectangleF(0, 398, 512, 80)), $sf)
$items[3].Save("$outDir\avatar_c_cool.png")

Write-Output 'DONE'
