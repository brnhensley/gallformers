"""Prompt templates for LLM-based text processing.

Prompts are loaded from markdown files in the prompts/ directory at the
project root. This keeps prompt content editable without touching Python code.
"""

from pathlib import Path

_PROMPTS_DIR = Path(__file__).resolve().parents[2] / "prompts"


def _load_prompt(name: str) -> str:
    """Load a prompt from a markdown file."""
    path = _PROMPTS_DIR / f"{name}.md"
    if not path.exists():
        raise FileNotFoundError(f"Prompt file not found: {path}")
    return path.read_text().strip()


CLEANUP_SYSTEM_PROMPT = _load_prompt("cleanup")
METADATA_SYSTEM_PROMPT = _load_prompt("metadata")
DATA_EXTRACT_SYSTEM_PROMPT = _load_prompt("data-extract")
