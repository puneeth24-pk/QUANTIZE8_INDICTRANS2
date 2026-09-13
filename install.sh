#!/bin/bash

set -e

# ============================================================
# KAIROS INSTALLER
# ============================================================

REPO="https://raw.githubusercontent.com/puneeth24-pk/QUANTIZE8_INDICTRANS2/main"

KAIROS_HOME="$HOME/.kairos"
KAIROS_BIN="$HOME/.local/bin"
KAIROS_VENV="$KAIROS_HOME/.venv"

MODEL_DIR="$KAIROS_HOME/indictrans2-int8"
MODEL_FILE="$MODEL_DIR/indictrans2-int8.pth"

MODEL_URL="https://github.com/puneeth24-pk/QUANTIZE8_INDICTRANS2/releases/latest/download/indictrans2-int8.pth"

EXPECTED_SHA256="51402de8aca015bb19d5da590d7e283550522b12239cfe2a4732cd3426cdc894"

# ============================================================
# HEADER
# ============================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "              K A I R O S"
echo "       Offline AI Translation Engine"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================================
# CHECK PYTHON
# ============================================================

echo "[1/7] Checking Python..."

if ! command -v python3 >/dev/null 2>&1; then
    echo ""
    echo "ERROR: Python 3 is required."
    echo ""
    echo "Please install Python 3.11 or newer and run"
    echo "the KAIROS installer again."
    exit 1
fi

PYTHON_VERSION="$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"

echo "      Python $PYTHON_VERSION"

# ============================================================
# CREATE DIRECTORIES
# ============================================================

echo "[2/7] Creating KAIROS environment..."

mkdir -p "$KAIROS_HOME"
mkdir -p "$MODEL_DIR"
mkdir -p "$KAIROS_BIN"

# ============================================================
# DOWNLOAD APPLICATION
# ============================================================

echo "[3/7] Downloading KAIROS application..."

curl -fsSL "$REPO/cli.py" \
    -o "$KAIROS_HOME/cli.py"

curl -fsSL "$REPO/kairos_loader.py" \
    -o "$KAIROS_HOME/kairos_loader.py"

mkdir -p "$KAIROS_HOME/kairos_model"

MODEL_FILES=(
    "config.json"
    "configuration_indictrans.py"
    "dict.SRC.json"
    "dict.TGT.json"
    "generation_config.json"
    "model.SRC"
    "model.TGT"
    "modeling_indictrans.py"
    "special_tokens_map.json"
    "tokenization_indictrans.py"
    "tokenizer_config.json"
)

for FILE in "${MODEL_FILES[@]}"; do
    curl -fsSL "$REPO/kairos_model/$FILE" \
        -o "$KAIROS_HOME/kairos_model/$FILE"
done

echo "      KAIROS application downloaded."

# ============================================================
# CREATE PYTHON VENV
# ============================================================

echo "[4/7] Preparing Python runtime..."

if [ ! -x "$KAIROS_VENV/bin/python" ]; then
    python3 -m venv "$KAIROS_VENV"
fi

PYTHON="$KAIROS_VENV/bin/python"
PIP="$KAIROS_VENV/bin/pip"

"$PYTHON" -m pip install --upgrade pip --quiet

echo "      Installing dependencies..."

"$PIP" install \
    "torch" \
    "transformers==4.51.3" \
    "IndicTransToolkit" \
    "rich" \
    --quiet

echo "      Runtime ready."

# ============================================================
# DOWNLOAD INT8 MODEL
# ============================================================

echo "[5/7] Preparing INT8 translation model..."

if [ -f "$MODEL_FILE" ]; then

    echo "      Existing model found."
    echo "      Verifying model..."

else

    echo ""
    echo "      Downloading INT8 model (~1.49 GB)"
    echo "      Please keep this terminal open."
    echo ""

    curl -L \
        --fail \
        --progress-bar \
        "$MODEL_URL" \
        -o "$MODEL_FILE"

fi

# ============================================================
# VERIFY SHA256
# ============================================================

echo "[6/7] Verifying INT8 model..."

ACTUAL_SHA256="$(shasum -a 256 "$MODEL_FILE" | awk '{print $1}')"

if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "        MODEL VERIFICATION FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Expected:"
    echo "$EXPECTED_SHA256"
    echo ""
    echo "Received:"
    echo "$ACTUAL_SHA256"
    echo ""

    rm -f "$MODEL_FILE"

    exit 1
fi

echo "      SHA-256: OK"

# ============================================================
# CREATE GLOBAL COMMAND
# ============================================================

echo "[7/7] Installing KAIROS command..."

cat > "$KAIROS_BIN/kairos" <<'LAUNCHER'
#!/bin/bash

KAIROS_HOME="$HOME/.kairos"
KAIROS_PYTHON="$KAIROS_HOME/.venv/bin/python"

exec "$KAIROS_PYTHON" "$KAIROS_HOME/cli.py" "$@"
LAUNCHER

chmod +x "$KAIROS_BIN/kairos"

# ============================================================
# CONFIGURE PATH
# ============================================================

SHELL_CONFIG="$HOME/.zshrc"

if [[ ":$PATH:" != *":$KAIROS_BIN:"* ]]; then

    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_CONFIG" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_CONFIG"
    fi

    export PATH="$KAIROS_BIN:$PATH"
fi

# ============================================================
# SUCCESS
# ============================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "          KAIROS INSTALLED SUCCESSFULLY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "INT8 model verified."
echo "Offline runtime installed."
echo ""
echo "Run:"
echo ""
echo "    kairos"
echo ""
echo "If 'kairos' is not found, run:"
echo ""
echo "    source ~/.zshrc"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
