#!/usr/bin/env python3
import os
import xml.etree.ElementTree as ET
from collections import defaultdict

INPUT_RDF = os.path.join(os.path.dirname(__file__), "../metadata_to_ingest/update.rdf")
OUTPUT_DIR = os.path.join(
    os.path.dirname(__file__), "../metadata_to_ingest/chunks/updates"
)
os.makedirs(OUTPUT_DIR, exist_ok=True)

NAMESPACES = {
    "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    "acdh": "https://vocabs.acdh.oeaw.ac.at/schema#",
}
ET.register_namespace("rdf", NAMESPACES["rdf"])
ET.register_namespace("acdh", NAMESPACES["acdh"])


def extract_band(uri):
    """Extract band identifier from a master/derivate URI."""
    parts = uri.split("/")
    for i, part in enumerate(parts):
        if part in ("masters", "derivates") and i + 1 < len(parts):
            return parts[i + 1]
    return None


def main():
    tree = ET.parse(INPUT_RDF)
    root = tree.getroot()

    # Group descriptions by band
    band_descriptions = defaultdict(list)
    for desc in root.findall("rdf:Description", NAMESPACES):
        about = desc.attrib.get(f'{{{NAMESPACES["rdf"]}}}about')
        band = extract_band(about)
        if band:
            band_descriptions[band].append(desc)

    for band, descriptions in band_descriptions.items():
        band_root = ET.Element("rdf:RDF", root.attrib)
        for desc in descriptions:
            band_root.append(desc)
        out_path = os.path.join(OUTPUT_DIR, f"{band}.rdf")
        band_tree = ET.ElementTree(band_root)
        band_tree.write(out_path, encoding="utf-8", xml_declaration=True)
        print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
