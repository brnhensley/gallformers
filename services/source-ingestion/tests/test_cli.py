"""Tests for the CLI subcommands."""

from __future__ import annotations

import json
from unittest.mock import Mock

from click.testing import CliRunner

from ingest.cli import cli


class TestCliGroup:
    """Test the top-level CLI group."""

    def test_help_shows_subcommands(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["--help"])
        assert result.exit_code == 0
        assert "extract" in result.output
        assert "ocr" in result.output
        assert "preprocess" in result.output
        assert "llm-clean" in result.output
        assert "metadata" in result.output
        assert "assemble" in result.output
        assert "run" in result.output

    def test_no_args_shows_help(self):
        runner = CliRunner()
        result = runner.invoke(cli, [])
        assert result.exit_code == 0
        assert "extract" in result.output


class TestExtract:
    """Test the extract subcommand."""

    def test_extract_help(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["extract", "--help"])
        assert result.exit_code == 0
        assert "--input" in result.output or "-i" in result.output
        assert "--output" in result.output or "-o" in result.output

    def test_extract_plain_text(self, tmp_path, mocker):
        input_file = tmp_path / "input.txt"
        input_file.write_text("Hello world from a text file.")
        output_file = tmp_path / "output.txt"

        mock_extract = mocker.patch("ingest.cli.extract_text", return_value="Hello world from a text file.")

        runner = CliRunner()
        result = runner.invoke(cli, [
            "extract",
            "-i", str(input_file),
            "-o", str(output_file),
        ])

        assert result.exit_code == 0, f"CLI failed: {result.output}"
        mock_extract.assert_called_once_with(str(input_file))
        assert output_file.read_text() == "Hello world from a text file."

    def test_extract_missing_input(self, tmp_path, mocker):
        output_file = tmp_path / "output.txt"
        mocker.patch("ingest.cli.extract_text", side_effect=FileNotFoundError("File not found: /missing.txt"))

        runner = CliRunner()
        result = runner.invoke(cli, [
            "extract",
            "-i", "/missing.txt",
            "-o", str(output_file),
        ])

        assert result.exit_code != 0

    def test_extract_missing_required_args(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["extract"])
        assert result.exit_code != 0


class TestOcr:
    """Test the ocr subcommand."""

    def test_ocr_help(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["ocr", "--help"])
        assert result.exit_code == 0
        assert "--input" in result.output or "-i" in result.output
        assert "--output" in result.output or "-o" in result.output
        assert "--model" in result.output

    def test_ocr_runs(self, tmp_path, mocker):
        input_file = tmp_path / "input.pdf"
        input_file.write_text("fake pdf")
        output_file = tmp_path / "output.txt"

        config_file = tmp_path / "providers.yaml"
        config_file.write_text(
            "providers:\n"
            "  test:\n"
            "    base_url: http://localhost:8000/v1\n"
            "    env_key: TEST_API_KEY\n"
            "    models:\n"
            "      - vision-model\n"
        )
        mocker.patch.dict("os.environ", {"TEST_API_KEY": "fake-key"})

        from ingest.llm import TokenUsage
        from ingest.ocr import OcrResult

        mock_ocr = mocker.patch(
            "ingest.cli.ocr_pdf",
            return_value=OcrResult(text="OCR extracted text", usage=TokenUsage(100, 50)),
        )

        runner = CliRunner()
        result = runner.invoke(cli, [
            "ocr",
            "-i", str(input_file),
            "-o", str(output_file),
            "--model", "test/vision-model",
            "--config", str(config_file),
        ])

        assert result.exit_code == 0, f"CLI failed: {result.output}"
        mock_ocr.assert_called_once()
        assert output_file.read_text() == "OCR extracted text"

    def test_ocr_missing_model(self, tmp_path):
        input_file = tmp_path / "input.pdf"
        input_file.write_text("fake pdf")
        output_file = tmp_path / "output.txt"

        runner = CliRunner()
        result = runner.invoke(cli, [
            "ocr",
            "-i", str(input_file),
            "-o", str(output_file),
        ])
        assert result.exit_code != 0


class TestPreprocess:
    """Test the preprocess subcommand."""

    def test_preprocess_help(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["preprocess", "--help"])
        assert result.exit_code == 0
        assert "--input" in result.output or "-i" in result.output
        assert "--output" in result.output or "-o" in result.output

    def test_preprocess_runs(self, tmp_path, mocker):
        input_file = tmp_path / "input.txt"
        input_file.write_text("Some raw text to preprocess.")
        output_file = tmp_path / "output.txt"

        mock_preprocess = mocker.patch("ingest.cli.preprocess", return_value="Preprocessed text.")

        runner = CliRunner()
        result = runner.invoke(cli, [
            "preprocess",
            "-i", str(input_file),
            "-o", str(output_file),
        ])

        assert result.exit_code == 0, f"CLI failed: {result.output}"
        mock_preprocess.assert_called_once_with("Some raw text to preprocess.")
        assert output_file.read_text() == "Preprocessed text."


class TestLlmClean:
    """Test the llm-clean subcommand."""

    def test_llm_clean_help(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["llm-clean", "--help"])
        assert result.exit_code == 0
        assert "--input" in result.output or "-i" in result.output
        assert "--output" in result.output or "-o" in result.output
        assert "--model" in result.output

    def test_llm_clean_runs(self, tmp_path, mocker):
        input_file = tmp_path / "input.txt"
        input_file.write_text("Raw text for LLM cleanup.")
        output_file = tmp_path / "output.txt"

        config_file = tmp_path / "providers.yaml"
        config_file.write_text(
            "providers:\n"
            "  test:\n"
            "    base_url: http://localhost:8000/v1\n"
            "    env_key: TEST_API_KEY\n"
            "    models:\n"
            "      - test-model\n"
        )
        mocker.patch.dict("os.environ", {"TEST_API_KEY": "fake-key"})

        from ingest.llm import CleanupResult, TokenUsage

        mock_clean = mocker.patch(
            "ingest.cli.clean_text",
            return_value=CleanupResult(text="Cleaned text.", usage=TokenUsage(50, 30)),
        )

        runner = CliRunner()
        result = runner.invoke(cli, [
            "llm-clean",
            "-i", str(input_file),
            "-o", str(output_file),
            "--model", "test/test-model",
            "--config", str(config_file),
        ])

        assert result.exit_code == 0, f"CLI failed: {result.output}"
        mock_clean.assert_called_once()
        assert output_file.read_text() == "Cleaned text."


class TestMetadata:
    """Test the metadata subcommand."""

    def test_metadata_help(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["metadata", "--help"])
        assert result.exit_code == 0
        assert "--input" in result.output or "-i" in result.output
        assert "--output" in result.output or "-o" in result.output
        assert "--model" in result.output

    def test_metadata_runs(self, tmp_path, mocker):
        input_file = tmp_path / "input.txt"
        input_file.write_text("Document text for metadata extraction.")
        output_file = tmp_path / "metadata.json"

        config_file = tmp_path / "providers.yaml"
        config_file.write_text(
            "providers:\n"
            "  test:\n"
            "    base_url: http://localhost:8000/v1\n"
            "    env_key: TEST_API_KEY\n"
            "    models:\n"
            "      - test-model\n"
        )
        mocker.patch.dict("os.environ", {"TEST_API_KEY": "fake-key"})

        from ingest.llm import MetadataResult, TokenUsage

        mock_metadata = mocker.patch(
            "ingest.cli.extract_metadata",
            return_value=MetadataResult(
                title="Test Paper",
                authors=["Author One", "Author Two"],
                year=2024,
                doi="10.1234/test",
                usage=TokenUsage(40, 20),
            ),
        )

        runner = CliRunner()
        result = runner.invoke(cli, [
            "metadata",
            "-i", str(input_file),
            "-o", str(output_file),
            "--model", "test/test-model",
            "--config", str(config_file),
        ])

        assert result.exit_code == 0, f"CLI failed: {result.output}"
        mock_metadata.assert_called_once()

        # Verify JSON output
        data = json.loads(output_file.read_text())
        assert data["title"] == "Test Paper"
        assert data["authors"] == ["Author One", "Author Two"]
        assert data["year"] == 2024
        assert data["doi"] == "10.1234/test"


class TestDataExtract:
    """Test the data-extract subcommand."""

    def test_data_extract_help(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["data-extract", "--help"])
        assert result.exit_code == 0
        assert "--input" in result.output or "-i" in result.output
        assert "--output" in result.output or "-o" in result.output
        assert "--model" in result.output

    def test_data_extract_runs(self, tmp_path, mocker):
        input_file = tmp_path / "input.txt"
        input_file.write_text("Scholarly text about galls.")
        output_file = tmp_path / "data.json"

        config_file = tmp_path / "providers.yaml"
        config_file.write_text(
            "providers:\n"
            "  test:\n"
            "    base_url: http://localhost:8000/v1\n"
            "    env_key: TEST_API_KEY\n"
            "    models:\n"
            "      - test-model\n"
        )
        mocker.patch.dict("os.environ", {"TEST_API_KEY": "fake-key"})

        from ingest.llm import DataExtractResult, TokenUsage

        mock_extract = mocker.patch(
            "ingest.cli.extract_data",
            return_value=DataExtractResult(
                records=[{"gall_species": {"name": "Test gall"}, "confidence": 0.9}],
                usage=TokenUsage(100, 50),
            ),
        )

        runner = CliRunner()
        result = runner.invoke(cli, [
            "data-extract",
            "-i", str(input_file),
            "-o", str(output_file),
            "--model", "test/test-model",
            "--config", str(config_file),
        ])

        assert result.exit_code == 0, f"CLI failed: {result.output}"
        mock_extract.assert_called_once()

        # Verify JSON output
        data = json.loads(output_file.read_text())
        assert len(data) == 1
        assert data[0]["gall_species"]["name"] == "Test gall"

    def test_data_extract_appears_in_help(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["--help"])
        assert "data-extract" in result.output


class TestAssemble:
    """Test the assemble subcommand."""

    def test_assemble_help(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["assemble", "--help"])
        assert result.exit_code == 0
        assert "--input" in result.output or "-i" in result.output
        assert "--metadata" in result.output
        assert "--output" in result.output or "-o" in result.output
        assert "--source-id" in result.output

    def test_assemble_runs(self, tmp_path):
        cleaned_file = tmp_path / "cleaned.txt"
        cleaned_file.write_text("This is the cleaned body text.")

        metadata_file = tmp_path / "metadata.json"
        metadata_file.write_text(json.dumps({
            "title": "Test Paper",
            "authors": ["Author One"],
            "year": 2024,
            "doi": None,
        }))

        output_file = tmp_path / "output.md"

        runner = CliRunner()
        result = runner.invoke(cli, [
            "assemble",
            "-i", str(cleaned_file),
            "--metadata", str(metadata_file),
            "-o", str(output_file),
            "--source-id", "42",
        ])

        assert result.exit_code == 0, f"CLI failed: {result.output}"

        content = output_file.read_text()
        assert "---" in content
        assert "source_id: 42" in content
        assert "title: Test Paper" in content
        assert "This is the cleaned body text." in content

    def test_assemble_missing_metadata_file(self, tmp_path):
        cleaned_file = tmp_path / "cleaned.txt"
        cleaned_file.write_text("Body text.")
        output_file = tmp_path / "output.md"

        runner = CliRunner()
        result = runner.invoke(cli, [
            "assemble",
            "-i", str(cleaned_file),
            "--metadata", "/nonexistent/metadata.json",
            "-o", str(output_file),
            "--source-id", "42",
        ])

        assert result.exit_code != 0


class TestRun:
    """Test the run subcommand."""

    def test_run_help(self):
        runner = CliRunner()
        result = runner.invoke(cli, ["run", "--help"])
        assert result.exit_code == 0
        assert "--pipeline" in result.output or "-p" in result.output
        assert "--source-id" in result.output
        assert "--input" in result.output or "-i" in result.output

    def test_run_calls_pipeline(self, tmp_path, mocker):
        pipeline_file = tmp_path / "pipeline.yaml"
        pipeline_file.write_text(
            "pipeline:\n"
            "  name: test\n"
            "  stages:\n"
            "    - step: extract\n"
        )
        input_file = tmp_path / "input.txt"
        input_file.write_text("Some text.")

        config_file = tmp_path / "providers.yaml"
        config_file.write_text("providers:\n  test:\n    base_url: http://x\n    env_key: K\n    models:\n      - m\n")

        mock_run = mocker.patch("ingest.cli.run_pipeline")

        runner = CliRunner()
        result = runner.invoke(cli, [
            "run",
            "-p", str(pipeline_file),
            "--source-id", "1",
            "-i", str(input_file),
            "--config", str(config_file),
        ])

        assert result.exit_code == 0, f"CLI failed: {result.output}"
        assert "Running pipeline" in result.output
        mock_run.assert_called_once()

    def test_run_invalid_pipeline(self, tmp_path):
        pipeline_file = tmp_path / "pipeline.yaml"
        pipeline_file.write_text("stages: []")
        input_file = tmp_path / "input.txt"
        input_file.write_text("Some text.")

        runner = CliRunner()
        result = runner.invoke(cli, [
            "run",
            "-p", str(pipeline_file),
            "--source-id", "1",
            "-i", str(input_file),
        ])

        assert result.exit_code != 0
