# RubaiSTT Diktovka — Windows uchun to'liq build.
#
# Bajaradi: whisper.cpp (Vulkan) -> ilova -> o'rnatuvchi.
#
#   powershell -ExecutionPolicy Bypass -File build.ps1
#   powershell -ExecutionPolicy Bypass -File build.ps1 -SkipWhisper   # whisper.cpp tayyor bo'lsa
#   powershell -ExecutionPolicy Bypass -File build.ps1 -NoInstaller
#
# Talablar (bir marta o'rnatiladi):
#   winget install Kitware.CMake
#   winget install Microsoft.VisualStudio.2022.BuildTools --override "--add Microsoft.VisualStudio.Workload.VCTools"
#   winget install KhronosGroup.VulkanSDK
#   winget install JRSoftware.InnoSetup

param(
    [string]$WorkDir = "D:\rubai",     # whisper.cpp va build artefaktlari (katta)
    [switch]$SkipWhisper,
    [switch]$NoInstaller
)

$ErrorActionPreference = 'Stop'

$Root       = Split-Path $PSScriptRoot -Parent
$WhisperTag = 'v1.9.2'
$WhisperSrc = Join-Path $WorkDir 'whisper.cpp'
$WhisperBld = Join-Path $WhisperSrc 'build-vulkan'
$AppBld     = Join-Path $WorkDir 'app-build'
$DistDir    = Join-Path $Root 'dist'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "XATO: $msg" -ForegroundColor Red; exit 1 }

# CMake yo'llarni teskari slash bilan qabul qilmaydi: "D:\rubai\..." dagi
# \r, \n, \t escape ketma-ketligi sifatida talqin qilinadi va yo'l buziladi.
function CMakePath($p) { return ($p -replace '\\', '/') }

function Find-Tool($name, $paths) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in $paths) { if (Test-Path $p) { return $p } }
    return $null
}

# ---------------------------------------------------------------- vositalar

$cmake = Find-Tool 'cmake' @("$env:ProgramFiles\CMake\bin\cmake.exe")
if (-not $cmake) { Fail "CMake topilmadi. winget install Kitware.CMake" }

# Visual Studio o'rnatilgan joyini topish uchun (VC++ runtime fayllari uchun kerak).
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { $vswhere = $null }

if (-not $env:VULKAN_SDK) {
    $vk = Get-ChildItem 'C:\VulkanSDK' -Directory -EA SilentlyContinue |
          Sort-Object Name -Descending | Select-Object -First 1
    if (-not $vk) { Fail "Vulkan SDK topilmadi. winget install KhronosGroup.VulkanSDK" }
    $env:VULKAN_SDK = $vk.FullName
}
$env:PATH = "$env:VULKAN_SDK\Bin;$env:PATH"
Write-Host "Vulkan SDK: $env:VULKAN_SDK"

New-Item -ItemType Directory -Force $WorkDir | Out-Null

# ------------------------------------------------------------- whisper.cpp

if (-not $SkipWhisper -or -not (Test-Path "$WhisperBld\bin\Release\whisper.dll")) {
    Step "whisper.cpp ($WhisperTag)"
    if (-not (Test-Path $WhisperSrc)) {
        git clone --depth 1 --branch $WhisperTag https://github.com/ggml-org/whisper.cpp.git $WhisperSrc
        if ($LASTEXITCODE -ne 0) { Fail "whisper.cpp klonlanmadi" }
    }

    # GGML_BACKEND_DL + GGML_CPU_ALL_VARIANTS: CPU backendi bir nechta DLL
    # sifatida yig'iladi va ilova ishga tushganda protsessorga mos kelganini
    # tanlaydi. Busiz bitta CPU bazasini tanlashga majbur bo'lardik va eski
    # kompyuterlarda ilova umuman ishga tushmasdi.
    & $cmake -S (CMakePath $WhisperSrc) -B (CMakePath $WhisperBld) `
        -DGGML_VULKAN=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON `
        -DBUILD_SHARED_LIBS=ON -DGGML_NATIVE=OFF -DGGML_BLAS=OFF `
        -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF
    if ($LASTEXITCODE -ne 0) { Fail "whisper.cpp konfiguratsiyasi" }

    & $cmake --build (CMakePath $WhisperBld) --config Release -j
    if ($LASTEXITCODE -ne 0) { Fail "whisper.cpp build" }
} else {
    Step "whisper.cpp — tayyor, o'tkazib yuborildi"
}

# ------------------------------------------------------------------- ilova

Step "Ikonka"
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tools\make_icon.ps1')

Step "Ilova"
& $cmake -S (CMakePath $PSScriptRoot) -B (CMakePath $AppBld) `
    "-DWHISPER_ROOT=$(CMakePath $WhisperSrc)" "-DWHISPER_BUILD=$(CMakePath $WhisperBld)"
if ($LASTEXITCODE -ne 0) { Fail "ilova konfiguratsiyasi" }

& $cmake --build (CMakePath $AppBld) --config Release
if ($LASTEXITCODE -ne 0) { Fail "ilova build" }

$AppOut = Join-Path $AppBld 'Release'

# Kerakli fayllar bor-yo'qligini tekshiramiz — o'rnatuvchi jimgina
# yarim-ishlaydigan paket yig'ib qo'ymasligi uchun.
$required = @('RubaiSTT.exe', 'whisper.dll', 'ggml.dll', 'ggml-base.dll', 'ggml-vulkan.dll')
foreach ($f in $required) {
    if (-not (Test-Path (Join-Path $AppOut $f))) { Fail "$f topilmadi ($AppOut)" }
}
$cpuDlls = @(Get-ChildItem $AppOut -Filter 'ggml-cpu-*.dll')
if ($cpuDlls.Count -lt 2) { Fail "CPU backend DLL'lari yetishmaydi (GGML_CPU_ALL_VARIANTS o'chiqmi?)" }
Write-Host "  CPU variantlari: $($cpuDlls.Count) ta"

# ------------------------------------------------------- Visual C++ runtime
#
# Ilova va whisper.cpp DLL'lari MSVCP140.dll / VCRUNTIME140.dll ga bog'liq.
# Bu fayllar TOZA WINDOWS'DA YO'Q — ular Visual C++ Redistributable bilan
# keladi. Ishlab chiqish mashinasida bor (Build Tools o'rnatgan), shuning
# uchun muammo sezilmaydi; foydalanuvchida esa ilova
# "VCRUNTIME140.dll topilmadi" deb umuman ochilmaydi.
#
# Yechim: ularni ilova yoniga nusxalaymiz (Microsoft ruxsat bergan
# "app-local deployment"). Alohida redistributable o'rnatish shart emas.
#
# api-ms-win-crt-*.dll nusxalanmaydi — ular Windows 10+ tarkibida.

Step "Visual C++ runtime"

$vsRoots = @(
    $(if ($vswhere) { & $vswhere -latest -products * -property installationPath 2>$null }),
    'D:\BuildTools',
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community",
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$crtDir = $null
foreach ($root in $vsRoots) {
    $found = Get-ChildItem (Join-Path $root 'VC\Redist\MSVC') -Directory -EA SilentlyContinue |
             Sort-Object Name -Descending |
             ForEach-Object { Get-ChildItem (Join-Path $_.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' -EA SilentlyContinue } |
             Select-Object -First 1
    if ($found) { $crtDir = $found.FullName; break }
}

if (-not $crtDir) {
    Fail "Visual C++ redistributable DLL'lari topilmadi.`n" +
         "Build Tools o'rnatishda 'MSVC ... redistributable MSMs' komponenti kerak."
}

Write-Host "  Manba: $crtDir"
$crtFiles = Get-ChildItem $crtDir -Filter *.dll
Copy-Item $crtFiles.FullName -Destination $AppOut -Force
Write-Host "  Nusxalandi: $($crtFiles.Count) ta fayl ($([math]::Round(($crtFiles | Measure-Object Length -Sum).Sum/1MB,2)) MB)"

foreach ($f in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    if (-not (Test-Path (Join-Path $AppOut $f))) { Fail "$f nusxalanmadi" }
}

# --------------------------------------------------------------- o'rnatuvchi

if ($NoInstaller) {
    Step "Tayyor (o'rnatuvchisiz): $AppOut"
    exit 0
}

$iscc = Find-Tool 'iscc' @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe")
if (-not $iscc) { Fail "Inno Setup topilmadi. winget install JRSoftware.InnoSetup" }

Step "O'rnatuvchi"
New-Item -ItemType Directory -Force $DistDir | Out-Null
& $iscc "/DSourceDir=$AppOut" (Join-Path $PSScriptRoot 'installer\rubai.iss')
if ($LASTEXITCODE -ne 0) { Fail "o'rnatuvchi yig'ilmadi" }

$setup = Get-ChildItem $DistDir -Filter '*setup.exe' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Step "TAYYOR"
Write-Host "  $($setup.FullName)  ($([math]::Round($setup.Length/1MB,1)) MB)" -ForegroundColor Green
