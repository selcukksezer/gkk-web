// ============================================================
// Facility Detail Page (Server) — generates static params + delegates to client
// ============================================================

import { FACILITIES_CONFIG } from "@/data/FacilityConfig";
import FacilityDetailClient from "./FacilityDetailClient";

export const dynamic = "force-dynamic";

export function generateStaticParams() {
  return Object.keys(FACILITIES_CONFIG).map((type) => ({ type }));
}

export default async function FacilityDetailPage({
  params,
}: {
  params: Promise<{ type: string }>;
}) {
  const { type } = await params;
  return <FacilityDetailClient type={type} />;
}
