import { useEffect, useState } from "react";
import {
  collectionGroup, query, orderBy, limit, where,
  onSnapshot, doc, updateDoc, Timestamp, arrayUnion, deleteDoc,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuthStore } from "@/stores/authStore";
import type { Report, ReportNote, ReportStatus, HandlingLevel } from "@/types";

function toDate(val: unknown): Date {
  if (val instanceof Timestamp) return val.toDate();
  if (typeof val === "number") return new Date(val);
  if (typeof val === "string") return new Date(val);
  if (val instanceof Date) return val;
  return new Date();
}

function toReport(d: {
  id: string;
  data: () => Record<string, unknown>;
  ref: { parent: { parent: { id: string } | null } | null };
}): Report {
  const data = d.data();
  return {
    id: d.id,
    userId: d.ref?.parent?.parent?.id ?? (data.userId as string) ?? "",
    category:         (data.category as string)   ?? "Other",
    priority:         (data.priority as Report["priority"]) ?? "low",
    status:           (data.status   as Report["status"])   ?? "reported",
    municipality:     (data.municipality as string) ?? "",
    barangay:          data.barangay as string | undefined,
    location:         (data.location as string) ?? "",
    latitude:         typeof data.latitude  === "number" ? data.latitude  : undefined,
    longitude:        typeof data.longitude === "number" ? data.longitude : undefined,
    description:      (data.description as string) ?? "",
    isAnonymous:      (data.isAnonymous as boolean) ?? false,
    reportedAt:        toDate(data.reportedAt),
    resolvedAt:        data.resolvedAt ? toDate(data.resolvedAt) : undefined,
    notes: ((data.notes as ReportNote[]) ?? []).map((n) => ({
      ...n,
      timestamp: toDate(n.timestamp),
    })),
    assignedResponder: data.assignedResponder as string | undefined,
    satisfactionRating:data.satisfactionRating as number | undefined,
    imageUrl:          data.imageUrl as string | undefined,
    photoSource:       data.photoSource as Report["photoSource"],
    photoLatitude:     typeof data.photoLatitude  === "number" ? data.photoLatitude  : undefined,
    photoLongitude:    typeof data.photoLongitude === "number" ? data.photoLongitude : undefined,
    photoTimestamp:    data.photoTimestamp ? toDate(data.photoTimestamp) : undefined,
    lastModified:      toDate(data.lastModified),
    handlingLevel:     (data.handlingLevel as HandlingLevel) ?? "municipal",
    escalatedToProvince: (data.escalatedToProvince as boolean) ?? false,
  };
}

export function useReports(municipality: string | null) {
  const [reports, setReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const user = useAuthStore((s) => s.user);
  // A Barangay admin is confined to their own barangay: the security rules only
  // authorise a report read when the query also filters by their barangay, so
  // add that constraint (otherwise the whole collectionGroup read is denied).
  const scopedBarangay =
    user?.role === "barangay_admin" ? (user.barangay ?? "") : null;

  useEffect(() => {
    const base = collectionGroup(db, "reports");
    // Approval chain (full "both"): the province-wide view only shows reports a
    // Municipal admin has approved for escalation (escalatedToProvince == true).
    // A specific-municipality view still shows all of that town's reports so the
    // Municipal admin can triage and approve them.
    const q = scopedBarangay !== null && municipality
      ? query(base,
          where("municipality", "==", municipality),
          where("barangay", "==", scopedBarangay),
          orderBy("reportedAt", "desc"), limit(256))
      : municipality
        ? query(base, where("municipality", "==", municipality), orderBy("reportedAt", "desc"), limit(256))
        : query(base, where("escalatedToProvince", "==", true), orderBy("reportedAt", "desc"), limit(256));

    const unsub = onSnapshot(
      q,
      (snap) => { setReports(snap.docs.map(toReport)); setLoading(false); },
      (err)  => { console.error("Reports listener:", err); setLoading(false); }
    );

    return unsub;
  }, [municipality, scopedBarangay]);

  return { reports, loading };
}

export async function updateReportStatus(userId: string, reportId: string, status: ReportStatus) {
  await updateDoc(doc(db, "users", userId, "reports", reportId), {
    status,
    lastModified: Timestamp.now(),
  });
}

// Transfer/route a report to a different administrative tier. Mirrors the
// mobile FirebaseReportRepository.transferToLevel: keep escalatedToProvince in
// sync (true for provincial + Region II) so the province-wide view/badges keep
// working, and stamp who escalated it and when.
export async function transferReportLevel(
  userId: string,
  reportId: string,
  level: HandlingLevel,
  escalatedBy?: string,
) {
  const escalated = level === "provincial" || level === "region_ii";
  await updateDoc(doc(db, "users", userId, "reports", reportId), {
    handlingLevel: level,
    escalatedToProvince: escalated,
    lastModified: Timestamp.now(),
    ...(escalated
      ? { escalatedAt: Timestamp.now(), escalatedBy: escalatedBy ?? null }
      : {}),
  });
}

export async function assignResponder(userId: string, reportId: string, responder: string) {
  await updateDoc(doc(db, "users", userId, "reports", reportId), {
    assignedResponder: responder,
    lastModified: Timestamp.now(),
  });
}

export async function addReportNote(
  userId: string,
  reportId: string,
  note: Omit<ReportNote, "timestamp"> & { timestamp: Date }
) {
  await updateDoc(doc(db, "users", userId, "reports", reportId), {
    notes: arrayUnion({ ...note, timestamp: Timestamp.fromDate(note.timestamp) }),
    lastModified: Timestamp.now(),
  });
}

export async function deleteReport(userId: string, reportId: string) {
  await deleteDoc(doc(db, "users", userId, "reports", reportId));
}
