"""Integration tests: run multiple subcommands in sequence."""

from __future__ import annotations

import json
from unittest.mock import Mock

from click.testing import CliRunner

from ingest.cli import cli


class TestSubcommandPipeline:
    """Test running extract -> preprocess -> llm-clean -> metadata -> assemble."""

    def test_full_pipeline_via_subcommands(self, tmp_path, mocker):
        """Run the full pipeline as separate subcommand invocations."""
        runner = CliRunner()

        # -- Step 1: Extract --
        input_file = tmp_path / "input.txt"
        input_file.write_text("Some raw text about Andricus quercuscalifornicus.")
        extracted_file = tmp_path / "extracted.txt"

        result = runner.invoke(cli, [
            "extract",
            "-i", str(input_file),
            "-o", str(extracted_file),
        ])
        assert result.exit_code == 0, f"extract failed: {result.output}"
        assert extracted_file.exists()

        # -- Step 2: Preprocess --
        preprocessed_file = tmp_path / "preprocessed.txt"

        result = runner.invoke(cli, [
            "preprocess",
            "-i", str(extracted_file),
            "-o", str(preprocessed_file),
        ])
        assert result.exit_code == 0, f"preprocess failed: {result.output}"
        assert preprocessed_file.exists()

        # -- Step 3: LLM Clean --
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

        mock_client_cls = mocker.patch("ingest.llm.OpenAI")
        cleanup_response = Mock()
        cleanup_response.choices = [Mock(message=Mock(
            content="Cleaned text about *Andricus quercuscalifornicus*."
        ))]
        cleanup_response.usage = Mock(prompt_tokens=50, completion_tokens=30)

        metadata_response = Mock()
        metadata_response.choices = [Mock(message=Mock(
            content='{"title": "Test Document", "authors": ["Author One"], "year": 2024, "doi": null}'
        ))]
        metadata_response.usage = Mock(prompt_tokens=40, completion_tokens=20)

        mock_client_cls.return_value.chat.completions.create.side_effect = [
            cleanup_response,
            metadata_response,
        ]

        cleaned_file = tmp_path / "cleaned.txt"

        result = runner.invoke(cli, [
            "llm-clean",
            "-i", str(preprocessed_file),
            "-o", str(cleaned_file),
            "--model", "test/test-model",
            "--config", str(config_file),
        ])
        assert result.exit_code == 0, f"llm-clean failed: {result.output}"
        assert cleaned_file.exists()
        assert "Andricus quercuscalifornicus" in cleaned_file.read_text()

        # -- Step 4: Metadata --
        metadata_file = tmp_path / "metadata.json"

        result = runner.invoke(cli, [
            "metadata",
            "-i", str(preprocessed_file),
            "-o", str(metadata_file),
            "--model", "test/test-model",
            "--config", str(config_file),
        ])
        assert result.exit_code == 0, f"metadata failed: {result.output}"
        assert metadata_file.exists()

        meta = json.loads(metadata_file.read_text())
        assert meta["title"] == "Test Document"

        # -- Step 5: Assemble --
        output_file = tmp_path / "output.md"

        result = runner.invoke(cli, [
            "assemble",
            "-i", str(cleaned_file),
            "--metadata", str(metadata_file),
            "-o", str(output_file),
            "--source-id", "1234",
        ])
        assert result.exit_code == 0, f"assemble failed: {result.output}"
        assert output_file.exists()

        content = output_file.read_text()
        assert "---" in content
        assert "source_id: 1234" in content
        assert "Andricus quercuscalifornicus" in content
