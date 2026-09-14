$ErrorActionPreference = "Stop"

$Repo = "https://raw.githubusercontent.com/puneeth24-pk/QUANTIZE8_INDICTRANS2/main"

$KairosHome = Join-Path $env:USERPROFILE ".kairos"
$KairosBin = Join-Path $KairosHome "bin"
$KairosVenv = Join-Path $KairosHome ".venv"

$ModelDir = Join-Path $KairosHome "indictrans2-int8"
$ModelFile = Join-Path $ModelDir "indictrans2-int8.pth"

$ModelUrl = "https://github.com/puneeth24-pk/QUANTIZE8_INDICTRANS2/releases/latest/download/indictrans2-int8.pth"

$ExpectedSHA256 = "51402de8aca015bb19d5da590d7e283550522b12239cfe2a4732cd3426cdc894"

Write-Host ""
Write-Host "============================================"
Write-Host "              K A I R O S"
Write-Host "       Offline AI Translation Engine"
Write-Host "============================================"
Write-Host ""

# ------------------------------------------------------------
# 1. CHECK / INSTALL PYTHON 3.12
# ------------------------------------------------------------

Write-Host "[1/8] Checking Python 3.12..."

$PythonCommand = $null

$PyLauncher = Get-Command py -ErrorAction SilentlyContinue

if ($PyLauncher) {
    try {
        & py -3.12 --version *> $null

        if ($LASTEXITCODE -eq 0) {
            $PythonCommand = "py"
        }
    }
    catch {
        $PythonCommand = $null
    }
}

if (-not $PythonCommand) {

    Write-Host "      Python 3.12 not found."
    Write-Host "      Installing Python 3.12..."

    $Winget = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $Winget) {
        throw "Windows Package Manager (winget) was not found. Please install App Installer from Microsoft Store."
    }

    winget install `
        --id Python.Python.3.12 `
        --exact `
        --scope user `
        --accept-source-agreements `
        --accept-package-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "Python 3.12 installation failed."
    }

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") +
                ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    $PyLauncher = Get-Command py -ErrorAction SilentlyContinue

    if (-not $PyLauncher) {
        throw "Python launcher was not found after installation. Please open a new PowerShell window and run the installer again."
    }

    & py -3.12 --version *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "Python 3.12 was installed but could not be detected."
    }

    $PythonCommand = "py"
}

$PythonVersion = & py -3.12 --version

Write-Host "      $PythonVersion"

# ------------------------------------------------------------
# 2. CHECK / INSTALL MICROSOFT C++ BUILD TOOLS
# ------------------------------------------------------------

Write-Host "[2/8] Checking Microsoft C++ Build Tools..."

$VsWherePaths = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
)

$VsWhere = $null

foreach ($Path in $VsWherePaths) {
    if ($Path -and (Test-Path $Path)) {
        $VsWhere = $Path
        break
    }
}

$BuildToolsFound = $false

if ($VsWhere) {

    $Installation = & $VsWhere `
        -latest `
        -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath 2>$null

    if ($Installation) {
        $BuildToolsFound = $true
    }
}

if ($BuildToolsFound) {

    Write-Host "      C++ Build Tools already installed."

}
else {

    Write-Host "      C++ Build Tools not found."
    Write-Host "      Installing Microsoft Visual Studio Build Tools..."
    Write-Host ""
    Write-Host "      Windows may request administrator permission."
    Write-Host ""

    $Winget = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $Winget) {
        throw "Windows Package Manager (winget) was not found."
    }

    winget install `
        --id Microsoft.VisualStudio.2022.BuildTools `
        --exact `
        --scope machine `
        --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" `
        --accept-source-agreements `
        --accept-package-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "Microsoft C++ Build Tools installation failed."
    }

    Write-Host "      C++ Build Tools installed."

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") +
                ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# ------------------------------------------------------------
# 3. CREATE KAIROS ENVIRONMENT
# ------------------------------------------------------------

Write-Host "[3/8] Creating KAIROS environment..."

New-Item `
    -ItemType Directory `
    -Force `
    -Path $KairosHome | Out-Null

New-Item `
    -ItemType Directory `
    -Force `
    -Path $KairosBin | Out-Null

New-Item `
    -ItemType Directory `
    -Force `
    -Path $ModelDir | Out-Null

# ------------------------------------------------------------
# 4. DOWNLOAD KAIROS APPLICATION
# ------------------------------------------------------------

Write-Host "[4/8] Downloading KAIROS application..."

Invoke-WebRequest `
    "$Repo/cli.py" `
    -OutFile "$KairosHome\cli.py"

Invoke-WebRequest `
    "$Repo/kairos_loader.py" `
    -OutFile "$KairosHome\kairos_loader.py"

$ModelFiles = @(
    "config.json",
    "configuration_indictrans.py",
    "dict.SRC.json",
    "dict.TGT.json",
    "generation_config.json",
    "model.SRC",
    "model.TGT",
    "modeling_indictrans.py",
    "special_tokens_map.json",
    "tokenization_indictrans.py",
    "tokenizer_config.json"
)

$ModelFolder = Join-Path $KairosHome "kairos_model"

New-Item `
    -ItemType Directory `
    -Force `
    -Path $ModelFolder | Out-Null

foreach ($File in $ModelFiles) {

    Invoke-WebRequest `
        "$Repo/kairos_model/$File" `
        -OutFile "$ModelFolder\$File"
}

Write-Host "      KAIROS application downloaded."

# ------------------------------------------------------------
# 5. CREATE VENV + INSTALL DEPENDENCIES
# ------------------------------------------------------------

Write-Host "[5/8] Preparing Python runtime..."

if (-not (Test-Path "$KairosVenv\Scripts\python.exe")) {

    & py -3.12 -m venv $KairosVenv

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Python virtual environment."
    }
}

$KairosPython = "$KairosVenv\Scripts\python.exe"
$KairosPip = "$KairosVenv\Scripts\pip.exe"

Write-Host "      Upgrading pip..."

& $KairosPython -m pip install --upgrade pip --quiet

if ($LASTEXITCODE -ne 0) {
    throw "Failed to upgrade pip."
}

Write-Host "      Installing dependencies..."

& $KairosPip install `
    torch `
    "transformers==4.51.3" `
    IndicTransToolkit `
    sentencepiece `
    rich `
    --quiet

if ($LASTEXITCODE -ne 0) {
    throw "Dependency installation failed."
}

Write-Host "      Runtime ready."

# ------------------------------------------------------------
# 6. DOWNLOAD INT8 MODEL
# ------------------------------------------------------------

Write-Host "[6/8] Preparing INT8 translation model..."

if (Test-Path $ModelFile) {

    Write-Host "      Existing model found."

}
else {

    Write-Host ""
    Write-Host "      Downloading INT8 model (~1.49 GB)..."
    Write-Host "      Please keep this terminal open."
    Write-Host ""

    Invoke-WebRequest `
        $ModelUrl `
        -OutFile $ModelFile

    if (-not (Test-Path $ModelFile)) {
        throw "INT8 model download failed."
    }
}

# ------------------------------------------------------------
# 7. VERIFY MODEL
# ------------------------------------------------------------

Write-Host "[7/8] Verifying INT8 model..."

$ActualSHA256 = (
    Get-FileHash `
        -Algorithm SHA256 `
        -Path $ModelFile
).Hash.ToLower()

if ($ActualSHA256 -ne $ExpectedSHA256) {

    Write-Host ""
    Write-Host "MODEL VERIFICATION FAILED" -ForegroundColor Red
    Write-Host ""

    Write-Host "Expected:"
    Write-Host $ExpectedSHA256

    Write-Host ""
    Write-Host "Received:"
    Write-Host $ActualSHA256

    Remove-Item $ModelFile -Force

    exit 1
}

Write-Host "      SHA-256: OK"

# ------------------------------------------------------------
# 8. INSTALL KAIROS COMMAND
# ------------------------------------------------------------

Write-Host "[8/8] Installing KAIROS command..."

$Launcher = @"
@echo off
"$KairosPython" "$KairosHome\cli.py" %*
"@

$LauncherPath = Join-Path $KairosBin "kairos.cmd"

Set-Content `
    -Path $LauncherPath `
    -Value $Launcher `
    -Encoding ASCII

# ------------------------------------------------------------
# ADD KAIROS TO USER PATH
# ------------------------------------------------------------

$CurrentPath = [Environment]::GetEnvironmentVariable(
    "Path",
    "User"
)

if (-not $CurrentPath) {
    $CurrentPath = ""
}

$PathEntries = $CurrentPath -split ";"

if ($PathEntries -notcontains $KairosBin) {

    $NewPath = if ($CurrentPath.Trim()) {
        "$CurrentPath;$KairosBin"
    }
    else {
        $KairosBin
    }

    [Environment]::SetEnvironmentVariable(
        "Path",
        $NewPath,
        "User"
    )

    Write-Host "      Added KAIROS to user PATH."

}
else {

    Write-Host "      KAIROS already exists in user PATH."

}

# ------------------------------------------------------------
# COMPLETE
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================"
Write-Host "          KAIROS INSTALLED SUCCESSFULLY"
Write-Host "============================================"
Write-Host ""
Write-Host "Python:    3.12"
Write-Host "Model:     INT8"
Write-Host "Runtime:   CPU"
Write-Host "Mode:      OFFLINE"
Write-Host ""
Write-Host "Open a NEW PowerShell window and run:"
Write-Host ""
Write-Host "    kairos"
Write-Host ""
Write-Host "============================================"
Write-Host ""