import json
import sys

import pymupdf
import pymupdf4llm


def read_request():
    line = sys.stdin.readline()
    if not line:
        raise RuntimeError("missing request payload")

    payload = json.loads(line)
    return {
        "file_path": payload["file_path"],
        "ocr_fallback": bool(payload.get("ocr_fallback", False)),
    }


def extract_document(file_path, ocr_fallback):
    text = pymupdf4llm.to_markdown(file_path)

    with pymupdf.open(file_path) as document:
        page_count = getattr(document, "page_count", 0)
        metadata = getattr(document, "metadata", {}) or {}

        if ocr_fallback and len(text.strip()) < 100:
            text = "\n\n".join(page.get_text() for page in document)

    return {"text": text, "page_count": page_count, "metadata": metadata, "error": None}


def main():
    try:
        request = read_request()
        response = extract_document(request["file_path"], request["ocr_fallback"])
        print(json.dumps(response))
        return 0
    except Exception as exc:
        print(
            json.dumps(
                {
                    "text": None,
                    "page_count": 0,
                    "metadata": {},
                    "error": str(exc),
                }
            )
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
