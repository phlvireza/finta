param(
    [string]$InputDirectory = "store-assets/google-play/final-1080x1920",
    [string]$OutputDirectory = "store-assets/google-play/mascot-match-preview",
    [string]$BackgroundFile = "store-assets/app-store/source/app-store-background.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$inputRoot = Join-Path $root $InputDirectory
$outputRoot = Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$background = [System.Drawing.Bitmap]::FromFile((Join-Path $root $BackgroundFile))
$wave = Join-Path $root "assets/images/squi/3.0x/squi_wave.png"
$cheer = Join-Path $root "assets/images/squi/3.0x/squi_cheer.png"
$poses = @{
    "01-home.png" = $wave
    "02-budgets.png" = $cheer
    "03-analytics.png" = $wave
    "04-add-transaction.png" = $cheer
    "05-goals.png" = $wave
}

try {
    $cleanBackground = [System.Drawing.Bitmap]::new(1080,1920,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $bgGraphics = [System.Drawing.Graphics]::FromImage($cleanBackground)
    try {
        $bgGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $bgGraphics.DrawImage($background,[System.Drawing.Rectangle]::new(0,0,1080,1920))
    } finally { $bgGraphics.Dispose() }

    try {
        foreach ($file in Get-ChildItem -LiteralPath $inputRoot -File -Filter '*.png' | Sort-Object Name) {
            if (-not $poses.ContainsKey($file.Name)) { continue }
            $source = [System.Drawing.Bitmap]::FromFile($file.FullName)
            $mascot = [System.Drawing.Bitmap]::FromFile($poses[$file.Name])
            try {
                $canvas = [System.Drawing.Bitmap]::new(1080,1920,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
                $g = [System.Drawing.Graphics]::FromImage($canvas)
                try {
                    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $g.DrawImage($source,0,0)

                    # Restore only the mascot area from the clean background.
                    $restore = [System.Drawing.Rectangle]::new(0,900,432,1020)
                    $g.DrawImage($cleanBackground,$restore,$restore,[System.Drawing.GraphicsUnit]::Pixel)

                    # 420/1080 matches 500/1290. Width equals height: no stretching.
                    $g.DrawImage($mascot,[System.Drawing.Rectangle]::new(5,1215,420,420))
                } finally { $g.Dispose() }
                $destination = Join-Path $outputRoot $file.Name
                $canvas.Save($destination,[System.Drawing.Imaging.ImageFormat]::Png)
                Write-Host "Created $destination"
                $canvas.Dispose()
            } finally {
                $mascot.Dispose()
                $source.Dispose()
            }
        }
    } finally { $cleanBackground.Dispose() }
} finally { $background.Dispose() }
