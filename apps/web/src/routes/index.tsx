import { createFileRoute } from "@tanstack/react-router";
import { LandingPage } from "@/components/landing/LandingPage";

// Public landing page for residents. The admin/LGU console stays behind
// /login and /dashboard.
export const Route = createFileRoute("/")({
  component: LandingPage,
});
