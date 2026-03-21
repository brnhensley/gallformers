"""CLI entry point for the source ingestion pipeline."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import click

from ingest.extract import extract_text
from ingest.llm import DataExtractResult, MetadataResult, TokenUsage, clean_text, extract_data, extract_metadata
from ingest.ocr import ocr_pdf
from ingest.output import assemble_document, build_frontmatter
from ingest.pipeline import load_pipeline, run_pipeline
from ingest.preprocess import preprocess
from ingest.providers import ProviderConfig, load_config, resolve_model

DEFAULT_CONFIG = Path(__file__).parent.parent.parent / "providers.example.yaml"


def _load_provider(config_path: str | None, model_spec: str) -> ProviderConfig:
    """Load provider config and resolve model. Exits on error."""
    config_file = config_path or str(DEFAULT_CONFIG)
    try:
        config = load_config(config_file)
    except (FileNotFoundError, ValueError) as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)

    try:
        provider = resolve_model(model_spec, config)
    except ValueError as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)

    return provider


@click.group(invoke_without_command=True)
@click.pass_context
def cli(ctx: click.Context) -> None:
    """Source ingestion pipeline for gallformers."""
    if ctx.invoked_subcommand is None:
        click.echo(ctx.get_help())


@cli.command()
@click.option("-i", "--input", "input_path", required=True, help="Input file path or URL")
@click.option("-o", "--output", "output_path", required=True, help="Output file path")
def extract(input_path: str, output_path: str) -> None:
    """Extract text from PDF, URL, or text file."""
    click.echo(f"Extracting text from {input_path}")
    try:
        text = extract_text(input_path)
    except (FileNotFoundError, RuntimeError) as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(text)
    click.echo(f"Extracted {len(text)} characters to {output_path}")


@cli.command()
@click.option("-i", "--input", "input_path", required=True, help="PDF file path")
@click.option("-o", "--output", "output_path", required=True, help="Output file path")
@click.option("--model", required=True, help="Provider/model spec (e.g., lmstudio/olmocr-2-7b)")
@click.option("--config", "config_path", default=None, help="Provider config YAML path")
def ocr(input_path: str, output_path: str, model: str, config_path: str | None) -> None:
    """OCR extraction via vision model."""
    provider = _load_provider(config_path, model)

    click.echo(f"Running OCR on {input_path} with {provider.model}")
    try:
        result = ocr_pdf(input_path, provider)
    except RuntimeError as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(result.text)
    click.echo(f"OCR extracted {len(result.text)} characters to {output_path}")


@cli.command(name="preprocess")
@click.option("-i", "--input", "input_path", required=True, help="Input text file")
@click.option("-o", "--output", "output_path", required=True, help="Output file path")
def preprocess_cmd(input_path: str, output_path: str) -> None:
    """Deterministic text preprocessing."""
    click.echo(f"Preprocessing {input_path}")
    try:
        raw_text = Path(input_path).read_text()
    except FileNotFoundError:
        click.echo(f"Error: File not found: {input_path}", err=True)
        sys.exit(1)

    result = preprocess(raw_text)

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(result)
    click.echo(f"Preprocessed {len(raw_text)} -> {len(result)} characters to {output_path}")


@cli.command(name="llm-clean")
@click.option("-i", "--input", "input_path", required=True, help="Input text file")
@click.option("-o", "--output", "output_path", required=True, help="Output file path")
@click.option("--model", required=True, help="Provider/model spec (e.g., deepseek/deepseek-chat)")
@click.option("--config", "config_path", default=None, help="Provider config YAML path")
def llm_clean(input_path: str, output_path: str, model: str, config_path: str | None) -> None:
    """LLM text cleanup."""
    provider = _load_provider(config_path, model)

    click.echo(f"Cleaning text from {input_path} with {provider.model}")
    try:
        raw_text = Path(input_path).read_text()
    except FileNotFoundError:
        click.echo(f"Error: File not found: {input_path}", err=True)
        sys.exit(1)

    try:
        result = clean_text(raw_text, provider)
    except RuntimeError as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(result.text)
    click.echo(f"Cleaned text written to {output_path}")


@cli.command()
@click.option("-i", "--input", "input_path", required=True, help="Input text file")
@click.option("-o", "--output", "output_path", required=True, help="Output JSON file path")
@click.option("--model", required=True, help="Provider/model spec (e.g., deepseek/deepseek-chat)")
@click.option("--config", "config_path", default=None, help="Provider config YAML path")
def metadata(input_path: str, output_path: str, model: str, config_path: str | None) -> None:
    """Extract metadata via LLM."""
    provider = _load_provider(config_path, model)

    click.echo(f"Extracting metadata from {input_path} with {provider.model}")
    try:
        raw_text = Path(input_path).read_text()
    except FileNotFoundError:
        click.echo(f"Error: File not found: {input_path}", err=True)
        sys.exit(1)

    try:
        result = extract_metadata(raw_text, provider)
    except RuntimeError as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)

    data = {
        "title": result.title,
        "authors": result.authors,
        "year": result.year,
        "doi": result.doi,
    }

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(json.dumps(data, indent=2))
    click.echo(f"Metadata written to {output_path}")


@cli.command(name="data-extract")
@click.option("-i", "--input", "input_path", required=True, help="Input text file")
@click.option("-o", "--output", "output_path", required=True, help="Output JSON file path")
@click.option("--model", required=True, help="Provider/model spec (e.g., deepseek/deepseek-chat)")
@click.option("--config", "config_path", default=None, help="Provider config YAML path")
def data_extract(input_path: str, output_path: str, model: str, config_path: str | None) -> None:
    """Extract structured gall records via LLM."""
    provider = _load_provider(config_path, model)

    click.echo(f"Extracting structured data from {input_path} with {provider.model}")
    try:
        raw_text = Path(input_path).read_text()
    except FileNotFoundError:
        click.echo(f"Error: File not found: {input_path}", err=True)
        sys.exit(1)

    try:
        result = extract_data(raw_text, provider)
    except RuntimeError as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(json.dumps(result.records, indent=2))
    click.echo(f"Extracted {len(result.records)} records to {output_path}")


@cli.command()
@click.option("-i", "--input", "input_path", required=True, help="Cleaned text file")
@click.option("--metadata", "metadata_path", required=True, help="Metadata JSON file path")
@click.option("-o", "--output", "output_path", required=True, help="Output file path")
@click.option("--source-id", required=True, type=str, help="Source ID")
def assemble(input_path: str, metadata_path: str, output_path: str, source_id: str) -> None:
    """Assemble final markdown with frontmatter."""
    click.echo(f"Assembling document for source {source_id}")

    try:
        body = Path(input_path).read_text()
    except FileNotFoundError:
        click.echo(f"Error: File not found: {input_path}", err=True)
        sys.exit(1)

    try:
        meta_raw = Path(metadata_path).read_text()
    except FileNotFoundError:
        click.echo(f"Error: Metadata file not found: {metadata_path}", err=True)
        sys.exit(1)

    try:
        meta_data = json.loads(meta_raw)
    except json.JSONDecodeError as exc:
        click.echo(f"Error: Invalid metadata JSON: {exc}", err=True)
        sys.exit(1)

    meta = MetadataResult(
        title=meta_data.get("title"),
        authors=meta_data.get("authors", []),
        year=meta_data.get("year"),
        doi=meta_data.get("doi"),
        usage=TokenUsage(0, 0),
    )

    frontmatter = build_frontmatter(source_id, meta)
    document = assemble_document(frontmatter, body)

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(output_path).write_text(document)
    click.echo(f"Assembled document written to {output_path}")


@cli.command()
@click.option("-p", "--pipeline", "pipeline_path", required=True, help="Pipeline YAML config path")
@click.option("--source-id", required=True, type=str, help="Source ID")
@click.option("-i", "--input", "input_path", default=None, help="Input file (optional when resuming)")
@click.option("--config", "config_path", default=None, help="Provider config YAML path")
@click.option("-o", "--output", "output_dir", default="./output", help="Output directory")
def run(
    pipeline_path: str,
    source_id: str,
    input_path: str,
    config_path: str | None,
    output_dir: str,
) -> None:
    """Run a multi-stage ingestion pipeline."""
    try:
        pipeline = load_pipeline(pipeline_path)
    except (FileNotFoundError, ValueError) as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)

    config_file = config_path or str(DEFAULT_CONFIG)
    try:
        provider_config = load_config(config_file)
    except (FileNotFoundError, ValueError) as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)

    click.echo(f"Running pipeline '{pipeline['name']}' for source {source_id}")

    try:
        run_pipeline(
            pipeline=pipeline,
            source_id=source_id,
            input_path=input_path,
            provider_config=provider_config,
            output_dir=output_dir,
        )
    except (ValueError, RuntimeError) as exc:
        click.echo(f"Error: {exc}", err=True)
        sys.exit(1)

    click.echo(f"Pipeline '{pipeline['name']}' complete.")


if __name__ == "__main__":
    cli()
