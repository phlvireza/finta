param(
    [string]$Screenshot = "C:\Users\windows 10\Downloads\1000182108.jpg",
    [string]$AndroidOutput = "store-assets/google-play/new-budget-preview/06-create-budget.png",
    [string]$IosOutput = "store-assets/app-store/new-budget-preview/06-create-budget.png",
    [string]$Title = "Budget`nyour way",
    [string]$Body = "Repeat every period.`nNo need to recreate`nyour budget every`nmonth.",
    [string]$MascotPath = "assets/images/squi/3.0x/squi_cheer.png"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $root $Path
}

function New-RoundedPath([System.Drawing.RectangleF]$Rect, [float]$Radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $Radius * 2
    $arc = [System.Drawing.RectangleF]::new($Rect.X, $Rect.Y, $diameter, $diameter)
    $path.AddArc($arc, 180, 90)
    $arc.X = $Rect.Right - $diameter
    $path.AddArc($arc, 270, 90)
    $arc.Y = $Rect.Bottom - $diameter
    $path.AddArc($arc, 0, 90)
    $arc.X = $Rect.X
    $path.AddArc($arc, 90, 90)
    $path.CloseFigure()
    return $path
}

function Initialize-Graphics([System.Drawing.Graphics]$Graphics) {
    $Graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
}

function Draw-PhoneShadow(
    [System.Drawing.Graphics]$Graphics,
    [System.Drawing.RectangleF]$PhoneRect,
    [float]$Radius
) {
    foreach ($step in 14, 10, 6) {
        $shadowRect = [System.Drawing.RectangleF]::new(
            $PhoneRect.X + $step / 2,
            $PhoneRect.Y + $step,
            $PhoneRect.Width,
            $PhoneRect.Height
        )
        $shadowPath = New-RoundedPath $shadowRect $Radius
        $shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(12, 0, 0, 0))
        try { $Graphics.FillPath($shadowBrush, $shadowPath) }
        finally { $shadowBrush.Dispose(); $shadowPath.Dispose() }
    }
}

function Draw-Device(
    [System.Drawing.Graphics]$Graphics,
    [System.Drawing.Bitmap]$ScreenshotBitmap,
    [System.Drawing.RectangleF]$PhoneRect,
    [bool]$IsIos
) {
    $outerRadius = if ($IsIos) { 72.0 } else { 58.0 }
    Draw-PhoneShadow $Graphics $PhoneRect $outerRadius

    $outerPath = New-RoundedPath $PhoneRect $outerRadius
    $frameBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $PhoneRect,
        [System.Drawing.Color]::FromArgb(38, 39, 40),
        [System.Drawing.Color]::FromArgb(5, 5, 5),
        0.0
    )
    try { $Graphics.FillPath($frameBrush, $outerPath) }
    finally { $frameBrush.Dispose(); $outerPath.Dispose() }

    $inset = if ($IsIos) { 22.0 } else { 18.0 }
    $innerRect = [System.Drawing.RectangleF]::new(
        $PhoneRect.X + $inset,
        $PhoneRect.Y + $inset,
        $PhoneRect.Width - 2 * $inset,
        $PhoneRect.Height - 2 * $inset
    )
    $innerRadius = $outerRadius - $inset / 2
    $innerPath = New-RoundedPath $innerRect $innerRadius
    $state = $Graphics.Save()
    try {
        $Graphics.SetClip($innerPath)
        $screenBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(250, 247, 242))
        try { $Graphics.FillRectangle($screenBrush, $innerRect) }
        finally { $screenBrush.Dispose() }

        if ($IsIos) {
            # Remove the Android status bar from the supplied capture. The crop
            # keeps the app UI proportional and reserves space for an iOS bar.
            $sourceRect = [System.Drawing.Rectangle]::new(35, 74, 1010, 2266)
            $contentRect = [System.Drawing.RectangleF]::new(
                $innerRect.X,
                $innerRect.Y + 70,
                $innerRect.Width,
                $innerRect.Height - 70
            )
            $Graphics.DrawImage($ScreenshotBitmap, $contentRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)

            $statusBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(248, 246, 242))
            try { $Graphics.FillRectangle($statusBrush, $innerRect.X, $innerRect.Y, $innerRect.Width, 82) }
            finally { $statusBrush.Dispose() }

            $statusFont = [System.Drawing.Font]::new("Segoe UI", 24, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $statusText = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(20, 20, 20))
            try {
                $Graphics.DrawString("9:30", $statusFont, $statusText, $innerRect.X + 43, $innerRect.Y + 25)
            } finally { $statusText.Dispose(); $statusFont.Dispose() }

            $iconBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(20, 20, 20))
            $iconPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(20, 20, 20), 4)
            try {
                # Cellular bars.
                for ($bar = 0; $bar -lt 4; $bar++) {
                    $barHeight = 8 + $bar * 5
                    $Graphics.FillRectangle($iconBrush, $innerRect.Right - 176 + $bar * 11, $innerRect.Y + 51 - $barHeight, 7, $barHeight)
                }
                # Compact Wi-Fi mark.
                $Graphics.DrawArc($iconPen, $innerRect.Right - 123, $innerRect.Y + 28, 38, 28, 205, 130)
                $Graphics.DrawArc($iconPen, $innerRect.Right - 115, $innerRect.Y + 36, 22, 16, 205, 130)
                $Graphics.FillEllipse($iconBrush, $innerRect.Right - 106, $innerRect.Y + 49, 6, 6)
                # Battery outline and terminal.
                $Graphics.DrawRectangle($iconPen, $innerRect.Right - 70, $innerRect.Y + 29, 42, 22)
                $Graphics.FillRectangle($iconBrush, $innerRect.Right - 65, $innerRect.Y + 34, 30, 12)
                $Graphics.FillRectangle($iconBrush, $innerRect.Right - 24, $innerRect.Y + 36, 5, 9)
            } finally { $iconPen.Dispose(); $iconBrush.Dispose() }

            $islandRect = [System.Drawing.RectangleF]::new($innerRect.X + $innerRect.Width / 2 - 92, $innerRect.Y + 16, 184, 54)
            $islandPath = New-RoundedPath $islandRect 27
            $islandBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Black)
            try { $Graphics.FillPath($islandBrush, $islandPath) }
            finally { $islandBrush.Dispose(); $islandPath.Dispose() }

            $homeRect = [System.Drawing.RectangleF]::new($innerRect.X + $innerRect.Width / 2 - 105, $innerRect.Bottom - 28, 210, 9)
            $homePath = New-RoundedPath $homeRect 4.5
            $homeBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Black)
            try { $Graphics.FillPath($homeBrush, $homePath) }
            finally { $homeBrush.Dispose(); $homePath.Dispose() }
        } else {
            # A narrow horizontal crop maps the 1080x2340 capture into the
            # Android screen without changing its aspect ratio.
            $sourceRect = [System.Drawing.Rectangle]::new(31, 0, 1018, 2340)
            $Graphics.DrawImage($ScreenshotBitmap, $innerRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
            $cameraBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(15, 15, 15))
            try { $Graphics.FillEllipse($cameraBrush, $innerRect.X + $innerRect.Width / 2 - 8, $innerRect.Y + 10, 16, 16) }
            finally { $cameraBrush.Dispose() }
        }
    } finally {
        $Graphics.Restore($state)
        $innerPath.Dispose()
    }

    $rimPath = New-RoundedPath $PhoneRect $outerRadius
    $rimPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(115, 255, 255, 255), 2)
    try { $Graphics.DrawPath($rimPen, $rimPath) }
    finally { $rimPen.Dispose(); $rimPath.Dispose() }
}

function Draw-ReferenceDevice(
    [System.Drawing.Graphics]$Graphics,
    [System.Drawing.Bitmap]$ScreenshotBitmap,
    [System.Drawing.Bitmap]$ReferenceBitmap,
    [bool]$IsIos
) {
    if ($IsIos) {
        # Copy the exact approved iPhone, including its frame, shadow, Dynamic
        # Island, status bar, proportions, and placement.
        $phoneCrop = [System.Drawing.Rectangle]::new(460, 620, 800, 1760)
        $Graphics.DrawImage($ReferenceBitmap, $phoneCrop, $phoneCrop, [System.Drawing.GraphicsUnit]::Pixel)

        $innerRect = [System.Drawing.RectangleF]::new(520, 682, 678, 1650)
        $contentRect = [System.Drawing.RectangleF]::new(520, 770, 678, 1521)
        # Preserve more of the screenshot's native horizontal padding so the
        # app UI does not sit directly against the iPhone's inner bezel.
        $sourceRect = [System.Drawing.Rectangle]::new(21, 74, 1038, 2192)
        $clipPath = New-RoundedPath $innerRect 55
        $outerRect = [System.Drawing.RectangleF]::new(492, 660, 730, 1700)
        $outerRadius = 82
        $statusRect = [System.Drawing.RectangleF]::new(520, 682, 678, 88)
    } else {
        # Copy the exact approved Android phone, including its frame, shadow,
        # camera cutout, neutral status bar, proportions, and placement.
        $phoneCrop = [System.Drawing.Rectangle]::new(400, 390, 620, 1320)
        $Graphics.DrawImage($ReferenceBitmap, $phoneCrop, $phoneCrop, [System.Drawing.GraphicsUnit]::Pixel)

        $innerRect = [System.Drawing.RectangleF]::new(451, 431, 519, 1204)
        $contentRect = [System.Drawing.RectangleF]::new(451, 480, 519, 1152)
        $sourceRect = [System.Drawing.Rectangle]::new(29, 74, 1022, 2266)
        $clipPath = New-RoundedPath $innerRect 44
        $outerRect = [System.Drawing.RectangleF]::new(430, 412, 560, 1245)
        $outerRadius = 62
        $statusRect = [System.Drawing.RectangleF]::new(451, 431, 519, 49)
    }

    $state = $Graphics.Save()
    try {
        $Graphics.SetClip($clipPath)
        # The supplied Android status bar is deliberately excluded. The clean,
        # generic status bar from the approved device reference remains visible.
        $Graphics.DrawImage($ScreenshotBitmap, $contentRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    } finally {
        $Graphics.Restore($state)
        $clipPath.Dispose()
    }

    # Reapply only the exact approved frame band and status area above the new
    # app content. This prevents the replacement screenshot from changing the
    # mockup silhouette, bezel, controls, or platform-specific status bar.
    $outerPath = New-RoundedPath $outerRect $outerRadius
    $innerOverlayPath = New-RoundedPath $innerRect ($outerRadius - 15)
    $frameRegion = [System.Drawing.Region]::new($outerPath)
    try {
        $frameRegion.Exclude($innerOverlayPath)
        $frameRegion.Union($statusRect)
        $overlayState = $Graphics.Save()
        try {
            $Graphics.SetClip($frameRegion, [System.Drawing.Drawing2D.CombineMode]::Replace)
            $Graphics.DrawImage($ReferenceBitmap, 0, 0)
        } finally { $Graphics.Restore($overlayState) }
    } finally {
        $frameRegion.Dispose(); $innerOverlayPath.Dispose(); $outerPath.Dispose()
    }
}

function Build-Preview(
    [int]$Width,
    [int]$Height,
    [bool]$IsIos,
    [string]$Destination,
    [System.Drawing.Bitmap]$Background,
    [System.Drawing.Bitmap]$Mascot,
    [System.Drawing.Bitmap]$ScreenshotBitmap,
    [System.Drawing.Bitmap]$ReferenceBitmap
) {
    $canvas = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    try {
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        try {
            Initialize-Graphics $g
            $g.DrawImage($Background, [System.Drawing.Rectangle]::new(0, 0, $Width, $Height))

            if ($IsIos) {
                $titleFont = [System.Drawing.Font]::new("Segoe UI", 66, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
                $bodyFont = [System.Drawing.Font]::new("Segoe UI", 38, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
                $mascotRect = [System.Drawing.Rectangle]::new(-55, 1772, 530, 530)
                $titleX = 67; $titleY = 650; $bodyY = 842
            } else {
                $titleFont = [System.Drawing.Font]::new("Segoe UI", 56, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
                $bodyFont = [System.Drawing.Font]::new("Segoe UI", 32, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
                $mascotRect = [System.Drawing.Rectangle]::new(5, 1215, 420, 420)
                $titleX = 55; $titleY = 338; $bodyY = 510
            }

            # Identical pose and proportional square bounds on both platforms.
            $g.DrawImage($Mascot, $mascotRect)
            Draw-ReferenceDevice $g $ScreenshotBitmap $ReferenceBitmap $IsIos

            $titleBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(22, 20, 18))
            $bodyBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(93, 88, 83))
            try {
                $g.DrawString($Title, $titleFont, $titleBrush, $titleX, $titleY)
                $g.DrawString($Body, $bodyFont, $bodyBrush, $titleX, $bodyY)
            } finally {
                $bodyBrush.Dispose(); $titleBrush.Dispose()
                $bodyFont.Dispose(); $titleFont.Dispose()
            }
        } finally { $g.Dispose() }

        $resolvedDestination = Resolve-ProjectPath $Destination
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedDestination) | Out-Null
        $canvas.Save($resolvedDestination, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "Created $resolvedDestination"
    } finally { $canvas.Dispose() }
}

$background = [System.Drawing.Bitmap]::FromFile((Resolve-ProjectPath "store-assets/background/background.png"))
$mascot = [System.Drawing.Bitmap]::FromFile((Resolve-ProjectPath $MascotPath))
$screen = [System.Drawing.Bitmap]::FromFile((Resolve-ProjectPath $Screenshot))
$androidReference = [System.Drawing.Bitmap]::FromFile((Resolve-ProjectPath "store-assets/google-play/mascot-match-preview/02-budgets.png"))
$iosReference = [System.Drawing.Bitmap]::FromFile((Resolve-ProjectPath "store-assets/app-store/mascot-match-preview/02-budgets.png"))
try {
    Build-Preview 1080 1920 $false $AndroidOutput $background $mascot $screen $androidReference
    Build-Preview 1290 2796 $true $IosOutput $background $mascot $screen $iosReference
} finally {
    $iosReference.Dispose(); $androidReference.Dispose()
    $screen.Dispose(); $mascot.Dispose(); $background.Dispose()
}
