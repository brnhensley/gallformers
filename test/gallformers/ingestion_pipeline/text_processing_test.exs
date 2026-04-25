defmodule Gallformers.IngestionPipeline.TextProcessingTest do
  use ExUnit.Case, async: true

  alias Gallformers.IngestionPipeline.TextProcessing

  describe "strip_bhl_boilerplate/1" do
    test "removes the BHL header block" do
      text = """
      https://www.biodiversitylibrary.org/

      Holding Institution: Missouri Botanical Garden
      Sponsored by: Missouri Botanical Garden

      Generated 3 March 2026 6:28 PM
      This page intentionally left blank.

      A biological and systematic study
      """

      result = TextProcessing.strip_bhl_boilerplate(text)

      refute result =~ "biodiversitylibrary.org"
      refute result =~ "Holding Institution"
      assert result =~ "A biological and systematic study"
    end
  end

  describe "rejoin_lines/1" do
    test "rejoins OCR continuation blocks while preserving paragraphs" do
      text = """
      Galls are abnormal growths on the stems, leaves, roots, or

      other parts of plants, caused by the action of insects.

      New paragraph.
      """

      result = TextProcessing.rejoin_lines(text)

      assert result =~ "roots, or other parts"
      assert result =~ "\n\nNew paragraph."
    end

    test "preserves headings" do
      assert TextProcessing.rejoin_lines("# INTRODUCTION\n\nSome text here.") ==
               "# INTRODUCTION\n\nSome text here."
    end
  end

  describe "rejoin_hyphenated/1" do
    test "rejoins words hyphenated across line breaks" do
      assert TextProcessing.rejoin_hyphenated("This is an ex-\nplanation.") ==
               "This is an explanation."
    end
  end

  describe "strip_page_headers/1" do
    test "removes journal headers and standalone page numbers" do
      text = """
      end of previous text.

      528 Philippine Journal of Science
      1919

      527

      Start of next text.
      """

      result = TextProcessing.strip_page_headers(text)

      refute result =~ "Philippine Journal of Science"
      refute result =~ "\n527\n"
      assert result =~ "Start of next text."
    end
  end

  describe "strip_plate_pages/1" do
    test "removes plate image pages but preserves descriptions" do
      text = """
      Real content here.

      ILLUSTRATIONS

      PLATE I

      Description of plate one figures.

      PLATE I. PLANT GALLS.

      UICHANCO: PHILIPPINE PLANT GALLS. ] [PHILIP. JouRN. Sct., XIV, No. 5.

      |

      Hq
      """

      result = TextProcessing.strip_plate_pages(text)

      assert result =~ "Real content here."
      assert result =~ "Description of plate one figures."
      refute result =~ "PLATE I. PLANT GALLS."
      refute result =~ "UICHANCO: PHILIPPINE PLANT GALLS"
      refute result =~ "Hq"
    end
  end

  describe "preprocess/1" do
    test "runs the full preprocessing pipeline in order" do
      text = """
      https://www.biodiversitylibrary.org/

      Holding Institution: Some Library
      This page intentionally left blank.

      A biological study

      Galls are abnormal growths on the stems, leaves, roots, or

      other parts of plants, caused by the action of in-
      sects.

      528 Philippine Journal of Science
      1919

      PLATE I. PLANT GALLS.

      OCR junk |
      """

      result = TextProcessing.preprocess(text)

      refute result =~ "biodiversitylibrary"
      refute result =~ "Philippine Journal of Science"
      refute result =~ "PLATE I. PLANT GALLS."
      assert result =~ "A biological study"
      assert result =~ "insects"
    end
  end

  describe "cheap_sniff/1" do
    test "extracts doi, title, authors, and year from the preprocessed text" do
      text = """
      A biological and systematic study of Philippine galls
      Smith, J.A.
      1919
      DOI 10.1234/Example.

      Body text starts here.
      """

      assert %{
               doi: "10.1234/example",
               title: "A biological and systematic study of Philippine galls",
               authors: ["Smith, J.A."],
               year: 1919
             } = TextProcessing.cheap_sniff(text)
    end
  end

  describe "compute_sha256/1" do
    test "returns a 64-character lowercase hex digest" do
      digest = TextProcessing.compute_sha256("hello")

      assert digest == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
      assert String.length(digest) == 64
    end
  end
end
