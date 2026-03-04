"""Vision-model OCR extraction for PDF documents.

Converts PDF pages to images and sends them to a vision-language model
(e.g., olmocr) for text extraction, as an alternative to pymupdf4llm.
"""

from __future__ import annotations

import base64
from dataclasses import dataclass
from pathlib import Path

import click
import pymupdf
from openai import APIError, OpenAI

from ingest.llm import TokenUsage
from ingest.providers import ProviderConfig

OCR_PROMPT = (
    "Extract all text from this page image. "
    "Preserve the original text faithfully — do not paraphrase or summarize. "
    "Return only the extracted text, no commentary."
)


@dataclass(frozen=True)
class OcrResult:
    """Result of OCR extraction across all pages."""

    text: str
    usage: TokenUsage


def extract_pages_as_images(pdf_path: str, dpi: int = 200) -> list[str]:
    """Convert each page of a PDF to a base64-encoded PNG image.

    Args:
        pdf_path: Path to the PDF file.
        dpi: Resolution for rendering. Higher = better OCR but more tokens.

    Returns:
        List of base64-encoded PNG strings, one per page.
    """
    images: list[str] = []
    with pymupdf.open(pdf_path) as doc:
        for page in doc:
            pixmap = page.get_pixmap(dpi=dpi)
            png_bytes = pixmap.tobytes("png")
            b64 = base64.b64encode(png_bytes).decode("ascii")
            images.append(b64)
    return images


def ocr_page(image_b64: str, provider: ProviderConfig) -> tuple[str, TokenUsage]:
    """Send a single page image to the vision model for OCR.

    Args:
        image_b64: Base64-encoded PNG image of the page.
        provider: LLM provider configuration.

    Returns:
        Tuple of (extracted text, token usage).

    Raises:
        RuntimeError: If the API call fails.
    """
    client = OpenAI(base_url=provider.base_url, api_key=provider.api_key)

    user_content: list[dict] = [
        {"type": "text", "text": OCR_PROMPT},
        {
            "type": "image_url",
            "image_url": {"url": f"data:image/png;base64,{image_b64}"},
        },
    ]

    messages: list[dict] = [{"role": "user", "content": user_content}]

    try:
        response = client.chat.completions.create(
            model=provider.model,
            messages=messages,
        )
    except APIError as exc:
        raise RuntimeError(f"OCR API call failed: {exc}") from exc

    content = response.choices[0].message.content
    usage = TokenUsage(
        prompt_tokens=response.usage.prompt_tokens,
        completion_tokens=response.usage.completion_tokens,
    )
    return content, usage


def ocr_pdf(
    pdf_path: str,
    provider: ProviderConfig,
    cache_dir: str | None = None,
    dpi: int = 200,
) -> OcrResult:
    """Extract text from a PDF using a vision-language model.

    Converts each page to an image and sends it to the model for OCR.
    Results are cached per-page when cache_dir is provided.

    Args:
        pdf_path: Path to the PDF file.
        provider: Vision model provider configuration.
        cache_dir: Optional directory for caching per-page results.
        dpi: Resolution for page rendering.

    Returns:
        OcrResult with combined text and total token usage.
    """
    images = extract_pages_as_images(pdf_path, dpi=dpi)
    pages: list[str] = []
    total_prompt = 0
    total_completion = 0

    if cache_dir:
        Path(cache_dir).mkdir(parents=True, exist_ok=True)

    for i, image_b64 in enumerate(images, 1):
        page_cache = Path(cache_dir) / f"page_{i}.md" if cache_dir else None

        if page_cache and page_cache.exists():
            click.echo(f"  Loading cached page {i}/{len(images)}")
            pages.append(page_cache.read_text())
            continue

        click.echo(f"  OCR page {i}/{len(images)}...")
        text, usage = ocr_page(image_b64, provider)
        pages.append(text)
        total_prompt += usage.prompt_tokens
        total_completion += usage.completion_tokens

        if page_cache:
            page_cache.write_text(text)

    return OcrResult(
        text="\n\n".join(pages),
        usage=TokenUsage(prompt_tokens=total_prompt, completion_tokens=total_completion),
    )
