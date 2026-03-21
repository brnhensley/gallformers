"""Tests for the pipeline runner module."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import call

import pytest
import yaml

from ingest.pipeline import load_pipeline, run_pipeline


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

VALID_PIPELINE = {
    "pipeline": {
        "name": "test-pipe",
        "stages": [
            {"step": "extract"},
            {"step": "preprocess"},
        ],
    }
}

FULL_PIPELINE = {
    "pipeline": {
        "name": "bhl-ocr-cleanup",
        "stages": [
            {"step": "ocr", "model": "lmstudio/olmocr-2-7b"},
            {"step": "preprocess"},
            {"step": "llm-clean", "model": "lmstudio/qwen3-vl-8b"},
            {"step": "metadata", "model": "lmstudio/qwen3-vl-8b"},
            {"step": "assemble"},
        ],
    }
}

FORK_PIPELINE = {
    "pipeline": {
        "name": "compare-llms",
        "stages": [
            {"step": "ocr", "model": "lmstudio/olmocr-2-7b"},
            {"step": "preprocess"},
            {
                "fork": {
                    "qwen": [
                        {"step": "llm-clean", "model": "lmstudio/qwen3-vl-8b"},
                    ],
                    "deepseek": [
                        {"step": "llm-clean", "model": "deepseek/deepseek-chat"},
                    ],
                }
            },
        ],
    }
}


def _write_pipeline(tmp_path: Path, data: dict) -> Path:
    """Write a pipeline YAML file and return its path."""
    p = tmp_path / "pipeline.yaml"
    p.write_text(yaml.dump(data))
    return p


def _make_provider_config(tmp_path: Path) -> tuple[Path, dict]:
    """Create a providers.yaml and return (path, loaded config dict)."""
    config = {
        "providers": {
            "lmstudio": {
                "base_url": "http://localhost:1234/v1",
                "env_key": "LMSTUDIO_KEY",
                "models": ["olmocr-2-7b", "qwen3-vl-8b"],
            },
            "deepseek": {
                "base_url": "https://api.deepseek.com/v1",
                "env_key": "DEEPSEEK_KEY",
                "models": ["deepseek-chat"],
            },
        }
    }
    p = tmp_path / "providers.yaml"
    p.write_text(yaml.dump(config))
    return p, config["providers"]


# ---------------------------------------------------------------------------
# TestLoadPipeline
# ---------------------------------------------------------------------------


class TestLoadPipeline:
    """Tests for load_pipeline()."""

    def test_loads_valid_config(self, tmp_path):
        path = _write_pipeline(tmp_path, VALID_PIPELINE)
        result = load_pipeline(str(path))
        assert result["name"] == "test-pipe"
        assert len(result["stages"]) == 2
        assert result["stages"][0]["step"] == "extract"

    def test_missing_pipeline_key(self, tmp_path):
        path = _write_pipeline(tmp_path, {"stages": [{"step": "extract"}]})
        with pytest.raises(ValueError, match="pipeline"):
            load_pipeline(str(path))

    def test_missing_name(self, tmp_path):
        data = {"pipeline": {"stages": [{"step": "extract"}]}}
        path = _write_pipeline(tmp_path, data)
        with pytest.raises(ValueError, match="name"):
            load_pipeline(str(path))

    def test_missing_stages(self, tmp_path):
        data = {"pipeline": {"name": "test"}}
        path = _write_pipeline(tmp_path, data)
        with pytest.raises(ValueError, match="stages"):
            load_pipeline(str(path))

    def test_invalid_step_type(self, tmp_path):
        data = {
            "pipeline": {
                "name": "test",
                "stages": [{"step": "nonexistent"}],
            }
        }
        path = _write_pipeline(tmp_path, data)
        with pytest.raises(ValueError, match="nonexistent"):
            load_pipeline(str(path))

    def test_loads_fork_config(self, tmp_path):
        path = _write_pipeline(tmp_path, FORK_PIPELINE)
        result = load_pipeline(str(path))
        assert result["name"] == "compare-llms"
        # Find the fork stage
        fork_stage = None
        for stage in result["stages"]:
            if "fork" in stage:
                fork_stage = stage
                break
        assert fork_stage is not None
        assert "qwen" in fork_stage["fork"]
        assert "deepseek" in fork_stage["fork"]

    def test_empty_stages(self, tmp_path):
        data = {"pipeline": {"name": "test", "stages": []}}
        path = _write_pipeline(tmp_path, data)
        with pytest.raises(ValueError, match="stages"):
            load_pipeline(str(path))

    def test_file_not_found(self):
        with pytest.raises(FileNotFoundError):
            load_pipeline("/nonexistent/pipeline.yaml")


# ---------------------------------------------------------------------------
# TestRunPipeline
# ---------------------------------------------------------------------------


class TestRunPipeline:
    """Tests for run_pipeline() with sequential stages."""

    def test_runs_sequential_stages(self, tmp_path, mocker):
        """extract -> preprocess runs in order, each handler called once."""
        input_file = tmp_path / "input.txt"
        input_file.write_text("raw content")
        output_dir = tmp_path / "output"

        mock_extract = mocker.patch(
            "ingest.pipeline.extract_text", return_value="extracted text"
        )
        mock_preprocess = mocker.patch(
            "ingest.pipeline.preprocess", return_value="preprocessed text"
        )

        pipeline = {
            "name": "test-pipe",
            "stages": [
                {"step": "extract"},
                {"step": "preprocess"},
            ],
        }

        run_pipeline(
            pipeline=pipeline,
            source_id=9995,
            input_path=str(input_file),
            provider_config={},
            output_dir=str(output_dir),
        )

        mock_extract.assert_called_once()
        mock_preprocess.assert_called_once()

        # Verify output files exist with correct naming
        extract_out = output_dir / "9995" / "test-pipe-1-extract.md"
        preprocess_out = output_dir / "9995" / "test-pipe-2-preprocess.md"
        assert extract_out.exists()
        assert preprocess_out.exists()
        assert extract_out.read_text() == "extracted text"
        assert preprocess_out.read_text() == "preprocessed text"

    def test_skips_existing_output(self, tmp_path, mocker):
        """If output file already exists, skip that stage."""
        input_file = tmp_path / "input.txt"
        input_file.write_text("raw content")
        output_dir = tmp_path / "output"

        # Pre-create the extract output
        extract_out = output_dir / "9995" / "test-pipe-1-extract.md"
        extract_out.parent.mkdir(parents=True, exist_ok=True)
        extract_out.write_text("already extracted")

        mock_extract = mocker.patch("ingest.pipeline.extract_text")
        mock_preprocess = mocker.patch(
            "ingest.pipeline.preprocess", return_value="preprocessed"
        )

        pipeline = {
            "name": "test-pipe",
            "stages": [
                {"step": "extract"},
                {"step": "preprocess"},
            ],
        }

        run_pipeline(
            pipeline=pipeline,
            source_id=9995,
            input_path=str(input_file),
            provider_config={},
            output_dir=str(output_dir),
        )

        # extract should NOT be called (skipped)
        mock_extract.assert_not_called()
        # preprocess should still run, reading the pre-existing extract output
        mock_preprocess.assert_called_once()

    def test_passes_model_to_llm_stages(self, tmp_path, mocker):
        """llm-clean and metadata stages resolve the model and pass provider."""
        input_file = tmp_path / "input.txt"
        input_file.write_text("raw content")
        output_dir = tmp_path / "output"

        from ingest.llm import CleanupResult, MetadataResult, TokenUsage

        mock_clean = mocker.patch(
            "ingest.pipeline.clean_text",
            return_value=CleanupResult(
                text="cleaned", usage=TokenUsage(10, 5)
            ),
        )
        mock_metadata = mocker.patch(
            "ingest.pipeline.extract_metadata",
            return_value=MetadataResult(
                title="Test", authors=["A"], year=2024, doi=None, usage=TokenUsage(10, 5)
            ),
        )
        mock_resolve = mocker.patch(
            "ingest.pipeline.resolve_model",
        )

        provider_config = {
            "test": {
                "base_url": "http://localhost:1234/v1",
                "env_key": "TEST_KEY",
                "models": ["test-model"],
            }
        }

        pipeline = {
            "name": "test-pipe",
            "stages": [
                {"step": "llm-clean", "model": "test/test-model"},
                {"step": "metadata", "model": "test/test-model"},
            ],
        }

        run_pipeline(
            pipeline=pipeline,
            source_id=9995,
            input_path=str(input_file),
            provider_config=provider_config,
            output_dir=str(output_dir),
        )

        # resolve_model should be called for each LLM stage
        assert mock_resolve.call_count == 2
        mock_clean.assert_called_once()
        mock_metadata.assert_called_once()

    def test_assemble_finds_metadata(self, tmp_path, mocker):
        """assemble picks up the metadata JSON output and the last cleaned text."""
        input_file = tmp_path / "input.txt"
        input_file.write_text("raw content")
        output_dir = tmp_path / "output"

        from ingest.llm import CleanupResult, MetadataResult, TokenUsage

        mocker.patch(
            "ingest.pipeline.clean_text",
            return_value=CleanupResult(
                text="cleaned body", usage=TokenUsage(10, 5)
            ),
        )
        mocker.patch(
            "ingest.pipeline.extract_metadata",
            return_value=MetadataResult(
                title="Paper Title",
                authors=["Author One"],
                year=2024,
                doi="10.1234/test",
                usage=TokenUsage(10, 5),
            ),
        )
        mocker.patch("ingest.pipeline.resolve_model")
        mock_assemble = mocker.patch("ingest.pipeline.assemble_document", return_value="---\nfinal doc\n")
        mock_frontmatter = mocker.patch("ingest.pipeline.build_frontmatter", return_value="source_id: 9995\n")

        pipeline = {
            "name": "test-pipe",
            "stages": [
                {"step": "llm-clean", "model": "test/test-model"},
                {"step": "metadata", "model": "test/test-model"},
                {"step": "assemble"},
            ],
        }

        run_pipeline(
            pipeline=pipeline,
            source_id=9995,
            input_path=str(input_file),
            provider_config={"test": {"base_url": "http://x", "env_key": "K", "models": ["test-model"]}},
            output_dir=str(output_dir),
        )

        # assemble should produce the final output file
        final_out = output_dir / "9995" / "test-pipe-9995.md"
        assert final_out.exists()
        mock_frontmatter.assert_called_once()
        mock_assemble.assert_called_once()

    def test_assemble_without_metadata_errors(self, tmp_path, mocker):
        """assemble without a preceding metadata step raises an error."""
        input_file = tmp_path / "input.txt"
        input_file.write_text("raw content")
        output_dir = tmp_path / "output"

        from ingest.llm import CleanupResult, TokenUsage

        mocker.patch(
            "ingest.pipeline.clean_text",
            return_value=CleanupResult(text="cleaned", usage=TokenUsage(10, 5)),
        )
        mocker.patch("ingest.pipeline.resolve_model")

        pipeline = {
            "name": "test-pipe",
            "stages": [
                {"step": "llm-clean", "model": "test/test-model"},
                {"step": "assemble"},
            ],
        }

        with pytest.raises(ValueError, match="metadata"):
            run_pipeline(
                pipeline=pipeline,
                source_id=9995,
                input_path=str(input_file),
                provider_config={"test": {"base_url": "http://x", "env_key": "K", "models": ["test-model"]}},
                output_dir=str(output_dir),
            )

    def test_output_naming(self, tmp_path, mocker):
        """Verify the file naming convention: prefix-N-step.ext."""
        input_file = tmp_path / "input.txt"
        input_file.write_text("raw content")
        output_dir = tmp_path / "output"

        from ingest.llm import CleanupResult, MetadataResult, TokenUsage

        mocker.patch("ingest.pipeline.extract_text", return_value="extracted")
        mocker.patch("ingest.pipeline.preprocess", return_value="preprocessed")
        mocker.patch(
            "ingest.pipeline.clean_text",
            return_value=CleanupResult(text="cleaned", usage=TokenUsage(10, 5)),
        )
        mocker.patch(
            "ingest.pipeline.extract_metadata",
            return_value=MetadataResult(
                title="T", authors=[], year=2024, doi=None, usage=TokenUsage(10, 5)
            ),
        )
        mocker.patch("ingest.pipeline.resolve_model")
        mocker.patch("ingest.pipeline.build_frontmatter", return_value="fm\n")
        mocker.patch("ingest.pipeline.assemble_document", return_value="---\nfm\n---\nbody\n")

        pipeline = {
            "name": "bhl-ocr-cleanup",
            "stages": [
                {"step": "extract"},
                {"step": "preprocess"},
                {"step": "llm-clean", "model": "test/test-model"},
                {"step": "metadata", "model": "test/test-model"},
                {"step": "assemble"},
            ],
        }

        run_pipeline(
            pipeline=pipeline,
            source_id=9995,
            input_path=str(input_file),
            provider_config={"test": {"base_url": "http://x", "env_key": "K", "models": ["test-model"]}},
            output_dir=str(output_dir),
        )

        source_dir = output_dir / "9995"
        assert (source_dir / "bhl-ocr-cleanup-1-extract.md").exists()
        assert (source_dir / "bhl-ocr-cleanup-2-preprocess.md").exists()
        assert (source_dir / "bhl-ocr-cleanup-3-llm-clean.md").exists()
        assert (source_dir / "bhl-ocr-cleanup-4-metadata.json").exists()
        assert (source_dir / "bhl-ocr-cleanup-9995.md").exists()

    def test_ocr_stage(self, tmp_path, mocker):
        """OCR stage calls ocr_pdf and writes output."""
        input_file = tmp_path / "input.pdf"
        input_file.write_text("fake pdf")
        output_dir = tmp_path / "output"

        from ingest.llm import TokenUsage
        from ingest.ocr import OcrResult

        mocker.patch(
            "ingest.pipeline.ocr_pdf",
            return_value=OcrResult(text="ocr text", usage=TokenUsage(100, 50)),
        )
        mocker.patch("ingest.pipeline.resolve_model")

        pipeline = {
            "name": "test-pipe",
            "stages": [
                {"step": "ocr", "model": "test/test-model"},
            ],
        }

        run_pipeline(
            pipeline=pipeline,
            source_id=9995,
            input_path=str(input_file),
            provider_config={"test": {"base_url": "http://x", "env_key": "K", "models": ["test-model"]}},
            output_dir=str(output_dir),
        )

        ocr_out = output_dir / "9995" / "test-pipe-1-ocr.md"
        assert ocr_out.exists()
        assert ocr_out.read_text() == "ocr text"


# ---------------------------------------------------------------------------
# TestForkPipeline
# ---------------------------------------------------------------------------


class TestDataExtractStep:
    """Tests for the data-extract pipeline step."""

    def test_data_extract_is_valid_step(self, tmp_path):
        """data-extract is recognized as a valid step type."""
        data = {
            "pipeline": {
                "name": "test",
                "stages": [{"step": "data-extract", "model": "test/test-model"}],
            }
        }
        path = _write_pipeline(tmp_path, data)
        result = load_pipeline(str(path))
        assert result["stages"][0]["step"] == "data-extract"

    def test_runs_data_extract_stage(self, tmp_path, mocker):
        """data-extract stage calls extract_data and writes JSON output."""
        input_file = tmp_path / "input.txt"
        input_file.write_text("scholarly text")
        output_dir = tmp_path / "output"

        from ingest.llm import DataExtractResult, TokenUsage

        mock_extract = mocker.patch(
            "ingest.pipeline.extract_data",
            return_value=DataExtractResult(
                records=[{"gall_species": {"name": "Test gall"}, "confidence": 0.9}],
                usage=TokenUsage(100, 50),
            ),
        )
        mocker.patch("ingest.pipeline.resolve_model")

        pipeline = {
            "name": "test-pipe",
            "stages": [
                {"step": "data-extract", "model": "test/test-model"},
            ],
        }

        run_pipeline(
            pipeline=pipeline,
            source_id=9995,
            input_path=str(input_file),
            provider_config={"test": {"base_url": "http://x", "env_key": "K", "models": ["test-model"]}},
            output_dir=str(output_dir),
        )

        mock_extract.assert_called_once()

        # Output should be JSON
        data_out = output_dir / "9995" / "test-pipe-1-data-extract.json"
        assert data_out.exists()
        data = json.loads(data_out.read_text())
        assert len(data) == 1
        assert data[0]["gall_species"]["name"] == "Test gall"

    def test_output_uses_json_extension(self, tmp_path, mocker):
        """data-extract output files use .json extension."""
        input_file = tmp_path / "input.txt"
        input_file.write_text("text")
        output_dir = tmp_path / "output"

        from ingest.llm import DataExtractResult, TokenUsage

        mocker.patch(
            "ingest.pipeline.extract_data",
            return_value=DataExtractResult(
                records=[], usage=TokenUsage(10, 5),
            ),
        )
        mocker.patch("ingest.pipeline.resolve_model")

        pipeline = {
            "name": "test-pipe",
            "stages": [
                {"step": "data-extract", "model": "test/test-model"},
            ],
        }

        run_pipeline(
            pipeline=pipeline,
            source_id=9995,
            input_path=str(input_file),
            provider_config={"test": {"base_url": "http://x", "env_key": "K", "models": ["test-model"]}},
            output_dir=str(output_dir),
        )

        source_dir = output_dir / "9995"
        json_files = list(source_dir.glob("*.json"))
        assert len(json_files) == 1
        assert json_files[0].name == "test-pipe-1-data-extract.json"


class TestForkPipeline:
    """Tests for pipeline forking."""

    def test_fork_runs_branches(self, tmp_path, mocker):
        """Shared stages run once, then each fork branch runs."""
        input_file = tmp_path / "input.txt"
        input_file.write_text("raw content")
        output_dir = tmp_path / "output"

        from ingest.llm import CleanupResult, TokenUsage

        mocker.patch("ingest.pipeline.preprocess", return_value="preprocessed")
        mock_clean = mocker.patch(
            "ingest.pipeline.clean_text",
            return_value=CleanupResult(text="cleaned", usage=TokenUsage(10, 5)),
        )
        mocker.patch("ingest.pipeline.resolve_model")

        pipeline = {
            "name": "compare-llms",
            "stages": [
                {"step": "preprocess"},
                {
                    "fork": {
                        "qwen": [
                            {"step": "llm-clean", "model": "test/test-model"},
                        ],
                        "deepseek": [
                            {"step": "llm-clean", "model": "test/test-model"},
                        ],
                    }
                },
            ],
        }

        run_pipeline(
            pipeline=pipeline,
            source_id=9995,
            input_path=str(input_file),
            provider_config={"test": {"base_url": "http://x", "env_key": "K", "models": ["test-model"]}},
            output_dir=str(output_dir),
        )

        # clean_text should be called twice (once per branch)
        assert mock_clean.call_count == 2

    def test_fork_output_naming(self, tmp_path, mocker):
        """Fork branch names appear in output file names."""
        input_file = tmp_path / "input.txt"
        input_file.write_text("raw content")
        output_dir = tmp_path / "output"

        from ingest.llm import CleanupResult, TokenUsage

        mocker.patch("ingest.pipeline.preprocess", return_value="preprocessed")
        mocker.patch(
            "ingest.pipeline.clean_text",
            return_value=CleanupResult(text="cleaned", usage=TokenUsage(10, 5)),
        )
        mocker.patch("ingest.pipeline.resolve_model")

        pipeline = {
            "name": "compare-llms",
            "stages": [
                {"step": "preprocess"},
                {
                    "fork": {
                        "qwen": [
                            {"step": "llm-clean", "model": "test/test-model"},
                        ],
                        "deepseek": [
                            {"step": "llm-clean", "model": "test/test-model"},
                        ],
                    }
                },
            ],
        }

        run_pipeline(
            pipeline=pipeline,
            source_id=9995,
            input_path=str(input_file),
            provider_config={"test": {"base_url": "http://x", "env_key": "K", "models": ["test-model"]}},
            output_dir=str(output_dir),
        )

        source_dir = output_dir / "9995"
        # Shared stage uses normal numbering
        assert (source_dir / "compare-llms-1-preprocess.md").exists()
        # Fork branches use branch name in place of step number
        assert (source_dir / "compare-llms-qwen-2-llm-clean.md").exists()
        assert (source_dir / "compare-llms-deepseek-2-llm-clean.md").exists()
