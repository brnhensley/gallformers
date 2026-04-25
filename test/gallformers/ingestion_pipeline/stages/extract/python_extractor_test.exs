defmodule Gallformers.IngestionPipeline.Stages.Extract.PythonExtractorTest do
  use ExUnit.Case, async: false

  alias Gallformers.IngestionPipeline.Stages.Extract.PythonExtractor

  setup do
    previous_config = Application.get_env(:gallformers, PythonExtractor)

    on_exit(fn ->
      if previous_config == nil do
        Application.delete_env(:gallformers, PythonExtractor)
      else
        Application.put_env(:gallformers, PythonExtractor, previous_config)
      end
    end)

    :ok
  end

  describe "extract_text/2" do
    test "spawns the extractor through uv and returns extracted text for a sample pdf fixture" do
      tmp_dir = tmp_dir!()
      pdf_path = write_sample_pdf(tmp_dir, "sample.pdf")
      fake_modules_dir = write_fake_python_modules(tmp_dir)
      fake_uv = write_python_uv_wrapper(tmp_dir, fake_modules_dir)

      put_config(uv_executable: fake_uv)

      assert {:ok, result} = PythonExtractor.extract_text(pdf_path)
      assert result.text == "markdown::sample.pdf"
      assert result.page_count == 2
      assert result.metadata == %{"title" => "Fixture PDF"}
    end

    test "uses a configured python executable when available" do
      tmp_dir = tmp_dir!()
      pdf_path = write_sample_pdf(tmp_dir, "sample.pdf")
      fake_modules_dir = write_fake_python_modules(tmp_dir)
      fake_python = write_python_wrapper(tmp_dir)

      put_config(python_executable: fake_python, python_path: fake_modules_dir)

      assert {:ok, result} = PythonExtractor.extract_text(pdf_path)
      assert result.text == "markdown::sample.pdf"
      assert result.page_count == 2
      assert result.metadata == %{"title" => "Fixture PDF"}
    end

    test "returns extraction_failed on timeout and closes the port" do
      tmp_dir = tmp_dir!()
      fake_uv = write_sleeping_uv(tmp_dir)

      put_config(uv_executable: fake_uv, timeout_ms: 25)

      assert {:error, :extraction_failed, :timeout} =
               PythonExtractor.extract_text("/tmp/never-used.pdf")
    end

    test "returns extraction_failed when the Python process exits non-zero" do
      tmp_dir = tmp_dir!()
      fake_uv = write_static_uv(tmp_dir, ~s({"error":"boom"}\n), 1)

      put_config(uv_executable: fake_uv)

      assert {:error, :extraction_failed, %{exit_status: 1, output: output}} =
               PythonExtractor.extract_text("/tmp/error.pdf")

      assert output =~ ~s({"error":"boom"})
    end

    test "uses OCR fallback when markdown extraction is too short" do
      tmp_dir = tmp_dir!()
      pdf_path = write_sample_pdf(tmp_dir, "short.pdf")
      fake_modules_dir = write_fake_python_modules(tmp_dir)
      fake_uv = write_python_uv_wrapper(tmp_dir, fake_modules_dir)

      put_config(uv_executable: fake_uv)

      assert {:ok, result} = PythonExtractor.extract_text(pdf_path, ocr_fallback: true)
      assert result.text == "ocr page 1\n\nocr page 2"
      assert result.page_count == 2
    end

    test "returns invalid_response when Python prints unparseable JSON" do
      tmp_dir = tmp_dir!()
      fake_uv = write_static_uv(tmp_dir, "not-json\n", 0)

      put_config(uv_executable: fake_uv)

      assert {:error, :invalid_response, "not-json\n"} =
               PythonExtractor.extract_text("/tmp/invalid.pdf")
    end
  end

  defp tmp_dir! do
    dir =
      Path.join(System.tmp_dir!(), "python_extractor_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    dir
  end

  defp write_sample_pdf(tmp_dir, filename) do
    path = Path.join(tmp_dir, filename)
    File.write!(path, "%PDF-1.4\n% fixture pdf\n")
    path
  end

  defp write_fake_python_modules(tmp_dir) do
    modules_dir = Path.join(tmp_dir, "modules")
    File.mkdir_p!(modules_dir)

    File.write!(Path.join(modules_dir, "pymupdf4llm.py"), fake_pymupdf4llm_module())
    File.write!(Path.join(modules_dir, "pymupdf.py"), fake_pymupdf_module())

    modules_dir
  end

  defp write_python_uv_wrapper(tmp_dir, fake_modules_dir) do
    python_executable = system_python_executable!()
    path = Path.join(tmp_dir, "uv")

    File.write!(
      path,
      """
      #!/bin/sh
      export PYTHONPATH="#{fake_modules_dir}${PYTHONPATH:+:$PYTHONPATH}"
      exec "#{python_executable}" pdf_text_extractor.py
      """
    )

    File.chmod!(path, 0o755)
    path
  end

  defp write_python_wrapper(tmp_dir) do
    python_executable = system_python_executable!()
    path = Path.join(tmp_dir, "python-wrapper")

    File.write!(
      path,
      """
      #!/bin/sh
      exec "#{python_executable}" "$@"
      """
    )

    File.chmod!(path, 0o755)
    path
  end

  defp write_sleeping_uv(tmp_dir) do
    path = Path.join(tmp_dir, "uv")

    File.write!(
      path,
      """
      #!/bin/sh
      sleep 5
      """
    )

    File.chmod!(path, 0o755)
    path
  end

  defp write_static_uv(tmp_dir, output, exit_code) do
    path = Path.join(tmp_dir, "uv")
    output_path = Path.join(tmp_dir, "output.txt")
    File.write!(output_path, output)

    File.write!(
      path,
      """
      #!/bin/sh
      cat "#{output_path}"
      exit #{exit_code}
      """
    )

    File.chmod!(path, 0o755)
    path
  end

  defp fake_pymupdf4llm_module do
    """
    from pathlib import Path


    def to_markdown(file_path):
        if Path(file_path).name == "short.pdf":
            return "tiny"

        return f"markdown::{Path(file_path).name}"
    """
  end

  defp fake_pymupdf_module do
    """
    from pathlib import Path


    class FakePage:
        def __init__(self, text):
            self._text = text

        def get_text(self):
            return self._text


    class FakeDocument:
        def __init__(self, file_path):
            self.page_count = 2
            self.metadata = {"title": "Fixture PDF"}
            name = Path(file_path).name

            if name == "short.pdf":
                self._pages = [FakePage("ocr page 1"), FakePage("ocr page 2")]
            else:
                self._pages = [FakePage("page 1"), FakePage("page 2")]

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def __iter__(self):
            return iter(self._pages)


    def open(file_path):
        return FakeDocument(file_path)
    """
  end

  defp system_python_executable! do
    System.find_executable("python3") ||
      System.find_executable("python") ||
      raise "python executable not found for PythonExtractor test"
  end

  defp put_config(opts) do
    Application.put_env(:gallformers, PythonExtractor, opts)
  end
end
