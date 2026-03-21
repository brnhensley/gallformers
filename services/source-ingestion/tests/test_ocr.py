"""Tests for vision-model OCR extraction."""

from unittest.mock import Mock

import pytest

from ingest.ocr import extract_pages_as_images, ocr_page, ocr_pdf
from ingest.providers import ProviderConfig


@pytest.fixture()
def provider():
    return ProviderConfig(
        base_url="http://localhost:1234/v1",
        api_key="not-needed",
        model="olmocr-2-7b",
        no_system_role=True,
    )


class TestExtractPagesAsImages:
    def test_returns_base64_list(self, tmp_path, mocker):
        """Should convert PDF pages to base64-encoded PNG images."""
        mock_doc = Mock()
        mock_page = Mock()
        mock_pixmap = Mock()
        mock_pixmap.tobytes.return_value = b"fake-png-data"
        mock_page.get_pixmap.return_value = mock_pixmap
        mock_doc.__iter__ = Mock(return_value=iter([mock_page]))
        mock_doc.__len__ = Mock(return_value=1)
        mock_doc.__enter__ = Mock(return_value=mock_doc)
        mock_doc.__exit__ = Mock(return_value=False)
        mocker.patch("ingest.ocr.pymupdf.open", return_value=mock_doc)

        images = extract_pages_as_images("test.pdf")

        assert len(images) == 1
        assert isinstance(images[0], str)  # base64 string


class TestOcrPage:
    def test_sends_image_to_model(self, provider, mocker):
        """Should send a base64 image to the vision model and return text."""
        mock_client_cls = mocker.patch("ingest.ocr.OpenAI")
        mock_response = Mock()
        mock_response.choices = [Mock(message=Mock(content="Extracted text from page."))]
        mock_response.usage = Mock(prompt_tokens=500, completion_tokens=100)
        mock_client_cls.return_value.chat.completions.create.return_value = mock_response

        text, usage = ocr_page("base64data", provider)

        assert text == "Extracted text from page."
        assert usage.prompt_tokens == 500

        # Verify image was sent in the message
        call_kwargs = mock_client_cls.return_value.chat.completions.create.call_args[1]
        messages = call_kwargs["messages"]
        user_msg = messages[0] if provider.no_system_role else messages[1]
        content_parts = user_msg["content"]
        assert any(p.get("type") == "image_url" for p in content_parts)

    def test_api_error_raises(self, provider, mocker):
        from openai import APIError
        mock_client_cls = mocker.patch("ingest.ocr.OpenAI")
        mock_client_cls.return_value.chat.completions.create.side_effect = APIError(
            message="error", request=Mock(), body=None,
        )

        with pytest.raises(RuntimeError, match="OCR API call failed"):
            ocr_page("base64data", provider)


class TestOcrPdf:
    def test_processes_all_pages(self, provider, mocker):
        """Should OCR each page and join results."""
        mocker.patch("ingest.ocr.extract_pages_as_images", return_value=["img1", "img2", "img3"])

        mock_client_cls = mocker.patch("ingest.ocr.OpenAI")
        mock_response = Mock()
        mock_response.choices = [Mock(message=Mock(content="Page text."))]
        mock_response.usage = Mock(prompt_tokens=100, completion_tokens=50)
        mock_client_cls.return_value.chat.completions.create.return_value = mock_response

        result = ocr_pdf("test.pdf", provider)

        assert mock_client_cls.return_value.chat.completions.create.call_count == 3
        assert "Page text." in result.text
        assert result.usage.prompt_tokens == 300  # 100 * 3
        assert result.usage.completion_tokens == 150  # 50 * 3

    def test_caches_pages(self, tmp_path, provider, mocker):
        """Should cache each page and skip on re-run."""
        mocker.patch("ingest.ocr.extract_pages_as_images", return_value=["img1"])

        mock_client_cls = mocker.patch("ingest.ocr.OpenAI")
        mock_response = Mock()
        mock_response.choices = [Mock(message=Mock(content="Cached page."))]
        mock_response.usage = Mock(prompt_tokens=100, completion_tokens=50)
        mock_client_cls.return_value.chat.completions.create.return_value = mock_response

        cache_dir = str(tmp_path / "ocr_cache")

        # First run — calls LLM
        result1 = ocr_pdf("test.pdf", provider, cache_dir=cache_dir)
        assert mock_client_cls.return_value.chat.completions.create.call_count == 1

        # Second run — loads from cache
        result2 = ocr_pdf("test.pdf", provider, cache_dir=cache_dir)
        assert mock_client_cls.return_value.chat.completions.create.call_count == 1  # no new calls
        assert result2.text == result1.text
