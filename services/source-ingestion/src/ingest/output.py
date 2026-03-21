"""Output assembly and writing for ingested source documents."""

from __future__ import annotations

import os
from pathlib import Path

import boto3
import yaml

from ingest.llm import MetadataResult, TokenUsage


def build_frontmatter(
    source_id: str | int,
    metadata: MetadataResult,
    extra: dict | None = None,
) -> str:
    """Build YAML frontmatter string from metadata.

    Always includes source_id, title, authors, year. Optionally includes doi
    and any extra key-value pairs. Keys with None values are omitted.

    Returns the YAML string WITHOUT ``---`` delimiters.
    """
    data: dict = {
        "source_id": source_id,
        "title": metadata.title,
        "authors": metadata.authors,
        "year": metadata.year,
        "doi": metadata.doi,
    }

    if extra:
        data.update(extra)

    # Remove keys with None values.
    data = {k: v for k, v in data.items() if v is not None}

    return yaml.dump(data, default_flow_style=False, sort_keys=False, allow_unicode=True)


def assemble_document(frontmatter: str, body: str) -> str:
    """Combine frontmatter and body into a complete markdown document.

    Returns ``---\\n{frontmatter}---\\n\\n{body}\\n``.
    """
    body_stripped = body.rstrip("\n")
    return f"---\n{frontmatter}---\n\n{body_stripped}\n"


def write_local(document: str, source_id: str | int, output_dir: str = "./output") -> str:
    """Write document to a local file.

    Creates output_dir if it doesn't exist. Writes to ``{output_dir}/{source_id}.md``.

    Returns the output file path.
    """
    path = Path(output_dir)
    path.mkdir(parents=True, exist_ok=True)

    file_path = path / f"{source_id}.md"
    file_path.write_text(document)
    return str(file_path)


def write_s3(
    document: str,
    source_id: str | int,
    bucket: str | None = None,
) -> str:
    """Upload document to S3.

    Uploads to key ``sources/{source_id}.md``. Bucket is taken from the
    parameter or the ``INGEST_S3_BUCKET`` environment variable.

    Returns the S3 URI (``s3://{bucket}/sources/{source_id}.md``).

    Raises:
        ValueError: If no bucket is specified via parameter or env var.
    """
    resolved_bucket = bucket or os.environ.get("INGEST_S3_BUCKET")
    if not resolved_bucket:
        raise ValueError(
            "No S3 bucket specified. Pass bucket= or set INGEST_S3_BUCKET env var."
        )

    key = f"sources/{source_id}.md"
    client = boto3.client("s3")
    client.put_object(
        Bucket=resolved_bucket,
        Key=key,
        Body=document,
        ContentType="text/markdown",
    )
    return f"s3://{resolved_bucket}/{key}"


def format_summary(
    source_id: str | int,
    output_path: str,
    usage: TokenUsage,
    elapsed: float,
    cost_per_1k_tokens: float = 0.003,
) -> str:
    """Return a human-readable processing summary.

    Includes output path, token counts, estimated cost, and processing time.
    """
    total_tokens = usage.prompt_tokens + usage.completion_tokens
    cost = (total_tokens / 1000) * cost_per_1k_tokens

    return (
        f"Source {source_id} processed successfully.\n"
        f"  Output: {output_path}\n"
        f"  Tokens: {usage.prompt_tokens} prompt + {usage.completion_tokens} completion = {total_tokens} total\n"
        f"  Cost:   ${cost:.4f} (at ${cost_per_1k_tokens}/1k tokens)\n"
        f"  Time:   {elapsed:.2f}s"
    )
