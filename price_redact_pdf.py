#!/usr/bin/env python3
"""
PriceRedactPDF - Redact prices from scanned/image-based PDFs.

Finds all dollar amounts ($325, $2,925, $1,300, etc.) via OCR and
covers them with solid black rectangles.

Usage:
    python3 price_redact_pdf.py file1.pdf file2.pdf /folder/of/pdfs ...

Outputs _redacted.pdf files next to originals.

Dependencies:
    pip3 install PyMuPDF pytesseract Pillow
    brew install tesseract
"""

import os
import sys
import re
import io
import fitz  # PyMuPDF
import pytesseract
from PIL import Image, ImageDraw, ImageEnhance


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
RENDER_DPI = 300           # DPI for rendering PDF pages to images
OCR_DPI = 400              # Higher DPI for a second-pass OCR on hard-to-read columns
PADDING = 6                # Extra pixels around each redaction box
JPEG_QUALITY = 90          # Quality for output JPEG images inside the PDF
PRICE_PATTERN = re.compile(r'\$[\d,]+(?:\.\d{2})?')  # Matches $325, $2,925, $1,300.00, etc.


# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def is_price_text(text):
    """Return True if text looks like a dollar price (not a year or other number)."""
    text = text.strip()
    # Must contain a $ followed by at least one digit
    if PRICE_PATTERN.search(text):
        return True
    # Catch OCR variants where $ is read as 'S' or split across tokens:
    # only if the token literally starts with $
    if text.startswith("$") and re.search(r'\d', text):
        return True
    return False


def find_prices_on_image(img, label=""):
    """Run OCR on a PIL Image and return bounding boxes for any price text found.

    Returns a list of (x1, y1, x2, y2) pixel rectangles.
    """
    boxes = []
    ocr_data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)

    for i, text in enumerate(ocr_data["text"]):
        if is_price_text(text):
            x = ocr_data["left"][i]
            y = ocr_data["top"][i]
            w = ocr_data["width"][i]
            h = ocr_data["height"][i]
            if w > 0 and h > 0:
                boxes.append((x, y, x + w, y + h))
    return boxes


def find_prices_multipass(img):
    """Two-pass price detection: full-page OCR, then enhanced-column OCR.

    Scanned PDFs sometimes have columns where OCR misses values at normal
    settings.  A second pass at higher contrast and --psm 6 catches them.
    """
    boxes = find_prices_on_image(img, label="full-page")

    # --- Second pass: scan right third of the image with enhanced contrast ---
    w, h = img.size
    crop_x_start = int(w * 0.60)
    crop = img.crop((crop_x_start, 0, w, h))
    enhancer = ImageEnhance.Contrast(crop)
    crop = enhancer.enhance(2.0)

    crop_boxes = []
    try:
        ocr_data = pytesseract.image_to_data(
            crop, output_type=pytesseract.Output.DICT, config="--psm 6"
        )
        for i, text in enumerate(ocr_data["text"]):
            if is_price_text(text):
                x = ocr_data["left"][i]
                y = ocr_data["top"][i]
                w_box = ocr_data["width"][i]
                h_box = ocr_data["height"][i]
                if w_box > 0 and h_box > 0:
                    # Translate back to full-image coordinates
                    crop_boxes.append((
                        x + crop_x_start, y,
                        x + crop_x_start + w_box, y + h_box,
                    ))
    except Exception:
        pass  # If enhanced pass fails, we still have the first pass

    # Merge both passes, deduplicating overlapping rectangles
    all_boxes = boxes + crop_boxes
    return deduplicate_boxes(all_boxes)


def deduplicate_boxes(boxes, overlap_thresh=0.5):
    """Remove near-duplicate rectangles (IoU > overlap_thresh)."""
    if not boxes:
        return boxes

    keep = []
    for box in boxes:
        is_dup = False
        for kept in keep:
            if iou(box, kept) > overlap_thresh:
                is_dup = True
                break
        if not is_dup:
            keep.append(box)
    return keep


def iou(a, b):
    """Intersection-over-union of two rectangles."""
    x1 = max(a[0], b[0])
    y1 = max(a[1], b[1])
    x2 = min(a[2], b[2])
    y2 = min(a[3], b[3])
    inter = max(0, x2 - x1) * max(0, y2 - y1)
    area_a = (a[2] - a[0]) * (a[3] - a[1])
    area_b = (b[2] - b[0]) * (b[3] - b[1])
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0


# ---------------------------------------------------------------------------
# Per-page and per-file processing
# ---------------------------------------------------------------------------

def redact_page(page, dpi=RENDER_DPI):
    """Render a fitz page, find prices via OCR, and return a redacted PIL Image."""
    pix = page.get_pixmap(dpi=dpi)
    img = Image.open(io.BytesIO(pix.tobytes("png")))

    boxes = find_prices_multipass(img)
    if boxes:
        draw = ImageDraw.Draw(img)
        for x1, y1, x2, y2 in boxes:
            draw.rectangle(
                [x1 - PADDING, y1 - PADDING, x2 + PADDING, y2 + PADDING],
                fill="black",
            )
    return img, len(boxes)


def redact_pdf(input_path, output_path=None):
    """Redact all prices in a PDF and write the result to output_path."""
    if output_path is None:
        base, ext = os.path.splitext(input_path)
        output_path = f"{base}_redacted{ext}"

    doc = fitz.open(input_path)
    new_doc = fitz.open()
    total_redactions = 0

    for page_num in range(len(doc)):
        page = doc[page_num]
        img, count = redact_page(page)
        total_redactions += count

        img_bytes = io.BytesIO()
        img.save(img_bytes, format="JPEG", quality=JPEG_QUALITY, dpi=(RENDER_DPI, RENDER_DPI))
        img_bytes.seek(0)

        new_page = new_doc.new_page(width=page.rect.width, height=page.rect.height)
        new_page.insert_image(new_page.rect, stream=img_bytes.read())

    new_doc.save(output_path, deflate=True, garbage=4)
    new_doc.close()
    doc.close()

    return total_redactions, output_path


# ---------------------------------------------------------------------------
# File / folder collection
# ---------------------------------------------------------------------------

def collect_pdfs(paths):
    """Given a list of files and/or directories, return all .pdf paths (recursive)."""
    pdfs = []
    for p in paths:
        p = p.strip().strip("'\"")
        if os.path.isfile(p) and p.lower().endswith(".pdf"):
            pdfs.append(p)
        elif os.path.isdir(p):
            for root, _dirs, files in os.walk(p):
                for f in sorted(files):
                    if f.lower().endswith(".pdf"):
                        pdfs.append(os.path.join(root, f))
    return pdfs


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print("PriceRedactPDF")
        print("=" * 50)
        print()
        print("Usage:")
        print("  python3 price_redact_pdf.py <file_or_folder> [...]")
        print()
        print("  Drag and drop PDFs or folders onto this script.")
        print("  All prices ($X, $X,XXX, etc.) will be redacted.")
        print("  Output: <original>_redacted.pdf next to each input.")
        return

    pdf_files = collect_pdfs(sys.argv[1:])

    if not pdf_files:
        print("No PDF files found in the provided paths.")
        return

    print(f"Found {len(pdf_files)} PDF(s) to process\n")

    success = 0
    for pdf_path in pdf_files:
        basename = os.path.basename(pdf_path)
        print(f"Processing: {basename} ...", end=" ", flush=True)
        try:
            count, out_path = redact_pdf(pdf_path)
            print(f"done  ({count} redaction(s)) -> {os.path.basename(out_path)}")
            success += 1
        except Exception as e:
            print(f"ERROR: {e}")

    print(f"\nCompleted: {success}/{len(pdf_files)} files processed successfully")


if __name__ == "__main__":
    main()
