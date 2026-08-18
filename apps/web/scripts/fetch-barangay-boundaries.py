#!/usr/bin/env python3
"""Regenerate apps/web/src/data/barangayBoundaries.ts (N9).

Pulls barangay boundary polygons for all 15 Nueva Vizcaya municipalities from
faeldon/philippines-json-maps (2023 PSGC edition, lowres / 0.1% simplification),
strips them to {barangay, municipality} + coordinates rounded to 5 decimals
(~1 m) so the bundled dataset stays small (~66 KB for 266 barangays).

Usage:  python3 apps/web/scripts/fetch-barangay-boundaries.py
"""
import json, os, urllib.request

BASE = ("https://raw.githubusercontent.com/faeldon/philippines-json-maps/master/"
        "2023/geojson/municities/lowres/bgysubmuns-municity-{}.0.001.json")

# adm3 PSGC code -> the web app's canonical municipality name (see
# apps/web/src/data/municipalities.ts). Nueva Vizcaya province = 205000000.
CODES = {
    "205001000": "Ambaguio", "205002000": "Aritao", "205003000": "Bagabag",
    "205004000": "Bambang", "205005000": "Bayombong", "205006000": "Diadi",
    "205007000": "Dupax del Norte", "205008000": "Dupax del Sur", "205009000": "Kasibu",
    "205010000": "Kayapa", "205011000": "Quezon", "205012000": "Santa Fe",
    "205013000": "Solano", "205014000": "Villaverde", "205015000": "Alfonso Castaneda",
}

OUT = os.path.join(os.path.dirname(__file__), "..", "src", "data", "barangayBoundaries.ts")


def rnd(x):
    return round(x, 5)


def round_coords(coords):
    if coords and isinstance(coords[0], (int, float)):
        return [rnd(coords[0]), rnd(coords[1])]
    return [round_coords(c) for c in coords]


def main():
    features, total, skipped = [], 0, 0
    for code, name in CODES.items():
        with urllib.request.urlopen(BASE.format(code), timeout=60) as r:
            data = json.loads(r.read())
        for f in data["features"]:
            g = f.get("geometry")
            if not g or not g.get("coordinates"):
                skipped += 1
                continue
            features.append({
                "type": "Feature",
                "properties": {"barangay": f["properties"].get("adm4_en", ""), "municipality": name},
                "geometry": {"type": g["type"], "coordinates": round_coords(g["coordinates"])},
            })
            total += 1

    fc = {"type": "FeatureCollection", "features": features}
    header = (
        "// Barangay boundary polygons for all 15 Nueva Vizcaya municipalities (N9).\n"
        "// Source: faeldon/philippines-json-maps (2023 PSGC, lowres / 0.1% simplification),\n"
        "// stripped to {barangay, municipality} with coordinates rounded to 5 decimals\n"
        "// (~1 m) to keep the bundle small. Regenerate: apps/web/scripts/fetch-barangay-boundaries.py\n"
        "export type BarangayGeometry =\n"
        "  | { type: \"Polygon\"; coordinates: number[][][] }\n"
        "  | { type: \"MultiPolygon\"; coordinates: number[][][][] };\n\n"
        "export interface BarangayFeature {\n"
        "  type: \"Feature\";\n"
        "  properties: { barangay: string; municipality: string };\n"
        "  geometry: BarangayGeometry;\n"
        "}\n\n"
        "export interface BarangayBoundaryCollection {\n"
        "  type: \"FeatureCollection\";\n"
        "  features: BarangayFeature[];\n"
        "}\n\n"
        "export const BARANGAY_BOUNDARIES: BarangayBoundaryCollection = "
    )
    with open(OUT, "w") as fh:
        fh.write(header)
        json.dump(fc, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write(";\n")
    print(f"wrote {total} barangays ({skipped} null-geometry skipped) -> {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
