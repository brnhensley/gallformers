"""LLM-based text cleanup and metadata extraction."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from openai import APIError, OpenAI

from ingest.prompts import CLEANUP_SYSTEM_PROMPT, METADATA_SYSTEM_PROMPT
from ingest.providers import ProviderConfig


@dataclass(frozen=True)
class TokenUsage:
    """Token usage from a single LLM call."""

    prompt_tokens: int
    completion_tokens: int


@dataclass(frozen=True)
class CleanupResult:
    """Result of cleaning text via LLM."""

    text: str
    usage: TokenUsage


@dataclass(frozen=True)
class MetadataResult:
    """Extracted bibliographic metadata."""

    title: str | None = None
    authors: list[str] = field(default_factory=list)
    year: int | None = None
    doi: str | None = None
    usage: TokenUsage = field(default_factory=lambda: TokenUsage(0, 0))


def _call_llm(system_prompt: str, user_text: str, provider: ProviderConfig) -> tuple[str, TokenUsage]:
    """Send a chat completion request and return (content, usage).

    Raises:
        RuntimeError: If the API call fails.
    """
    client = OpenAI(base_url=provider.base_url, api_key=provider.api_key)

    if provider.no_system_role:
        messages = [
            {"role": "user", "content": f"{system_prompt}\n\n---\n\n{user_text}"},
        ]
    else:
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_text},
        ]

    try:
        response = client.chat.completions.create(
            model=provider.model,
            messages=messages,
        )
    except APIError as exc:
        raise RuntimeError(f"LLM API call failed: {exc}") from exc

    content = response.choices[0].message.content
    usage = TokenUsage(
        prompt_tokens=response.usage.prompt_tokens,
        completion_tokens=response.usage.completion_tokens,
    )
    return content, usage


def _estimate_tokens(text: str) -> int:
    """Rough token estimate: ~4 characters per token."""
    return len(text) // 4


def _chunk_text(text: str, max_tokens: int) -> list[str]:
    """Split text into chunks that fit within max_tokens.

    Splits on paragraph boundaries (double newlines). If a single paragraph
    exceeds max_tokens, it goes into its own chunk.
    """
    paragraphs = text.split("\n\n")
    chunks: list[str] = []
    current: list[str] = []
    current_tokens = 0

    for para in paragraphs:
        para_tokens = _estimate_tokens(para)
        if current and current_tokens + para_tokens > max_tokens:
            chunks.append("\n\n".join(current))
            current = [para]
            current_tokens = para_tokens
        else:
            current.append(para)
            current_tokens += para_tokens

    if current:
        chunks.append("\n\n".join(current))

    return chunks


# Default max tokens for user content per chunk. Leaves room for system prompt
# and completion within a typical context window.
DEFAULT_CHUNK_MAX_TOKENS = 6000


def clean_text(
    text: str,
    provider: ProviderConfig,
    chunk_max_tokens: int = DEFAULT_CHUNK_MAX_TOKENS,
    cache_dir: str | None = None,
) -> CleanupResult:
    """Clean and format extracted text using an LLM.

    If the text exceeds chunk_max_tokens, it is split into chunks on paragraph
    boundaries. Each chunk is cleaned separately and the results are joined.

    When cache_dir is provided, each cleaned chunk is saved to
    ``{cache_dir}/chunk_{i}.md`` and loaded on subsequent runs instead of
    re-calling the LLM.

    Args:
        text: Raw extracted text to clean.
        provider: LLM provider configuration.
        chunk_max_tokens: Max estimated tokens per chunk.
        cache_dir: Optional directory for caching cleaned chunks.

    Returns:
        CleanupResult with cleaned text and token usage.

    Raises:
        RuntimeError: If the API call fails.
    """
    from pathlib import Path

    import click

    chunks = _chunk_text(text, chunk_max_tokens)
    cleaned_parts: list[str] = []
    total_prompt = 0
    total_completion = 0

    if cache_dir:
        Path(cache_dir).mkdir(parents=True, exist_ok=True)

    for i, chunk in enumerate(chunks, 1):
        chunk_cache = Path(cache_dir) / f"chunk_{i}.md" if cache_dir else None

        if chunk_cache and chunk_cache.exists():
            click.echo(f"  Loading cached chunk {i}/{len(chunks)}")
            cleaned_parts.append(chunk_cache.read_text())
            continue

        if len(chunks) > 1:
            click.echo(f"  Cleaning chunk {i}/{len(chunks)} ({_estimate_tokens(chunk)} est. tokens)...")

        content, usage = _call_llm(CLEANUP_SYSTEM_PROMPT, chunk, provider)
        cleaned_parts.append(content)
        total_prompt += usage.prompt_tokens
        total_completion += usage.completion_tokens

        if chunk_cache:
            chunk_cache.write_text(content)

    return CleanupResult(
        text="\n\n".join(cleaned_parts),
        usage=TokenUsage(prompt_tokens=total_prompt, completion_tokens=total_completion),
    )


def extract_metadata(text: str, provider: ProviderConfig) -> MetadataResult:
    """Extract bibliographic metadata from document text using an LLM.

    Sends the text with METADATA_SYSTEM_PROMPT and parses the JSON response.

    Args:
        text: Document text to extract metadata from.
        provider: LLM provider configuration.

    Returns:
        MetadataResult with extracted fields and token usage.

    Raises:
        RuntimeError: If the API call fails or JSON parsing fails.
    """
    # Metadata is in the first few pages — truncate to save tokens.
    max_chars = DEFAULT_CHUNK_MAX_TOKENS * 4
    truncated = text[:max_chars] if len(text) > max_chars else text
    content, usage = _call_llm(METADATA_SYSTEM_PROMPT, truncated, provider)

    data = _extract_json(content)

    return MetadataResult(
        title=data.get("title"),
        authors=data.get("authors", []),
        year=data.get("year"),
        doi=data.get("doi"),
        usage=usage,
    )


def _extract_json(content: str) -> dict:
    """Best-effort JSON extraction from LLM output.

    Handles: raw JSON, markdown-fenced JSON, preamble text before JSON,
    and truncated JSON (returns whatever fields were complete).
    """
    # Try fenced JSON first
    fence_match = re.search(r"```(?:json)?\s*\n(.*?)(?:\n?```|$)", content, re.DOTALL)
    candidate = fence_match.group(1).strip() if fence_match else content.strip()

    # If no fence, find the first '{'
    if not candidate.startswith("{"):
        brace_pos = candidate.find("{")
        if brace_pos >= 0:
            candidate = candidate[brace_pos:]

    # Try parsing as-is
    try:
        return json.loads(candidate)
    except json.JSONDecodeError:
        pass

    # Truncated JSON — try progressively closing open structures
    closers = ['"}', '"}]', '"]}', '"]}}', "}", "]}", "]}"]
    for suffix in closers:
        try:
            return json.loads(candidate + suffix)
        except json.JSONDecodeError:
            continue

    raise RuntimeError(
        f"Could not extract JSON from LLM response.\n"
        f"Response was: {content[:500]}"
    )
