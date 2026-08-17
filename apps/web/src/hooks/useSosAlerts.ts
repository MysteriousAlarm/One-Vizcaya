import { useEffect, useState } from "react";
import {
  collection, query, where, orderBy, limit, onSnapshot,
  doc, updateDoc, Timestamp,
} from "firebase/firestore";
import { db, auth } from "@/lib/firebase";
import { useAuthStore } from "@/stores/authStore";
import type { SosAlert, SosStatus } from "@/types";

const OPEN: SosStatus[] = ["active", "dispatched"];

function toAlert(id: string, d: Record<string, unknown>): SosAlert {
  const ts = (v: unknown) => (v instanceof Timestamp ? v.toDate() : undefined);
  const num = (v: unknown) => (typeof v === "number" ? v : undefined);
  return {
    id,
    uid: (d.uid as string) ?? "",
    name: (d.name as string) ?? "Unknown",
    phone: (d.phone as string) ?? "",
    municipality: (d.municipality as string) ?? "",
    barangay: (d.barangay as string) || undefined,
    lat: num(d.lat),
    lng: num(d.lng),
    accuracy: num(d.accuracy),
    status: (d.status as SosStatus) ?? "active",
    note: d.note as string | undefined,
    tracking: (d.tracking as boolean) ?? false,
    createdAt: ts(d.createdAt),
    updatedAt: ts(d.updatedAt),
  };
}

// Live OPEN emergencies, scoped to the acting admin's tier exactly like reports:
// province-wide for provincial+, their town for a municipal admin, their
// barangay for a barangay admin (the rules require the matching query filters).
export function useSosAlerts() {
  const [alerts, setAlerts] = useState<SosAlert[]>([]);
  const [loading, setLoading] = useState(true);
  const user = useAuthStore((s) => s.user);
  const municipality = useAuthStore((s) => s.getEffectiveMunicipality());
  const barangay = user?.role === "barangay_admin" ? (user.barangay ?? "") : null;

  useEffect(() => {
    const base = collection(db, "sos_alerts");
    const q =
      barangay !== null && municipality
        ? query(base,
            where("municipality", "==", municipality),
            where("barangay", "==", barangay),
            where("status", "in", OPEN),
            orderBy("createdAt", "desc"), limit(100))
        : municipality
          ? query(base,
              where("municipality", "==", municipality),
              where("status", "in", OPEN),
              orderBy("createdAt", "desc"), limit(100))
          : query(base,
              where("status", "in", OPEN),
              orderBy("createdAt", "desc"), limit(100));

    const unsub = onSnapshot(
      q,
      (snap) => { setAlerts(snap.docs.map((s) => toAlert(s.id, s.data()))); setLoading(false); },
      (err)  => { console.error("SOS listener:", err); setLoading(false); },
    );
    return unsub;
  }, [municipality, barangay]);

  return { alerts, loading };
}

export async function setSosStatus(id: string, status: Extract<SosStatus, "dispatched" | "resolved">) {
  const uid = auth.currentUser?.uid ?? null;
  await updateDoc(doc(db, "sos_alerts", id), {
    status,
    ...(status === "dispatched" ? { dispatchedBy: uid, dispatchedAt: Timestamp.now() } : {}),
    ...(status === "resolved" ? { resolvedBy: uid, resolvedAt: Timestamp.now(), tracking: false } : {}),
    updatedAt: Timestamp.now(),
  });
}
