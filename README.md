# PriceRedactPDF

A macOS drag-and-drop app and standalone Python script that automatically redacts dollar prices from scanned/image-based PDFs using OCR.

Drop PDFs or folders onto the app icon and every `$325`, `$2,925`, `$1,300.00`, etc. gets covered with a solid black box. Output files are saved as `<original>_redacted.pdf` next to the originals.

## How it works

1. Each PDF page is rendered to a high-resolution image (300 DPI)
2. Tesseract OCR detects text, filtering for dollar-amount patterns (`$` followed by digits)
3. A second enhanced-contrast pass catches prices in hard-to-read table columns
4. Black rectangles are drawn over every detected price
5. The redacted images are assembled back into a new PDF

## Prerequisites

- **macOS 11+** (Apple Silicon or Intel)
- **Homebrew** — <https://brew.sh>
- **Python 3.10+** (included with macOS or via Homebrew)
- **Tesseract OCR**

### Install prerequisites

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Tesseract OCR engine
brew install tesseract
```

> **Note:** The Python script itself works on Linux/Windows too — only the `.app` droplet is macOS-specific. On non-mac platforms, install Tesseract via your system package manager (`apt install tesseract-ocr`, `choco install tesseract`, etc.).

## Install

```bash
# Clone the repo
git clone https://github.com/lessthanjake/PriceRedactPDF.git
cd PriceRedactPDF

# Set up Python virtual environment and install dependencies
./setup_venv.sh

# Build the macOS drag-and-drop app (installs to ~/Desktop)
./build_app.sh
```

That's it. `PriceRedactPDF.app` will appear on your Desktop.

## Usage

### macOS app (drag and drop)

1. Drag one or more **PDF files** onto `PriceRedactPDF.app`
2. Drag a **folder** containing PDFs (they'll be found recursively)
3. A notification appears while processing; a dialog shows results when done
4. Output files are saved as `<original>_redacted.pdf` next to each input

### Standalone script (command line)

```bash
# Activate the virtual environment
source .venv/bin/activate

# Single file
python3 price_redact_pdf.py invoice.pdf

# Multiple files
python3 price_redact_pdf.py quote1.pdf quote2.pdf proposal.pdf

# Entire folder (recursive)
python3 price_redact_pdf.py /path/to/pdf-folder/

# Mix of files and folders
python3 price_redact_pdf.py estimates/ bid_response.pdf
```

## What gets redacted

The script detects and covers any text matching dollar-amount patterns:

| Pattern | Example |
|---------|---------|
| `$` + digits | `$325` |
| `$` + digits with commas | `$2,925` |
| `$` + digits with decimals | `$1,300.00` |
| Inline prices | `Cost: $2,925` |
| Table cells | Unit Price / Total Price columns |

Prices are detected via OCR, so this works on **scanned documents** (image-based PDFs) as well as text-layer PDFs.

## Project structure

```
PriceRedactPDF/
├── price_redact_pdf.py   # Core redaction script (standalone)
├── build_app.sh          # Builds PriceRedactPDF.app on ~/Desktop
├── setup_venv.sh         # Creates .venv with Python dependencies
├── requirements.txt      # Python package dependencies
├── .gitignore            # Excludes .venv, .app, *.pdf, .DS_Store
└── README.md
```

## Dependencies

| Package | Purpose | Install |
|---------|---------|---------|
| [Tesseract](https://github.com/tesseract-ocr/tesseract) | OCR engine | `brew install tesseract` |
| [PyMuPDF](https://pymupdf.readthedocs.io/) | PDF rendering and creation | `pip install PyMuPDF` |
| [pytesseract](https://github.com/madmaze/pytesseract) | Python wrapper for Tesseract | `pip install pytesseract` |
| [Pillow](https://pillow.readthedocs.io/) | Image manipulation | `pip install Pillow` |

> Python packages are installed automatically by `setup_venv.sh` into an isolated `.venv/`.

## Troubleshooting

### App does nothing when I drop files

The most common cause is that the app was built before the environment fix. Rebuild it:

```bash
cd PriceRedactPDF
./build_app.sh
```

The build script sets up `PATH`, `LANG`, and `TMPDIR` so that Homebrew-installed Tesseract and Python temp files work correctly inside AppleScript's restricted shell environment.

### "tesseract is not installed" error

```bash
brew install tesseract
```

Then re-run `./setup_venv.sh` and `./build_app.sh`.

### "No module named fitz" or other import errors

The virtual environment may be missing or incomplete:

```bash
cd PriceRedactPDF
rm -rf .venv
./setup_venv.sh
./build_app.sh    # rebuilds the app with fresh venv
```

### False positives (non-price text gets redacted)

The script only redacts text matching `$` followed by digits (with optional commas and decimals). If you see false positives, open an issue with the PDF (with sensitive info removed) and the OCR output that triggered the match.

### Output file is larger than the original

Because the script renders each page as a 300 DPI JPEG image, output files for text-layer PDFs may be larger than the original. For scanned PDFs the size is typically comparable. You can adjust `RENDER_DPI` and `JPEG_QUALITY` at the top of `price_redact_pdf.py`.

## How the macOS app works internally

The `.app` is an AppleScript "droplet" — a standard macOS app bundle that receives files via drag-and-drop. When files are dropped:

1. The AppleScript `on open` handler collects the file paths
2. It sets up the shell environment (`PATH` for Homebrew, `TMPDIR` for temp files, `LANG` for encoding)
3. It calls the bundled Python script via `do shell script`
4. Results are shown in a macOS dialog

The Python script and its entire virtual environment are bundled inside `PriceRedactPDF.app/Contents/Resources/`, making the app self-contained after building.

## License

[CC0 1.0 Universal](LICENSE) — Public Domain. Do whatever you want with it.
