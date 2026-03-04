"""Tests for the text pre-processing pipeline."""

from ingest.preprocess import preprocess, strip_bhl_boilerplate, rejoin_lines, rejoin_hyphenated, strip_page_headers, strip_plate_pages


class TestStripBHLBoilerplate:
    def test_removes_bhl_header(self):
        text = (
            "[https://www.biodiversitylibrary.org/](https://www.biodiversitylibrary.org/)\n\n"
            "# **The Philippine journal of science**\n\n"
            "Manila Bureau of Science\n"
            "[https://www.biodiversitylibrary.org/bibliography/50545](...)\n\n"
            "v.14 (1919): https://www.biodiversitylibrary.org/item/1124\n\n"
            "Page(s): Page 527, Page 528\n\n"
            "Holding Institution: Missouri Botanical Garden\n"
            "Sponsored by: Missouri Botanical Garden\n\n"
            "Generated 3 March 2026 6:28 PM\n"
            "[https://www.biodiversitylibrary.org/pdf4/...](https://...)\n\n"
            "This page intentionally left blank.\n\n"
            "A BIOLOGICAL AND SYSTEMATIC STUDY\n"
        )
        result = strip_bhl_boilerplate(text)
        assert "biodiversitylibrary.org" not in result
        assert "Holding Institution" not in result
        assert "intentionally left blank" not in result
        assert "BIOLOGICAL AND SYSTEMATIC STUDY" in result

    def test_preserves_non_bhl_text(self):
        text = "Just a normal document.\n\nWith some content."
        assert strip_bhl_boilerplate(text) == text


class TestRejoinLines:
    def test_rejoins_single_newlines(self):
        text = "This is a sentence that\ncontinues on the next line.\n\nNew paragraph here."
        result = rejoin_lines(text)
        assert "sentence that continues" in result
        assert "\n\n" in result  # paragraph break preserved

    def test_preserves_paragraph_breaks(self):
        text = "Paragraph one.\n\nParagraph two."
        result = rejoin_lines(text)
        assert result == "Paragraph one.\n\nParagraph two."

    def test_preserves_headings(self):
        text = "# INTRODUCTION\n\nSome text here."
        result = rejoin_lines(text)
        assert "# INTRODUCTION" in result

    def test_handles_blank_line_separated_ocr(self):
        """BHL-style: every line has a blank line after it."""
        text = "Galls are abnormal growths on the stems, leaves, roots, or\n\nother parts of plants, caused by the action of insects, arachnids, or\n\nfungi, by unknown agencies."
        result = rejoin_lines(text)
        # These should be joined since they're continuation lines
        assert "roots, or other parts" in result


class TestRejoinHyphenated:
    def test_rejoins_hyphenated_words(self):
        text = "This is a long ex-\nplanation of something."
        result = rejoin_hyphenated(text)
        assert "explanation" in result

    def test_rejoins_across_blank_lines(self):
        text = "a zodce-\n\ncidia may be"
        result = rejoin_hyphenated(text)
        assert "zodcecidia" in result

    def test_preserves_real_hyphens(self):
        text = "a well-known fact"
        result = rejoin_hyphenated(text)
        assert "well-known" in result


class TestStripPageHeaders:
    def test_removes_journal_page_headers(self):
        text = "end of previous text.\n\n528 Philippine Journal of Science\n1919\n\nStart of next text."
        result = strip_page_headers(text)
        assert "Philippine Journal of Science" not in result
        assert "end of previous text" in result
        assert "Start of next text" in result

    def test_removes_page_numbers(self):
        text = "some text.\n\n527\n\nmore text."
        result = strip_page_headers(text)
        assert result.strip() == "some text.\n\nmore text."


class TestStripPlatPages:
    def test_removes_plate_image_pages(self):
        text = (
            "Real content here.\n\n"
            "ILLUSTRATIONS\n\n"
            "PLATE I\n\n"
            "Description of plate one figures.\n\n"
            "PLATE I. PLANT GALLS.\n\n"
            "UICHANCO: PHILIPPINE PLANT GALLS. ] [PHILIP. JouRN. Sct., XIV, No. 5.\n\n"
            "|\n\nO\n\nHq\n\n"
            "PLATE II. PLANT GALLS.\n\n"
            "random OCR junk\n\n"
        )
        result = strip_plate_pages(text)
        assert "Real content here" in result
        assert "ILLUSTRATIONS" in result
        assert "Description of plate one figures" in result
        # Plate image pages should be gone
        assert "PLATE I. PLANT GALLS." not in result
        assert "UICHANCO: PHILIPPINE PLANT GALLS" not in result
        assert "Hq" not in result

    def test_preserves_plate_references_in_body(self):
        text = "The gall shown in Plate VI, fig. 8. Cross section."
        result = strip_plate_pages(text)
        assert "Plate VI" in result


class TestPreprocess:
    def test_full_pipeline(self):
        text = (
            "[https://www.biodiversitylibrary.org/](https://www.biodiversitylibrary.org/)\n\n"
            "Holding Institution: Some Library\n"
            "Sponsored by: Some Sponsor\n\n"
            "This page intentionally left blank.\n\n"
            "A BIOLOGICAL STUDY\n\n"
            "Galls are abnormal growths on the stems, leaves, roots, or\n\n"
            "other parts of plants, caused by the action of in-\nsects.\n\n"
            "528 Philippine Journal of Science\n1919\n\n"
            "More real content here.\n\n"
            "PLATE I. PLANT GALLS.\n\n"
            "OCR junk |\n\n"
        )
        result = preprocess(text)
        assert "biodiversitylibrary" not in result
        assert "intentionally left blank" not in result
        assert "BIOLOGICAL STUDY" in result
        assert "Philippine Journal of Science" not in result
        assert "PLATE I. PLANT GALLS." not in result
        # Content should be rejoined
        assert "insects" in result
