#!/bin/bash
# build_app.sh — Build PriceRedactPDF.app macOS droplet
#
# Creates a drag-and-drop .app on your Desktop that accepts PDFs and folders.
# The app uses an AppleScript wrapper that calls the Python redaction script.
#
# Prerequisites:
#   brew install tesseract
#   ./setup_venv.sh          (creates .venv with Python deps)
#
# Usage:
#   ./build_app.sh
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PriceRedactPDF"
APP_DIR="$HOME/Desktop/${APP_NAME}.app"
VENV_DIR="$SCRIPT_DIR/.venv"
PYTHON="$VENV_DIR/bin/python3"

# ── Preflight checks ─────────────────────────────────────────────────────────
if [ ! -d "$VENV_DIR" ]; then
    echo "Virtual environment not found. Running setup_venv.sh first..."
    bash "$SCRIPT_DIR/setup_venv.sh"
fi

if [ ! -f "$PYTHON" ]; then
    echo "ERROR: Python not found at $PYTHON"
    exit 1
fi

# ── Create temporary AppleScript ──────────────────────────────────────────────
APPLESCRIPT_SRC=$(mktemp /tmp/priceredact_XXXX.applescript)

cat > "$APPLESCRIPT_SRC" << 'APPLESCRIPT_EOF'
-- PriceRedactPDF droplet
-- Accepts drag-and-drop of PDF files and folders

on open theFiles
    set appPath to POSIX path of (path to me)
    if appPath ends with "/" then
        set appPath to text 1 thru -2 of appPath
    end if
    set pythonScript to appPath & "/Contents/Resources/price_redact_pdf.py"
    set pythonBin to appPath & "/Contents/Resources/.venv/bin/python3"

    -- Collect POSIX paths
    set filePaths to {}
    repeat with aFile in theFiles
        set end of filePaths to quoted form of POSIX path of aFile
    end repeat

    -- Join paths with spaces
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to " "
    set filePathsString to filePaths as text
    set AppleScript's text item delimiters to oldDelims

    try
        set cmd to quoted form of pythonBin & " " & quoted form of pythonScript & " " & filePathsString
        set output to do shell script cmd
        display notification output with title "PriceRedactPDF"
    on error errMsg
        display dialog "Error redacting prices:" & return & return & errMsg buttons {"OK"} default button 1 with icon stop
    end try
end open

on run
    display dialog "Drag and drop PDF files or folders onto this app to redact all prices ($X, $X,XXX, etc.)." & return & return & "Output: <original>_redacted.pdf next to each input file." buttons {"OK"} default button 1
end run
APPLESCRIPT_EOF

# ── Remove old app if it exists ───────────────────────────────────────────────
if [ -d "$APP_DIR" ]; then
    echo "Removing existing $APP_DIR ..."
    rm -rf "$APP_DIR"
fi

# ── Compile AppleScript into .app bundle ──────────────────────────────────────
echo "Compiling AppleScript droplet..."
osacompile -o "$APP_DIR" "$APPLESCRIPT_SRC"
rm "$APPLESCRIPT_SRC"

# ── Copy Python script and venv into the app bundle ───────────────────────────
RESOURCES="$APP_DIR/Contents/Resources"
echo "Copying Python script..."
cp "$SCRIPT_DIR/price_redact_pdf.py" "$RESOURCES/"

echo "Copying virtual environment..."
cp -R "$VENV_DIR" "$RESOURCES/.venv"

# Fix the venv shebang to be relocatable (use env)
# The python3 binary in the venv is a symlink, so we just need the site-packages
# Re-link to the venv's own python
VENV_PYTHON_REAL=$(readlink "$VENV_DIR/bin/python3" || echo "")
if [ -n "$VENV_PYTHON_REAL" ]; then
    # Recreate the symlink relative to the copied venv
    rm -f "$RESOURCES/.venv/bin/python3"
    ln -s "$VENV_PYTHON_REAL" "$RESOURCES/.venv/bin/python3"
fi

# ── Update Info.plist to accept files and folders ─────────────────────────────
echo "Updating Info.plist..."
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$APP_DIR/Contents/Info.plist"

# Accept PDF files
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0 string 'pdf'" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string 'Viewer'" "$APP_DIR/Contents/Info.plist"

# Accept folders
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1 dict" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1:CFBundleTypeExtensions array" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1:CFBundleTypeExtensions:0 string '*'" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1:CFBundleTypeOSTypes array" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1:CFBundleTypeOSTypes:0 string '****'" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:1:CFBundleTypeRole string 'Viewer'" "$APP_DIR/Contents/Info.plist"

# Set app name
/usr/libexec/PlistBuddy -c "Set :CFBundleName 'PriceRedactPDF'" "$APP_DIR/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleName string 'PriceRedactPDF'" "$APP_DIR/Contents/Info.plist"

echo ""
echo "=========================================="
echo "  Built: $APP_DIR"
echo "=========================================="
echo ""
echo "Drag PDFs or folders onto the app icon to redact prices."
