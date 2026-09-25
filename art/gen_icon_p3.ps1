# 应用图标替换为 P3 涂鸦头像（分层图标：前景=完整P3居中缩放，背景=纸色）
Add-Type -AssemblyName System.Drawing

$src = 'D:\HarmonyOS\Harmonymusic\art\avatar_p3_doodle.png'
$outEntry = 'D:\HarmonyOS\Harmonymusic\entry\src\main\resources\base\media'
$outScope = 'D:\HarmonyOS\Harmonymusic\AppScope\resources\base\media'

$p3 = [System.Drawing.Image]::FromFile($src)

# ===== background.png 1024：纯纸色（与P3纸底同色，蒙版裁切处无缝衔接）=====
$bg = New-Object System.Drawing.Bitmap(1024, 1024)
$g = [System.Drawing.Graphics]::FromImage($bg)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#FDFBF6'))
$g.Dispose()
$bg.Save("$outEntry\background.png")
$bg.Save("$outScope\background.png")
$bg.Dispose()

# ===== foreground.png 1024 透明底：P3内容按1.65倍居中（全部落在安全区内）=====
$fg = New-Object System.Drawing.Bitmap(1024, 1024)
$g2 = [System.Drawing.Graphics]::FromImage($fg)
$g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
# 内容 845x845 居中：(1024-845)/2 = 89.5 ≈ 90
$g2.DrawImage($p3, 90, 90, 845, 845)
$g2.Dispose()
$fg.Save("$outEntry\foreground.png")
$fg.Save("$outScope\foreground.png")
$fg.Dispose()

# ===== startIcon.png 144：P3直接缩放（开始窗口方形展示）=====
$ic = New-Object System.Drawing.Bitmap(144, 144)
$g3 = [System.Drawing.Graphics]::FromImage($ic)
$g3.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g3.DrawImage($p3, 0, 0, 144, 144)
$g3.Dispose()
$ic.Save("$outEntry\startIcon.png")
$ic.Dispose()

$p3.Dispose()
Write-Output 'ICON-P3 DONE'
