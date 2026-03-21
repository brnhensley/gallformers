"""Tests for output assembly and writing."""

from unittest.mock import Mock

import pytest
import yaml

from ingest.llm import MetadataResult, TokenUsage


@pytest.fixture()
def metadata():
    """Return a full MetadataResult for testing."""
    return MetadataResult(
        title="Gall Wasps of North America",
        authors=["Smith, J.", "Jones, A."],
        year=2020,
        doi="10.1234/test.567",
        usage=TokenUsage(prompt_tokens=100, completion_tokens=50),
    )


@pytest.fixture()
def metadata_partial():
    """Return a MetadataResult with None fields."""
    return MetadataResult(
        title="Partial Paper",
        authors=["Smith, J."],
        year=2021,
        doi=None,
        usage=TokenUsage(prompt_tokens=80, completion_tokens=40),
    )


class TestBuildFrontmatter:
    def test_basic(self, metadata):
        from ingest.output import build_frontmatter

        result = build_frontmatter(source_id=42, metadata=metadata)
        parsed = yaml.safe_load(result)

        assert parsed["source_id"] == 42
        assert parsed["title"] == "Gall Wasps of North America"
        assert parsed["authors"] == ["Smith, J.", "Jones, A."]
        assert parsed["year"] == 2020
        assert parsed["doi"] == "10.1234/test.567"

    def test_omits_none(self, metadata_partial):
        from ingest.output import build_frontmatter

        result = build_frontmatter(source_id=7, metadata=metadata_partial)
        parsed = yaml.safe_load(result)

        assert parsed["source_id"] == 7
        assert parsed["title"] == "Partial Paper"
        assert parsed["year"] == 2021
        assert "doi" not in parsed

    def test_extra_fields(self, metadata):
        from ingest.output import build_frontmatter

        result = build_frontmatter(
            source_id=42,
            metadata=metadata,
            extra={"journal": "Entomology Today", "volume": 15},
        )
        parsed = yaml.safe_load(result)

        assert parsed["journal"] == "Entomology Today"
        assert parsed["volume"] == 15
        # Standard fields still present.
        assert parsed["source_id"] == 42
        assert parsed["title"] == "Gall Wasps of North America"

    def test_extra_none_values_omitted(self, metadata):
        from ingest.output import build_frontmatter

        result = build_frontmatter(
            source_id=42,
            metadata=metadata,
            extra={"journal": "Entomology Today", "pages": None},
        )
        parsed = yaml.safe_load(result)

        assert parsed["journal"] == "Entomology Today"
        assert "pages" not in parsed


class TestAssembleDocument:
    def test_format(self):
        from ingest.output import assemble_document

        frontmatter = "source_id: 42\ntitle: Test\n"
        body = "This is the body text."

        result = assemble_document(frontmatter, body)

        assert result == "---\nsource_id: 42\ntitle: Test\n---\n\nThis is the body text.\n"

    def test_body_trailing_newline(self):
        from ingest.output import assemble_document

        result = assemble_document("title: Test\n", "Body already has newline.\n")

        # Should not double the trailing newline.
        assert result.endswith("Body already has newline.\n")
        assert not result.endswith("Body already has newline.\n\n")


class TestWriteLocal:
    def test_creates_file(self, tmp_path):
        from ingest.output import write_local

        document = "---\ntitle: Test\n---\n\nBody.\n"
        output_dir = str(tmp_path / "output")

        path = write_local(document, source_id=42, output_dir=output_dir)

        assert path == f"{output_dir}/42.md"
        with open(path) as f:
            assert f.read() == document

    def test_creates_directory(self, tmp_path):
        from ingest.output import write_local

        nested_dir = str(tmp_path / "deep" / "nested" / "output")
        document = "---\ntitle: Test\n---\n\nBody.\n"

        path = write_local(document, source_id=1, output_dir=nested_dir)

        assert path == f"{nested_dir}/1.md"
        with open(path) as f:
            assert f.read() == document


class TestWriteS3:
    def test_uploads(self, mocker):
        from ingest.output import write_s3

        mock_boto = mocker.patch("ingest.output.boto3")
        mock_client = Mock()
        mock_boto.client.return_value = mock_client

        document = "---\ntitle: Test\n---\n\nBody.\n"
        uri = write_s3(document, source_id=42, bucket="my-bucket")

        assert uri == "s3://my-bucket/sources/42.md"
        mock_boto.client.assert_called_once_with("s3")
        mock_client.put_object.assert_called_once_with(
            Bucket="my-bucket",
            Key="sources/42.md",
            Body=document,
            ContentType="text/markdown",
        )

    def test_env_bucket(self, mocker, monkeypatch):
        from ingest.output import write_s3

        mock_boto = mocker.patch("ingest.output.boto3")
        mock_client = Mock()
        mock_boto.client.return_value = mock_client
        monkeypatch.setenv("INGEST_S3_BUCKET", "env-bucket")

        uri = write_s3("doc content", source_id=7)

        assert uri == "s3://env-bucket/sources/7.md"
        mock_client.put_object.assert_called_once()
        assert mock_client.put_object.call_args[1]["Bucket"] == "env-bucket"

    def test_no_bucket_raises(self, mocker, monkeypatch):
        from ingest.output import write_s3

        mocker.patch("ingest.output.boto3")
        monkeypatch.delenv("INGEST_S3_BUCKET", raising=False)

        with pytest.raises(ValueError, match="bucket"):
            write_s3("doc content", source_id=7)


class TestFormatSummary:
    def test_contains_expected_info(self):
        from ingest.output import format_summary

        usage = TokenUsage(prompt_tokens=500, completion_tokens=200)
        result = format_summary(
            source_id=42,
            output_path="output/42.md",
            usage=usage,
            elapsed=3.75,
        )

        assert "output/42.md" in result
        assert "500" in result
        assert "200" in result
        assert "3.75" in result or "3.8" in result

    def test_cost_estimate(self):
        from ingest.output import format_summary

        usage = TokenUsage(prompt_tokens=1000, completion_tokens=1000)
        result = format_summary(
            source_id=1,
            output_path="output/1.md",
            usage=usage,
            elapsed=1.0,
            cost_per_1k_tokens=0.01,
        )

        # 2000 tokens at $0.01/1k = $0.02
        assert "0.02" in result
