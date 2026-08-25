Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\Jonat\.gemini\antigravity\brain\a9450711-c829-42ae-be16-d1696bb2b979\.user_uploaded\media_1787694354182.png"
$img = [System.Drawing.Image]::FromFile($srcPath)

$sizes = @(
    @{ Path = "assets\icons\app_icon.png"; Size = 512 },
    @{ Path = "android\app\src\main\res\mipmap-mdpi\ic_launcher.png"; Size = 48 },
    @{ Path = "android\app\src\main\res\mipmap-hdpi\ic_launcher.png"; Size = 72 },
    @{ Path = "android\app\src\main\res\mipmap-xhdpi\ic_launcher.png"; Size = 96 },
    @{ Path = "android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png"; Size = 144 },
    @{ Path = "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"; Size = 192 }
)

foreach ($item in $sizes) {
    $sz = $item.Size
    $destPath = Join-Path "C:\RandallEngineering\Jokarz-Engineering" $item.Path
    $dir = Split-Path $destPath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    
    $bmp = New-Object System.Drawing.Bitmap $sz, $sz
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($img, 0, 0, $sz, $sz)
    $g.Dispose()
    
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Generated $destPath ($sz x $sz)"
}

$img.Dispose()
Write-Host "All launcher icons generated successfully from attached hardhat image!"
