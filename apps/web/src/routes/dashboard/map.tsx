import { lazy, Suspense, useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { Map as MapIcon, Mountain, Loader2 } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { MapView } from "@/components/map/MapView";
// Lazy-loaded so the heavy MapLibre bundle only downloads when 3D is opened.
const Map3DView = lazy(() =>
  import("@/components/map/Map3DView").then((m) => ({ default: m.Map3DView })),
);
import { useReports } from "@/hooks/useReports";
import { useResponders } from "@/hooks/useResponders";
import { useAuthStore } from "@/stores/authStore";

export const Route = createFileRoute("/dashboard/map")({
  component: MapPage,
});

function MapPage() {
  const { getEffectiveMunicipality, user } = useAuthStore();
  const municipality = getEffectiveMunicipality();
  const { reports } = useReports(municipality);
  const { responders } = useResponders();
  const [view3D, setView3D] = useState(false);

  return (
    <div className="p-3 sm:p-5 lg:p-6 space-y-5 max-w-[1600px] mx-auto">
      <div className="flex items-start justify-between gap-4 pb-3 border-b">
        <div>
          <div className="flex items-center gap-2 mb-0.5">
            <div className="h-1 w-4 rounded bg-[hsl(var(--gov-green-800))]" />
            <h1 className="text-lg font-bold tracking-tight">Interactive Map</h1>
          </div>
          <p className="text-xs text-muted-foreground">
            {municipality ? `Municipality of ${municipality}` : "Province of Nueva Vizcaya"} · Report heatmap & responder locations
          </p>
        </div>
        <div className="flex items-center gap-3 shrink-0">
          {/* 2D / 3D view switch */}
          <div className="flex rounded-lg border overflow-hidden" role="group" aria-label="Map view mode">
            <Button
              variant="ghost" size="sm"
              className={cn("h-8 rounded-none gap-1.5 px-2.5 text-xs", !view3D && "bg-[hsl(var(--gov-green-800))] text-white hover:bg-[hsl(var(--gov-green-800))] hover:text-white")}
              onClick={() => setView3D(false)} aria-pressed={!view3D}
            >
              <MapIcon className="h-3.5 w-3.5" /> 2D
            </Button>
            <Button
              variant="ghost" size="sm"
              className={cn("h-8 rounded-none gap-1.5 px-2.5 text-xs", view3D && "bg-[hsl(var(--gov-green-800))] text-white hover:bg-[hsl(var(--gov-green-800))] hover:text-white")}
              onClick={() => setView3D(true)} aria-pressed={view3D}
            >
              <Mountain className="h-3.5 w-3.5" /> 3D
            </Button>
          </div>
          <div className="text-right hidden sm:block">
            <p className="text-xs font-semibold text-foreground">{user?.name}</p>
            <p className="text-[10px] text-muted-foreground">{new Date().toLocaleDateString("en-PH", { weekday: "short", year: "numeric", month: "short", day: "numeric" })}</p>
          </div>
        </div>
      </div>

      <Card>
        <CardContent className="pt-5">
          {view3D ? (
            <Suspense
              fallback={
                <div className="flex items-center justify-center" style={{ height: "clamp(340px, 55vw, 560px)" }}>
                  <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                </div>
              }
            >
              <Map3DView reports={reports} responders={responders} />
            </Suspense>
          ) : (
            <MapView reports={reports} responders={responders} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
