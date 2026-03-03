#!/bin/bash
# setup_venv.sh — Create a virtual environment and install Python dependencies
#
# This script checks for all prerequisites, creates an isolated .venv/,
# and installs the required Python packages (PyMuPDF, pytesseract, Pillow).
#
# Usage:
#   ./setup_venv.sh
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
REQUIREMENTS="$SCRIPT_DIR/requirements.txt"

echo "PriceRedactPDF — Environment Setup"
echo "===================================="
echo ""

# ── Check for Python 3.10+ ───────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is not installed."
    echo ""
    echo "  Install via Homebrew:  brew install python"
    echo "  Or download from:     https://www.python.org/downloads/"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || { [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]; }; then
    echo "ERROR: Python 3.10+ is required (found $PYTHON_VERSION)."
    echo ""
    echo "  Upgrade via Homebrew:  brew upgrade python"
    exit 1
fi
echo "[ok] Python $PYTHON_VERSION"

# ── Check for Tesseract OCR ──────────────────────────────────────────────────
if ! command -v tesseract &>/dev/null; then
    echo ""
    echo "ERROR: Tesseract OCR is not installed."
    echo ""
    echo "  macOS:   brew install tesseract"
    echo "  Ubuntu:  sudo apt install tesseract-ocr"
    echo "  Windows: choco install tesseract"
    echo ""
    echo "  More info: https://github.com/tesseract-ocr/tesseract"
    exit 1
fi
TESS_VERSION=$(tesseract --version 2>&1 | head -1)
echo "[ok] $TESS_VERSION"

# ── Create virtual environment ───────────────────────────────────────────────
if [ -d "$VENV_DIR" ]; then
    echo ""
    echo "Existing .venv found — removing and recreating..."
    rm -rf "$VENV_DIR"
fi

echo ""
echo "Creating virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# ── Install Python dependencies ──────────────────────────────────────────────
echo "Installing Python dependencies..."
pip install --upgrade pip --quiet
pip install -r "$REQUIREMENTS"

echo ""
echo "===================================="
echo "Setup complete!"
echo ""
echo "  Virtual environment: $VENV_DIR"
echo ""
echo "  Next steps:"
echo "    ./build_app.sh              # Build the macOS drag-and-drop app"
echo "    source .venv/bin/activate   # Or use the script directly"
echo "    python3 price_redact_pdf.py <file_or_folder>"
