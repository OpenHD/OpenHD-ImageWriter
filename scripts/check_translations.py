"""Check that every shipped Qt catalog covers the English sources safely."""
from collections import Counter
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET


def messages(path):
    tree = ET.parse(path)
    return {(context.findtext("name"), message.findtext("source"), message.findtext("comment") or ""): message
            for context in tree.findall("context") for message in context.findall("message")
            if message.find("translation").get("type") not in {"obsolete", "vanished"}}


def main():
    directory = Path(__file__).resolve().parents[1] / "src/i18n"
    expected = messages(directory / "rpi-imager_en.ts")
    failures = []
    for path in sorted(directory.glob("rpi-imager_*.ts")):
        catalog = messages(path)
        errors = []
        if set(catalog) != set(expected):
            errors.append(f"source coverage differs: {len(set(expected) - set(catalog))} missing, {len(set(catalog) - set(expected))} extra")
        for (_, source, _), message in catalog.items():
            translation = message.find("translation")
            target = translation.text or ""
            if translation.get("type") == "unfinished" or (source.strip() and not target.strip()):
                errors.append(f"unfinished: {source!r}")
            if any(marker in target for marker in ["\u2047", "\u2581", "\ufffd"]):
                errors.append(f"tokenizer artifact: {source!r}")
            if len(target) > max(100, len(source) * 4) or re.search(r"\b(\w+)(?:\s+\1){3,}\b", target, re.IGNORECASE):
                errors.append(f"suspiciously long or repetitive: {source!r}")
            for label, pattern in [("placeholders", r"%\d+|%n"), ("markup", r"<[^>]+>"), ("file filters", r"\*\.[a-z]+|\(\*\)"), ("filenames", r"(?<![A-Za-z0-9_-])[A-Za-z0-9_-]+\.(?:txt|json|conf|zip|exe|ohdcert|img)(?![A-Za-z0-9_])")]:
                if Counter(re.findall(pattern, source)) != Counter(re.findall(pattern, target)):
                    errors.append(f"changed {label}: {source!r}")
        print(f"{path.stem}: {len(catalog)} messages, {len(errors)} errors")
        failures.extend(f"{path.stem}: {error}" for error in errors)
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
