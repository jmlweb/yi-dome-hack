#!/usr/bin/env python3
"""Apply one binary patch record to a copy of its input file (ADR-0002).

Usage: patch-apply.py <record.json> <input-binary> <output-binary>

Writes nothing unless the input sha256 and the original bytes match the record,
and the result matches the record's output sha256. Never overwrites an output.
"""
import hashlib
import json
import pathlib
import sys


def fail(message):
    print(f"abort: {message}", file=sys.stderr)
    sys.exit(1)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def main(argv):
    if len(argv) != 4:
        fail("usage: patch-apply.py <record.json> <input-binary> <output-binary>")

    record = json.loads(pathlib.Path(argv[1]).read_text())
    input_path, output_path = pathlib.Path(argv[2]), pathlib.Path(argv[3])
    data = input_path.read_bytes()

    original = bytes.fromhex(record["original_hex"])
    replacement = bytes.fromhex(record["replacement_hex"])
    offset = int(record["file_offset"], 16)

    if len(original) != len(replacement):
        fail("record original and replacement differ in length")
    if sha256(data) != record["input_sha256"]:
        fail(f"input sha256 is not {record['input_sha256']}")
    if data[offset:offset + len(original)] != original:
        fail(f"original bytes differ at {record['file_offset']}")

    patched = data[:offset] + replacement + data[offset + len(replacement):]
    if sha256(patched) != record["output_sha256"]:
        fail("patched output sha256 does not match the record")
    if output_path.exists():
        fail(f"output exists, refusing to overwrite: {output_path}")

    output_path.write_bytes(patched)
    print(f"patched {record['id']} at {record['file_offset']}")
    print(f"output sha256 {record['output_sha256']}")


if __name__ == "__main__":
    main(sys.argv)
