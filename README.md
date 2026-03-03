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

- **macOS** (the `.app` droplet is macOS-only; the Python script works anywhere)
- **Python 3.10+**
- **Tesseract OCR**

```bash
brew install tesseract
```

## Quick start

```bash
# Clone
git clone https://github.com/jbang/PriceRedactPDF.git
cd PriceRedactPDF

# Set up virtual environment + install deps
./setup_venv.sh

# Build the macOS drop app (lands on ~/Desktop)
./build_app.sh
```

Then drag PDFs or folders onto `PriceRedactPDF.app` on your Desktop.

## Standalone script usage

```bash
# Single file
.venv/bin/python3 price_redact_pdf.py invoice.pdf

# Multiple files
.venv/bin/python3 price_redact_pdf.py quote1.pdf quote2.pdf

# Entire folder (recursive)
.venv/bin/python3 price_redact_pdf.py /path/to/pdf-folder/
```

## Project structure

```
PriceRedactPDF/
├── price_redact_pdf.py   # Standalone Python script
├── build_app.sh          # Builds PriceRedactPDF.app on Desktop
├── setup_venv.sh         # Creates .venv with dependencies
├── requirements.txt      # Python dependencies
└── README.md
```

## Dependencies

| Package | Purpose |
|---------|---------|
| [PyMuPDF](https://pymupdf.readthedocs.io/) | PDF rendering and creation |
| [pytesseract](https://github.com/madmaze/pytesseract) | Python wrapper for Tesseract OCR |
| [Pillow](https://pillow.readthedocs.io/) | Image manipulation (drawing redaction boxes) |
| [Tesseract](https://github.com/tesseract-ocr/tesseract) | OCR engine (system install via Homebrew) |
