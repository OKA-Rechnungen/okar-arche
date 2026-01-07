#!/usr/bin/env python3
"""Generate metadata/to_ingest/update.rdf with linking triples.

Requested triples:
1) master x tif  acdh:isSourceOf  derivate x tif
2) masters collection y  acdh:isSourceOf  corresponding TEI y
3) TEI z  acdh:isObjectMetadataFor  masters z collection
   TEI z  acdh:isObjectMetadataFor  derivates z collection

To avoid guessing which resources exist, this script scans the already-generated
RDF/XML export (metadata_to_ingest/arche.rdf) and extracts URIs from rdf:about.

It does not attempt to fully parse RDF/XML; it streams the file line-by-line and
uses conservative regexes matching the project’s URI patterns.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Dict, Iterable, List, Set, Tuple

ACDH_NS = "https://vocabs.acdh.oeaw.ac.at/schema#"
RDF_NS = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

ABOUT_TIF_RE = re.compile(
    r'rdf:about="(?P<uri>https://id\.acdh\.oeaw\.ac\.at/okar/(?P<kind>masters|derivates)/(?P<vol>[^/\"]+)/(?P<file>[^\"]+\.tif))"'
)

ABOUT_COLLECTION_RE = re.compile(
    r'rdf:about="https://id\.acdh\.oeaw\.ac\.at/okar/(?P<kind>masters|derivates)/(?P<vol>WSTLA-OKA-B1-1-[0-9]+-1)"'
)

ABOUT_TEI_RE = re.compile(
    r'rdf:about="https://id\.acdh\.oeaw\.ac\.at/okar/(?P<vol>WSTLA-OKA-B1-1-[0-9]+-1)\.xml"'
)


def _iter_lines(path: Path) -> Iterable[str]:
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            yield line


def scan_uris(arche_rdf: Path) -> Tuple[
    Dict[Tuple[str, str], str],
    Dict[Tuple[str, str], str],
    Set[str],
    Set[str],
    Set[str],
]:
    """Return (masters_tifs, derivates_tifs, masters_cols, derivates_cols, teis).

    masters_tifs/derivates_tifs map (vol, filename) -> full URI.
    *_cols/teis are sets of volume ids.
    """

    masters_tifs: Dict[Tuple[str, str], str] = {}
    derivates_tifs: Dict[Tuple[str, str], str] = {}
    masters_cols: Set[str] = set()
    derivates_cols: Set[str] = set()
    teis: Set[str] = set()

    for line in _iter_lines(arche_rdf):
        m = ABOUT_TIF_RE.search(line)
        if m:
            kind = m.group("kind")
            vol = m.group("vol")
            filename = m.group("file")
            uri = m.group("uri")
            key = (vol, filename)
            if kind == "masters":
                masters_tifs[key] = uri
            else:
                derivates_tifs[key] = uri
            continue

        m = ABOUT_COLLECTION_RE.search(line)
        if m:
            kind = m.group("kind")
            vol = m.group("vol")
            if kind == "masters":
                masters_cols.add(vol)
            else:
                derivates_cols.add(vol)
            continue

        m = ABOUT_TEI_RE.search(line)
        if m:
            teis.add(m.group("vol"))

    return masters_tifs, derivates_tifs, masters_cols, derivates_cols, teis


def build_triples(
    masters_tifs: Dict[Tuple[str, str], str],
    derivates_tifs: Dict[Tuple[str, str], str],
    masters_cols: Set[str],
    derivates_cols: Set[str],
    teis: Set[str],
) -> Tuple[List[Tuple[str, str]], List[Tuple[str, str]], List[Tuple[str, str]]]:
    """Build predicate-object pairs grouped by subject category.

    Returns:
      - tif_links: list of (master_tif_uri, derivate_tif_uri)
      - col_to_tei: list of (masters_collection_uri, tei_uri)
      - tei_to_cols: list of (tei_uri, collection_uri)
    """

    tif_links: List[Tuple[str, str]] = []
    for key, master_uri in masters_tifs.items():
        der_uri = derivates_tifs.get(key)
        if der_uri:
            tif_links.append((master_uri, der_uri))

    col_to_tei: List[Tuple[str, str]] = []
    tei_to_cols: List[Tuple[str, str]] = []

    vols = sorted(set(teis) | set(masters_cols) | set(derivates_cols))
    for vol in vols:
        tei_uri = f"https://id.acdh.oeaw.ac.at/okar/{vol}.xml"
        masters_col_uri = f"https://id.acdh.oeaw.ac.at/okar/masters/{vol}"
        derivates_col_uri = f"https://id.acdh.oeaw.ac.at/okar/derivates/{vol}"

        if vol in masters_cols and vol in teis:
            col_to_tei.append((masters_col_uri, tei_uri))

        if vol in teis:
            if vol in masters_cols:
                tei_to_cols.append((tei_uri, masters_col_uri))
            if vol in derivates_cols:
                tei_to_cols.append((tei_uri, derivates_col_uri))

    # stable order
    tif_links.sort()
    col_to_tei.sort()
    tei_to_cols.sort()

    return tif_links, col_to_tei, tei_to_cols


def write_rdf(
    out_path: Path,
    tif_links: List[Tuple[str, str]],
    col_to_tei: List[Tuple[str, str]],
    tei_to_cols: List[Tuple[str, str]],
) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # Group predicates by subject for compact output
    source_of: Dict[str, List[str]] = {}
    for s, o in tif_links:
        source_of.setdefault(s, []).append(o)

    col_source_of: Dict[str, List[str]] = {}
    for s, o in col_to_tei:
        col_source_of.setdefault(s, []).append(o)

    obj_md_for: Dict[str, List[str]] = {}
    for s, o in tei_to_cols:
        obj_md_for.setdefault(s, []).append(o)

    for d in (source_of, col_source_of, obj_md_for):
        for k in d:
            d[k].sort()

    with out_path.open("w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write("<rdf:RDF\n" f'  xmlns:rdf="{RDF_NS}"\n' f'  xmlns:acdh="{ACDH_NS}">\n')

        def write_desc(subject: str, pred: str, objects: List[str]) -> None:
            f.write(f'  <rdf:Description rdf:about="{subject}">\n')
            for obj in objects:
                f.write(f'    <acdh:{pred} rdf:resource="{obj}"/>\n')
            f.write("  </rdf:Description>\n")

        # 1) master tif isSourceOf derivate tif
        for subject in sorted(source_of):
            write_desc(subject, "isSourceOf", source_of[subject])

        # 2) master collection isSourceOf tei
        for subject in sorted(col_source_of):
            write_desc(subject, "isSourceOf", col_source_of[subject])

        # 3) tei isObjectMetadataFor collections
        for subject in sorted(obj_md_for):
            write_desc(subject, "isObjectMetadataFor", obj_md_for[subject])

        f.write("</rdf:RDF>\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--input",
        default="metadata_to_ingest/arche.rdf",
        help="Path to arche.rdf (RDF/XML) to scan",
    )
    ap.add_argument(
        "--output",
        default="metadata_to_ingest/update.rdf",
        help="Path to update.rdf to write",
    )
    args = ap.parse_args()

    in_path = Path(args.input)
    out_path = Path(args.output)
    if not in_path.exists():
        raise SystemExit(f"Input not found: {in_path}")

    masters_tifs, derivates_tifs, masters_cols, derivates_cols, teis = scan_uris(
        in_path
    )
    tif_links, col_to_tei, tei_to_cols = build_triples(
        masters_tifs, derivates_tifs, masters_cols, derivates_cols, teis
    )

    write_rdf(out_path, tif_links, col_to_tei, tei_to_cols)

    print(
        "Wrote",
        str(out_path),
        "| tif_links:",
        len(tif_links),
        "| col_to_tei:",
        len(col_to_tei),
        "| tei_to_cols:",
        len(tei_to_cols),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
