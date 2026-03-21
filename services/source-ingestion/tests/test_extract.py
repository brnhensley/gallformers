from pathlib import Path

import pytest

from ingest.extract import extract_text


class TestInputDetection:
    """Verify that extract_text dispatches to the correct backend."""

    def test_detects_pdf_by_extension(self, mocker):
        mock_pdf = mocker.patch("ingest.extract.pymupdf4llm.to_markdown", return_value="pdf content")
        extract_text("paper.pdf")
        mock_pdf.assert_called_once_with("paper.pdf")

    def test_detects_url_by_prefix(self, mocker):
        mocker.patch("ingest.extract.trafilatura.fetch_url", return_value="<html></html>")
        mock_extract = mocker.patch("ingest.extract.trafilatura.extract", return_value="web content")
        extract_text("https://example.com/article")
        mock_extract.assert_called_once()

    def test_detects_plain_text(self, mocker, tmp_path):
        f = tmp_path / "notes.txt"
        f.write_text("hello")
        # Should NOT call pdf or url backends
        mock_pdf = mocker.patch("ingest.extract.pymupdf4llm.to_markdown")
        mock_fetch = mocker.patch("ingest.extract.trafilatura.fetch_url")
        extract_text(str(f))
        mock_pdf.assert_not_called()
        mock_fetch.assert_not_called()


class TestPlainText:
    def test_plain_text_reads_file(self, tmp_path):
        f = tmp_path / "sample.txt"
        f.write_text("Some extracted content\nwith multiple lines")
        result = extract_text(str(f))
        assert result == "Some extracted content\nwith multiple lines"

    def test_missing_file_raises_error(self):
        with pytest.raises(FileNotFoundError):
            extract_text("/nonexistent/path/to/file.txt")


class TestURLExtraction:
    def test_url_fetch_failure_raises_error(self, mocker):
        mocker.patch("ingest.extract.trafilatura.fetch_url", return_value=None)
        with pytest.raises(RuntimeError, match="fetch"):
            extract_text("https://example.com/missing")

    def test_url_extract_empty_raises_error(self, mocker):
        mocker.patch("ingest.extract.trafilatura.fetch_url", return_value="<html></html>")
        mocker.patch("ingest.extract.trafilatura.extract", return_value=None)
        with pytest.raises(RuntimeError, match="extract"):
            extract_text("https://example.com/empty")


class TestPDFExtraction:
    def test_pdf_extraction_calls_pymupdf4llm(self, mocker):
        mock_pdf = mocker.patch(
            "ingest.extract.pymupdf4llm.to_markdown",
            return_value="# Title\n\nParagraph from PDF",
        )
        result = extract_text("document.pdf")
        mock_pdf.assert_called_once_with("document.pdf")
        assert result == "# Title\n\nParagraph from PDF"
