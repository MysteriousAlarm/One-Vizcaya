import { useEffect, useState } from "react";
import {
  collection, query, where, orderBy, limit, onSnapshot,
  addDoc, updateDoc, doc, Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { RoleRequest } from "@/types";
import type { AdminRole } from "@/lib/firebase";

function toRoleRequest(id: string, data: Record<string, unknown>): RoleRequest {
  const ts = (v: unknown) => (v instanceof Timestamp ? v.toDate() : undefined);
  return {
    id,
    targetUid: (data.targetUid as string) ?? "",
    targetName: (data.targetName as string) ?? "",
    targetPhone: data.targetPhone as string | undefined,
    requestedRole: (data.requestedRole as RoleRequest["requestedRole"]) ?? "citizen",
    municipality: data.municipality as string | undefined,
    barangay: data.barangay as string | undefined,
    nominatedBy: (data.nominatedBy as string) ?? "",
    nominatedByName: (data.nominatedByName as string) ?? "",
    status: (data.status as RoleRequest["status"]) ?? "pending",
    createdAt: ts(data.createdAt) ?? new Date(),
    decidedBy: data.decidedBy as string | undefined,
    decidedAt: ts(data.decidedAt),
  };
}

// Live pending nominations, newest first. Only super_admins can act on them,
// but any admin may see the queue (rules allow isAdmin read).
export function usePendingRoleRequests() {
  const [requests, setRequests] = useState<RoleRequest[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(
      collection(db, "roleRequests"),
      where("status", "==", "pending"),
      orderBy("createdAt", "desc"),
      limit(100),
    );
    const unsub = onSnapshot(
      q,
      (snap) => { setRequests(snap.docs.map((d) => toRoleRequest(d.id, d.data()))); setLoading(false); },
      (err) => { console.error("Role requests listener:", err); setLoading(false); },
    );
    return unsub;
  }, []);

  return { requests, loading };
}

export interface NominateInput {
  targetUid: string;
  targetName: string;
  targetPhone?: string;
  requestedRole: AdminRole | "citizen";
  municipality?: string;
  barangay?: string;
  nominatedBy: string;
  nominatedByName: string;
}

// Create a pending nomination. The role is NOT applied here — a super_admin
// must approve it, after which onRoleRequestDecision writes the role server-side.
export async function nominateForRole(input: NominateInput) {
  await addDoc(collection(db, "roleRequests"), {
    targetUid: input.targetUid,
    targetName: input.targetName,
    targetPhone: input.targetPhone ?? null,
    requestedRole: input.requestedRole,
    municipality: input.municipality ?? null,
    barangay: input.requestedRole === "barangay_admin" ? (input.barangay ?? "") : null,
    nominatedBy: input.nominatedBy,
    nominatedByName: input.nominatedByName,
    status: "pending",
    createdAt: Timestamp.now(),
  });
}

// Super-admin decision. Flipping status triggers onRoleRequestDecision, which
// applies (or skips) the role and writes the audit entry.
export async function decideRoleRequest(
  id: string,
  decision: "approved" | "rejected",
  decidedBy: string,
) {
  await updateDoc(doc(db, "roleRequests", id), {
    status: decision,
    decidedBy,
    decidedAt: Timestamp.now(),
  });
}
