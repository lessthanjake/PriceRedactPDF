#!/bin/bash
# Create a virtual environment and install dependencies for PriceRedactPDF
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "Setting up PriceRedactPDF virtual environment..."

# Check for tesseract
if ! command -v tesseract &>/dev/null; then
    echo "ERROR: tesseract is not installed."
    echo "  Install via:  brew install tesseract"
    exit 1
fi

# Create venv
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Install deps
pip install --upgrade pip
pip install -r "$SCRIPT_DIR/requirements.txt"

echo ""
echo "Setup complete.  Virtual environment at: $VENV_DIR"
echo "To use:  source $VENV_DIR/bin/activate"
