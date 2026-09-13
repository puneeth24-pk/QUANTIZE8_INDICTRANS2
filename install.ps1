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
# 1. FIND PYTHON 3.12
# ------------------------------------------------------------

Write-Host "[1/7] Checking Python..."

$PythonCommand = $null

$PyLauncher = Get-Command py -ErrorAction SilentlyContinue

if ($PyLauncher) {
    try {
        & py -3.12 --version *> $null

        if ($LASTEXITCODE -eq 0) {
            $PythonCommand = "py"
            Write-Host "      Using Python 3.12"
        }
    }
    catch {
        $PythonCommand = $null
    }
}

if (-not $PythonCommand) {
    Write-Host ""
    Write-Host "ERROR: Python 3.12 was not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Python 3.12 and run the installer again."
    Write-Host ""
    Write-Host "Command:"
    Write-Host "    winget install Python.Python.3.12"
    Write-Host ""
    exit 1
}

$PythonVersion = & py -3.12 --version
Write-Host "      $PythonVersion"

# ------------------------------------------------------------
# 2. CREATE KAIROS ENVIRONMENT
# ------------------------------------------------------------

Write-Host "[2/7] Creating KAIROS environment..."

New-Item -ItemType Directory -Force -Path $KairosHome | Out-Null
New-Item -ItemType Directory -Force -Path $KairosBin | Out-Null
New-Item -ItemType Directory -Force -Path $ModelDir | Out-Null

# ------------------------------------------------------------
# 3. DOWNLOAD KAIROS APPLICATION
# ------------------------------------------------------------

Write-Host "[3/7] Downloading KAIROS application..."

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
# 4. CREATE VENV + INSTALL DEPENDENCIES
# ------------------------------------------------------------

Write-Host "[4/7] Preparing Python runtime..."

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
# 5. DOWNLOAD INT8 MODEL
# ------------------------------------------------------------

Write-Host "[5/7] Preparing INT8 translation model..."

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
# 6. VERIFY MODEL
# ------------------------------------------------------------

Write-Host "[6/7] Verifying INT8 model..."

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
# 7. INSTALL KAIROS COMMAND
# ------------------------------------------------------------

Write-Host "[7/7] Installing KAIROS command..."

$Launcher = @"
@echo off
"$KairosPython" "$KairosHome\cli.py" %*
"@

$LauncherPath = Join-Path $KairosBin "kairos.cmd"

Set-Content `
    -Path $LauncherPath `
    -Value $Launcher `
    -Encoding ASCII

# Add KAIROS bin directory to USER PATH if missing

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