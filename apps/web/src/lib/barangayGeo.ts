import { BARANGAY_BOUNDARIES } from "@/data/barangayBoundaries";

export type LatLng = { lat: number; lng: number };

// One barangay's renderable geometry: a list of polygons (a MultiPolygon
// barangay has several), each polygon a list of rings (outer + any holes),
// each ring a list of LatLng — the shape the @vis.gl Polygon `paths` wants.
export interface BarangayShape {
  barangay: string;
  polygons: LatLng[][][];
  center: LatLng;
}

const ringToLatLng = (ring: number[][]): LatLng[] =>
  ring.map(([lng, lat]) => ({ lat, lng }));

function centroidOf(polygons: LatLng[][][]): LatLng {
  // Simple average of the first polygon's outer-ring vertices — good enough to
  // recentre the camera on the barangay (not a true area centroid).
  const outer = polygons[0]?.[0] ?? [];
  if (outer.length === 0) return { lat: 0, lng: 0 };
  const sum = outer.reduce(
    (a, p) => ({ lat: a.lat + p.lat, lng: a.lng + p.lng }),
    { lat: 0, lng: 0 },
  );
  return { lat: sum.lat / outer.length, lng: sum.lng / outer.length };
}

// Memoise per municipality — MapView re-renders often and the conversion is
// pure, so cache the derived shapes the first time a town is opened.
const cache = new Map<string, BarangayShape[]>();

export function barangayShapesOf(municipality: string): BarangayShape[] {
  if (!municipality || municipality === "all") return [];
  const hit = cache.get(municipality);
  if (hit) return hit;

  const shapes: BarangayShape[] = BARANGAY_BOUNDARIES.features
    .filter((f) => f.properties.municipality === municipality)
    .map((f) => {
      const polygons: LatLng[][][] =
        f.geometry.type === "Polygon"
          ? [f.geometry.coordinates.map(ringToLatLng)]
          : f.geometry.coordinates.map((poly) => poly.map(ringToLatLng));
      return { barangay: f.properties.barangay, polygons, center: centroidOf(polygons) };
    });

  cache.set(municipality, shapes);
  return shapes;
}

export function barangayNamesOf(municipality: string): string[] {
  return barangayShapesOf(municipality)
    .map((s) => s.barangay)
    .filter(Boolean)
    .sort((a, b) => a.localeCompare(b));
}
