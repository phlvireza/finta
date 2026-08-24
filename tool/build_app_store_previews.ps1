param(
    [string]$InputDirectory = "store-assets/app-store",
    [string]$OutputDirectory = "store-assets/app-store/final-1290x2796",
    [string]$BackgroundFile = "store-assets/app-store/source/app-store-background.png",
    [int]$MascotSize = 520,
    [int]$MascotX = 10,
    [int]$MascotY = 1550,
    [switch]$MascotBehindPhone
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public static class ConnectedBackgroundRemoval {
    static bool IsBackground(Color c) {
        bool pale = c.R > 180 && c.G > 165 && c.B > 145;
        bool orange = c.R > 155 && c.G < 180 && c.B < 150 && c.R > c.G + 25;
        return pale || orange;
    }
    public static Bitmap Extract(Bitmap source, Rectangle crop) {
        Bitmap result = new Bitmap(crop.Width, crop.Height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(result)) {
            g.DrawImage(source, new Rectangle(0, 0, crop.Width, crop.Height), crop, GraphicsUnit.Pixel);
        }
        int w = result.Width, h = result.Height;
        bool[] seen = new bool[w * h];
        Queue<int> queue = new Queue<int>();
        Action<int,int> add = (x,y) => {
            if (x < 0 || y < 0 || x >= w || y >= h) return;
            int i = y * w + x;
            if (seen[i] || !IsBackground(result.GetPixel(x,y))) return;
            seen[i] = true;
            queue.Enqueue(i);
        };
        for (int x = 0; x < w; x++) { add(x,0); add(x,h-1); }
        for (int y = 0; y < h; y++) { add(0,y); add(w-1,y); }
        int[] dx = {-1,0,1,-1,1,-1,0,1};
        int[] dy = {-1,-1,-1,0,0,1,1,1};
        while (queue.Count > 0) {
            int i = queue.Dequeue(), x = i % w, y = i / w;
            Color c = result.GetPixel(x,y);
            result.SetPixel(x,y,Color.FromArgb(0,c.R,c.G,c.B));
            for (int d = 0; d < 8; d++) add(x + dx[d], y + dy[d]);
        }
        return result;
    }
}
"@

$root = Split-Path -Parent $PSScriptRoot
$inputRoot = Join-Path $root $InputDirectory
$outputRoot = Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$background = [System.Drawing.Bitmap]::FromFile((Join-Path $root $BackgroundFile))
$wave = Join-Path $root "assets/images/squi/3.0x/squi_wave.png"
$cheer = Join-Path $root "assets/images/squi/3.0x/squi_cheer.png"
$copy = @{
    "01-home.png" = @{ Title="See your`nmoney`nclearly"; Body=("Balance, spending,`nand daily guidance" + [char]0x2014 + "`nall in one place."); Mascot=$wave }
    "02-budgets.png" = @{ Title="Plan every`nrupiah"; Body="Set limits, follow`nprogress, and stay`non track."; Mascot=$cheer }
    "03-analytics.png" = @{ Title="Understand`nevery`nspend"; Body="Clear insights show`nwhere your money`ngoes."; Mascot=$wave }
    "04-add-transaction.png" = @{ Title="Add`ntransactions`nfast"; Body="Capture every`nexpense in just`na few taps."; Mascot=$cheer }
    "05-goals.png" = @{ Title="Save toward`nwhat`nmatters"; Body="Create goals and`nturn plans into`nprogress."; Mascot=$wave }
}

$width = 1290
$height = 2796
$scale = $width / 941.0
$offsetY = [int][Math]::Round(($height - 1672 * $scale) / 2)
$crop = [System.Drawing.Rectangle]::new(336,255,584,1335)
$phoneRect = [System.Drawing.Rectangle]::new(
    [int][Math]::Round($crop.X * $scale),
    [int][Math]::Round($crop.Y * $scale) + $offsetY,
    [int][Math]::Round($crop.Width * $scale),
    [int][Math]::Round($crop.Height * $scale)
)
$titleFont = [System.Drawing.Font]::new("Segoe UI",66,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$bodyFont = [System.Drawing.Font]::new("Segoe UI",38,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$titleBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(22,20,18))
$bodyBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(93,88,83))
$format = [System.Drawing.StringFormat]::new()
$format.FormatFlags = [System.Drawing.StringFormatFlags]::NoClip

try {
    foreach ($file in Get-ChildItem -LiteralPath $inputRoot -File -Filter '*.png' | Sort-Object Name) {
        if (-not $copy.ContainsKey($file.Name)) { continue }
        $source = [System.Drawing.Bitmap]::FromFile($file.FullName)
        $phone = [ConnectedBackgroundRemoval]::Extract($source,$crop)
        $mascot = [System.Drawing.Bitmap]::FromFile($copy[$file.Name].Mascot)
        try {
            $canvas = [System.Drawing.Bitmap]::new($width,$height,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            try {
                $g = [System.Drawing.Graphics]::FromImage($canvas)
                try {
                    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
                    # Draw the clean source background exactly once.
                    $g.DrawImage($background,[System.Drawing.Rectangle]::new(0,0,$width,$height))
                    if ($MascotBehindPhone) {
                        $g.DrawImage($mascot,[System.Drawing.Rectangle]::new($MascotX,$MascotY,$MascotSize,$MascotSize))
                    }
                    $g.DrawImage($phone,$phoneRect)
                    $g.DrawString($copy[$file.Name].Title,$titleFont,$titleBrush,67,650,$format)
                    $g.DrawString($copy[$file.Name].Body,$bodyFont,$bodyBrush,67,975,$format)
                    if (-not $MascotBehindPhone) {
                        $g.DrawImage($mascot,[System.Drawing.Rectangle]::new($MascotX,$MascotY,$MascotSize,$MascotSize))
                    }
                } finally { $g.Dispose() }
                $destination = Join-Path $outputRoot $file.Name
                $canvas.Save($destination,[System.Drawing.Imaging.ImageFormat]::Png)
                Write-Host "Created $destination"
            } finally { $canvas.Dispose() }
        } finally {
            $mascot.Dispose()
            $phone.Dispose()
            $source.Dispose()
        }
    }
} finally {
    $format.Dispose()
    $bodyBrush.Dispose()
    $titleBrush.Dispose()
    $bodyFont.Dispose()
    $titleFont.Dispose()
    $background.Dispose()
}
