#!/usr/bin/env python3
"""Chunk ARCHE RDF/XML export into per-(sub)collection files.

Goal
----
Split a large RDF/XML file like `arche/html/arche.rdf` into:
- one file per *immediate* subcollection of:
  - https://id.acdh.oeaw.ac.at/okar/masters
  - https://id.acdh.oeaw.ac.at/okar/derivates
  including all resources whose `rdf:about` starts with that subcollection URI, and
- one additional file (`rest.rdf`) containing everything else.

This is implemented as a streaming XML parser so it works with very large files.

Usage
-----
python3 scripts/chunk_arche_rdf.py \
  --input data/rdf/arche.rdf \
  --output metadata_to_ingest/chunks

Notes
-----
- Chunk assignment is based on the `rdf:about` URI path. This matches the OKAR
  structure where each band lives under `/masters/<BAND_ID>/...` and
  `/derivates/<BAND_ID>/...`.
- Root collections themselves (`.../masters`, `.../derivates`) are written to `rest.rdf`.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Optional, Set, Tuple

RDF_NS = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
ACDH_NS = "https://vocabs.acdh.oeaw.ac.at/schema#"

ET.register_namespace("rdf", RDF_NS)
ET.register_namespace("acdh", ACDH_NS)

RDF_ABOUT = f"{{{RDF_NS}}}about"

MASTERS_ROOT = "https://id.acdh.oeaw.ac.at/okar/masters"
DERIVATES_ROOT = "https://id.acdh.oeaw.ac.at/okar/derivates"


def _safe_filename(name: str) -> str:
    # Keep it deterministic and filesystem-friendly.
    name = name.strip()
    name = re.sub(r"[^A-Za-z0-9._-]+", "_", name)
    name = re.sub(r"_+", "_", name)
    return name.strip("_") or "chunk"


def _chunk_key_from_about(about: str) -> Optional[Tuple[str, str]]:
    """Return (kind, sub_id) for masters/derivates items, else None.

    kind is one of: 'masters', 'derivates'
    sub_id is the immediate segment after the root.
    """

    for kind, root in (("masters", MASTERS_ROOT), ("derivates", DERIVATES_ROOT)):
        prefix = root.rstrip("/") + "/"
        if about.startswith(prefix):
            rest = about[len(prefix) :]
            sub_id = rest.split("/", 1)[0]
            if sub_id:
                return kind, sub_id
    return None


@dataclass
class RdfFileWriter:
    output_dir: Path
    created: Set[Path]

    def _ensure_header(self, path: Path) -> None:
        if path in self.created:
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("wb") as f:
            f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
            f.write(
                (f'<rdf:RDF xmlns:rdf="{RDF_NS}" xmlns:acdh="{ACDH_NS}">\n').encode(
                    "utf-8"
                )
            )
        self.created.add(path)

    def append_element(self, path: Path, elem: object, *, tostring) -> None:
        self._ensure_header(path)
        data = tostring(elem, encoding="utf-8")
        with path.open("ab") as f:
            f.write(data)
            f.write(b"\n")

    def finalize_all(self) -> None:
        for path in sorted(self.created):
            with path.open("ab") as f:
                f.write(b"</rdf:RDF>\n")


def chunk_rdf(input_path: Path, output_dir: Path) -> Dict[str, int]:
    """Chunk RDF/XML into output_dir. Returns simple stats."""

    if not input_path.exists():
        raise FileNotFoundError(str(input_path))

    writer = RdfFileWriter(output_dir=output_dir, created=set())

    rest_path = output_dir / "rest.rdf"

    # Keep minimal stats.
    counts: Dict[str, int] = {"rest": 0, "masters": 0, "derivates": 0, "total": 0}

    # Prefer lxml for huge files (safer streaming + parent access).
    try:
        from lxml import etree as LET  # type: ignore

        rdf_about = f"{{{RDF_NS}}}about"
        context = LET.iterparse(str(input_path), events=("end",), huge_tree=True)
        tostring = LET.tostring

        for _event, elem in context:
            about = elem.get(rdf_about)
            if not about:
                continue

            counts["total"] += 1

            chunk_key = _chunk_key_from_about(about)
            if chunk_key is None or about in (MASTERS_ROOT, DERIVATES_ROOT):
                writer.append_element(rest_path, elem, tostring=tostring)
                counts["rest"] += 1
            else:
                kind, sub_id = chunk_key
                filename = _safe_filename(sub_id) + ".rdf"
                path = output_dir / kind / filename
                writer.append_element(path, elem, tostring=tostring)
                counts[kind] += 1

            parent = elem.getparent()
            if parent is not None:
                parent.remove(elem)

    except Exception:
        # Fallback: standard library ElementTree. (Works for smaller files; may use more RAM.)
        context = ET.iterparse(str(input_path), events=("start", "end"))
        root: Optional[ET.Element] = None
        for event, elem in context:
            if root is None and event == "start":
                root = elem
                continue

            if event != "end":
                continue

            about = elem.get(RDF_ABOUT)
            if not about:
                continue

            counts["total"] += 1

            chunk_key = _chunk_key_from_about(about)
            if chunk_key is None or about in (MASTERS_ROOT, DERIVATES_ROOT):
                writer.append_element(rest_path, elem, tostring=ET.tostring)
                counts["rest"] += 1
            else:
                kind, sub_id = chunk_key
                filename = _safe_filename(sub_id) + ".rdf"
                path = output_dir / kind / filename
                writer.append_element(path, elem, tostring=ET.tostring)
                counts[kind] += 1

            if root is not None:
                try:
                    root.remove(elem)
                except ValueError:
                    pass
            elem.clear()

    writer.finalize_all()
    return counts


def main(argv: Optional[Iterable[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Chunk OKAR ARCHE RDF/XML export")
    parser.add_argument(
        "--input",
        default="data/rdf/arche.rdf",
        help="Input RDF/XML file (default: data/rdf/arche.rdf)",
    )
    parser.add_argument(
        "--output",
        default="metadata_to_ingest/chunks",
        help="Output directory (default: metadata_to_ingest/chunks)",
    )

    args = parser.parse_args(list(argv) if argv is not None else None)

    input_path = Path(args.input).resolve()
    output_dir = Path(args.output).resolve()

    stats = chunk_rdf(input_path=input_path, output_dir=output_dir)

    # Print a short summary for the terminal.
    print("Wrote chunks to:", output_dir)
    print("Elements:")
    print("  total     ", stats["total"])
    print("  masters   ", stats["masters"])
    print("  derivates ", stats["derivates"])
    print("  rest      ", stats["rest"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
