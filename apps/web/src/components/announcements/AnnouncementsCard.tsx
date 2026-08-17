import { useState } from "react";
import { format } from "date-fns";
import { Plus, Trash2, Megaphone, AlertTriangle, Loader2, Link2, Download } from "lucide-react";
import { httpsCallable } from "firebase/functions";
import { functions } from "@/lib/firebase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { postAnnouncement, deleteAnnouncement } from "@/hooks/useAnnouncements";
import { useAuthStore } from "@/stores/authStore";
import { toast } from "@/hooks/useToast";
import { timeAgo } from "@/lib/utils";
import { MUNICIPALITIES } from "@/data/municipalities";
import type { Announcement } from "@/types";

interface AnnouncementsCardProps {
  announcements: Announcement[];
  loading: boolean;
}

export function AnnouncementsCard({ announcements, loading }: AnnouncementsCardProps) {
  const { user } = useAuthStore();
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [urgent, setUrgent] = useState(false);
  const [municipality, setMunicipality] = useState("all");
  // Agency/source shown to residents as the author of the post (e.g.
  // "PDRRMO Nueva Vizcaya", "Philstar"), instead of the logged-in admin's
  // personal name. Defaults to the admin's name if left blank.
  const [postedBy, setPostedBy] = useState("");
  const [saving, setSaving] = useState(false);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [deleteTitle, setDeleteTitle] = useState("");
  // Import-from-link (interim FB / news importer)
  const [importUrl, setImportUrl] = useState("");
  const [importing, setImporting] = useState(false);
  const [sourceUrl, setSourceUrl] = useState("");
  const [imageUrl, setImageUrl] = useState("");

  const resetForm = () => {
    setTitle(""); setBody(""); setUrgent(false); setMunicipality("all");
    setImportUrl(""); setSourceUrl(""); setImageUrl(""); setPostedBy("");
  };

  const handleImport = async () => {
    const url = importUrl.trim();
    if (!url) return;
    setImporting(true);
    try {
      const fn = httpsCallable<
        { url: string },
        { title: string; description: string; image: string; siteName: string; url: string }
      >(functions, "fetchLinkPreview");
      const { data } = await fn({ url });
      if (data.title) setTitle(data.title.slice(0, 140));
      if (data.description) setBody(data.description);
      if (data.image) setImageUrl(data.image);
      // Credit the original source as the author (e.g. "Philstar") so the post
      // reads like the app's agency-sourced announcements, not "posted by <admin>".
      if (data.siteName) setPostedBy(data.siteName);
      setSourceUrl(data.url || url);
      const bodyMissing = !data.description;
      toast({
        title: bodyMissing ? "Imported title only" : "Imported — review before posting",
        description: bodyMissing
          ? "This link (often Facebook) hides its text behind a login. Paste the message body manually."
          : undefined,
        variant: "success" as never,
      });
    } catch {
      toast({ title: "Couldn't import that link", description: "Paste the text manually instead.", variant: "destructive" });
    } finally {
      setImporting(false);
    }
  };

  const handlePost = async () => {
    if (!title.trim() || !body.trim() || !user) return;
    setSaving(true);
    try {
      await postAnnouncement({
        title: title.trim(),
        body: body.trim(),
        urgent,
        isUrgent: urgent,
        municipality,
        postedBy: postedBy.trim() || user.name,
        ...(sourceUrl ? { sourceUrl, sourceLabel: "View original post" } : {}),
        ...(imageUrl ? { imageUrl } : {}),
      });
      toast({ title: "Announcement posted", variant: "success" as never });
      setOpen(false);
      resetForm();
    } catch {
      toast({ title: "Failed to post", variant: "destructive" });
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!deleteId) return;
    try {
      await deleteAnnouncement(deleteId);
      toast({ title: "Announcement removed", variant: "success" as never });
    } catch {
      toast({ title: "Failed to delete", variant: "destructive" });
    } finally {
      setDeleteId(null);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">{announcements.length} announcement{announcements.length !== 1 ? "s" : ""}</p>
        <Button size="sm" className="h-8 text-xs" onClick={() => setOpen(true)}>
          <Plus className="h-3.5 w-3.5 mr-1" /> Post
        </Button>
      </div>

      {loading ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-16 w-full" />)}
        </div>
      ) : announcements.length === 0 ? (
        <div className="text-center py-10 text-muted-foreground">
          <Megaphone className="h-8 w-8 mx-auto mb-2 opacity-40" />
          <p className="text-sm">No announcements yet</p>
        </div>
      ) : (
        <div className="space-y-2">
          {announcements.map((a) => (
            <div
              key={a.id}
              className={`border rounded-lg p-3.5 ${a.urgent ? "border-red-200 bg-red-50/50" : "bg-white"}`}
            >
              <div className="flex items-start gap-2">
                {a.urgent && <AlertTriangle className="h-4 w-4 text-red-500 mt-0.5 shrink-0" />}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="font-medium text-sm">{a.title}</p>
                    {a.urgent && <Badge variant="destructive" className="text-xs">Urgent</Badge>}
                    {a.municipality !== "all" && (
                      <Badge variant="outline" className="text-xs">{a.municipality}</Badge>
                    )}
                  </div>
                  <p className="text-sm text-muted-foreground mt-1 line-clamp-2">{a.body}</p>
                  <p className="text-xs text-muted-foreground mt-1.5">
                    {a.postedBy} · {timeAgo(a.timestamp)}
                  </p>
                </div>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-7 w-7 shrink-0 text-muted-foreground hover:text-destructive"
                  onClick={() => { setDeleteId(a.id); setDeleteTitle(a.title); }}
                >
                  <Trash2 className="h-3.5 w-3.5" />
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}

      <Dialog open={open} onOpenChange={(o) => { setOpen(o); if (!o) resetForm(); }}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Post Announcement</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            {/* Interim importer: pull a public post's title/text/image so an
                admin can review + publish without retyping. Nothing auto-posts. */}
            <div className="space-y-1.5 rounded-lg border border-dashed p-2.5 bg-muted/30">
              <Label className="text-xs flex items-center gap-1">
                <Link2 className="h-3.5 w-3.5" /> Import from a link (Facebook / news)
              </Label>
              <div className="flex gap-2">
                <Input
                  value={importUrl}
                  onChange={(e) => setImportUrl(e.target.value)}
                  placeholder="Paste a public post URL…"
                  className="text-xs"
                />
                <Button type="button" variant="outline" size="sm" onClick={handleImport} disabled={importing || !importUrl.trim()}>
                  {importing ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}
                  <span className="ml-1 hidden sm:inline">Import</span>
                </Button>
              </div>
              <p className="text-[10px] text-muted-foreground">
                Pulls the title, text &amp; image for you to review — then Post. Nothing is auto-published.
              </p>
            </div>
            <div className="space-y-1">
              <Label className="text-xs">Title *</Label>
              <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Announcement title" />
            </div>
            <div className="space-y-1">
              <Label className="text-xs">Message *</Label>
              <Textarea value={body} onChange={(e) => setBody(e.target.value)} placeholder="Message…" rows={4} className="resize-none" />
            </div>
            <div className="space-y-1">
              <Label className="text-xs">Posted by (agency / source)</Label>
              <Input
                value={postedBy}
                onChange={(e) => setPostedBy(e.target.value)}
                placeholder={`e.g. PDRRMO Nueva Vizcaya — defaults to ${user?.name ?? "your name"}`}
              />
            </div>
            {imageUrl && (
              <div className="space-y-1">
                <img src={imageUrl} alt="Imported preview" className="rounded-md border w-full h-32 object-cover" />
              </div>
            )}
            {sourceUrl && (
              <p className="text-[10px] text-muted-foreground truncate">Source: {sourceUrl}</p>
            )}
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label className="text-xs">Target</Label>
                <Select value={municipality} onValueChange={setMunicipality}>
                  <SelectTrigger className="text-xs"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">Province-wide</SelectItem>
                    {MUNICIPALITIES.map((m) => <SelectItem key={m.name} value={m.name}>{m.name}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label className="text-xs">Urgent</Label>
                <div className="flex items-center gap-2 pt-2">
                  <Switch checked={urgent} onCheckedChange={setUrgent} />
                  <span className="text-xs text-muted-foreground">{urgent ? "Yes" : "No"}</span>
                </div>
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
            <Button onClick={handlePost} disabled={saving || !title.trim() || !body.trim()}>
              {saving ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
              Post
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <AlertDialog open={!!deleteId} onOpenChange={(o) => !o && setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Announcement?</AlertDialogTitle>
            <AlertDialogDescription>Remove "{deleteTitle}"?</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={handleDelete} className="bg-destructive hover:bg-destructive/90">Delete</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
