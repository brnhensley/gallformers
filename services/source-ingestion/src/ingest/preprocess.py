"""Deterministic text pre-processing for BHL and OCR-extracted documents.

Cleans up raw extracted text before sending to the LLM. Handles:
- BHL boilerplate removal
- Line rejoining (OCR single-line breaks)
- Hyphenated word rejoining
- Page header/footer stripping
- Plate image page removal
"""

from __future__ import annotations

import re


def strip_bhl_boilerplate(text: str) -> str:
    """Remove BHL cover page boilerplate from the start of the document.

    Detects BHL documents by the biodiversitylibrary.org URL and strips
    everything up to and including "This page intentionally left blank."
    """
    # Check if this looks like a BHL document
    if "biodiversitylibrary.org" not in text[:500]:
        return text

    # Find the end of BHL boilerplate. Common markers:
    # - "This page intentionally left blank."
    # - "Generated <date>" line
    markers = [
        "This page intentionally left blank.",
        "This page intentionally left blank",
    ]

    cut_point = 0
    for marker in markers:
        idx = text.find(marker)
        if idx >= 0:
            # Cut after the marker and any following whitespace
            cut_point = idx + len(marker)
            break

    if cut_point == 0:
        # No blank page marker — try cutting after "Generated ... PM/AM" line
        gen_match = re.search(r"Generated .+(?:PM|AM)\b.*?\n", text)
        if gen_match:
            cut_point = gen_match.end()

    if cut_point == 0:
        return text

    return text[cut_point:].lstrip("\n")


def rejoin_lines(text: str) -> str:
    """Rejoin lines that were broken by OCR/PDF extraction.

    BHL PDFs often produce one of two patterns:
    1. Single newlines mid-sentence: "word\\nword"
    2. Blank-line-separated lines that are actually one paragraph:
       "sentence start,\\n\\ncontinuation"

    Preserves real paragraph breaks and headings.
    """
    # Split into blocks separated by 2+ blank lines
    blocks = re.split(r"\n{2,}", text)

    merged: list[str] = []
    i = 0
    while i < len(blocks):
        block = blocks[i].strip()
        if not block:
            i += 1
            continue

        # If this block looks like a heading or special line, keep it separate
        if _is_heading_or_special(block):
            merged.append(block)
            i += 1
            continue

        # Collect continuation blocks — lines that look like mid-sentence
        # continuations of the previous block
        parts = [block]
        while i + 1 < len(blocks):
            next_block = blocks[i + 1].strip()
            if not next_block:
                i += 1
                continue
            if _is_continuation(parts[-1], next_block):
                parts.append(next_block)
                i += 1
            else:
                break

        # Join the parts with spaces (they were mid-sentence breaks)
        joined = " ".join(parts)
        # Also rejoin any single newlines within each block
        joined = re.sub(r"(?<!\n)\n(?!\n)", " ", joined)
        merged.append(joined)
        i += 1

    return "\n\n".join(merged)


def _is_heading_or_special(line: str) -> bool:
    """Check if a line is a heading, all-caps title, or special marker."""
    stripped = line.strip()
    if stripped.startswith("#"):
        return True
    # All-caps short lines are likely headings
    if stripped.isupper() and len(stripped) < 100:
        return True
    # Lines that are just numbers (page numbers that weren't caught)
    if stripped.isdigit():
        return True
    return False


def _is_continuation(prev: str, current: str) -> bool:
    """Heuristic: does `current` look like a continuation of `prev`?

    A line is a continuation if the previous line doesn't end with sentence-
    ending punctuation and the current line starts with a lowercase letter
    or common continuation patterns.
    """
    prev_stripped = prev.rstrip()
    current_stripped = current.lstrip()

    if not prev_stripped or not current_stripped:
        return False

    # Previous line ends mid-sentence
    prev_ends_mid = prev_stripped[-1] not in ".!?:;\""

    # Current line starts lowercase or with common continuation chars
    current_continues = (
        current_stripped[0].islower()
        or current_stripped[0] in ",(;—–-"
    )

    # Previous ends with comma, semicolon, or conjunction words
    prev_ends_soft = prev_stripped[-1] in ",;:" or prev_stripped.endswith((" or", " and", " the", " of", " a", " an", " in", " to", " by"))

    return prev_ends_mid and current_continues or prev_ends_soft


def rejoin_hyphenated(text: str) -> str:
    """Rejoin words that were hyphenated across line breaks.

    Handles both "ex-\\nplanation" and "ex-\\n\\nplanation" patterns.
    Only rejoins when the second part starts with a lowercase letter
    (to preserve real hyphenated compounds like "well-known").
    """
    # Hyphen at end of line followed by newline(s) and lowercase continuation
    text = re.sub(r"(\w)-\s*\n+\s*([a-z])", r"\1\2", text)
    return text


def strip_page_headers(text: str) -> str:
    """Remove page headers and footers from OCR text.

    Common patterns:
    - "528 Philippine Journal of Science\\n1919"
    - Standalone page numbers
    - "AUTHOR: TITLE" running headers
    """
    # Journal name + year pattern (page number before or after)
    text = re.sub(
        r"\n+\d{3,4}\s+Philippine Journal of Science\s*\n+\d{4}\s*\n*",
        "\n\n",
        text,
    )

    # Generic "NUMBER JournalName YEAR" headers
    text = re.sub(
        r"\n+\d{3,4}\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+\s+\d{4}\s*\n*",
        "\n\n",
        text,
    )

    # "AUTHOR: TITLE" running headers (all caps with colon or brackets)
    text = re.sub(
        r"\n+[A-Z]+:\s+[A-Z\s]+\.\s*\]\s*\[?[A-Z\s.,]+\d+[.,]\s*(?:No\.\s*\d+\.?)?\s*\n*",
        "\n\n",
        text,
    )

    # Standalone page numbers (3-4 digits alone on a line)
    text = re.sub(r"\n+(\d{3,4})\s*\n+", "\n\n", text)

    # Clean up excessive blank lines
    text = re.sub(r"\n{3,}", "\n\n", text)

    return text


def strip_plate_pages(text: str) -> str:
    """Remove plate image pages (OCR junk from scanned photographs).

    Keeps plate caption/description sections (e.g., under "ILLUSTRATIONS")
    but removes the actual plate image pages which produce only OCR garbage.

    Plate image pages are identified by lines like:
    - "PLATE I. PLANT GALLS."
    - "AUTHOR: TITLE. ] [JOURNAL..."
    followed by OCR noise (single characters, pipes, short nonsense).
    """
    lines = text.split("\n")
    result: list[str] = []
    in_plate_image = False

    for line in lines:
        stripped = line.strip()

        # Detect start of a plate image page
        if re.match(r"^PLATE\s+[IVXLCDM]+\.\s+", stripped):
            in_plate_image = True
            continue

        # Running headers on plate pages
        if in_plate_image and re.match(r"^[A-Z]+:\s+[A-Z\s]+\.", stripped):
            continue

        # OCR junk lines: very short, single characters, pipes, etc.
        if in_plate_image and (
            len(stripped) <= 3
            or re.match(r"^[|OoIl\s\W]+$", stripped)
        ):
            continue

        # If we're in a plate image section and hit a real content line,
        # check if it's another plate or if we've exited the plates
        if in_plate_image:
            # Another plate reference in captions (PLATE I\n\nDescription)
            # is fine — these are in the ILLUSTRATIONS section before the
            # image pages
            if re.match(r"^PLATE\s+[IVXLCDM]+$", stripped):
                in_plate_image = False
                result.append(line)
                continue
            # Real content — we've exited the plate image pages
            if len(stripped) > 20:
                in_plate_image = False
                result.append(line)
                continue
            # Skip short ambiguous lines while in plate mode
            continue

        result.append(line)

    return "\n".join(result)


def preprocess(text: str) -> str:
    """Run the full pre-processing pipeline.

    Order matters:
    1. Strip BHL boilerplate (before line manipulation)
    2. Strip plate image pages (before line rejoining, since they're noise)
    3. Strip page headers/footers
    4. Rejoin hyphenated words (before line rejoining, to catch cross-line hyphens)
    5. Rejoin broken lines (last, on clean text)
    """
    text = strip_bhl_boilerplate(text)
    text = strip_plate_pages(text)
    text = strip_page_headers(text)
    text = rejoin_hyphenated(text)
    text = rejoin_lines(text)
    return text.strip()
