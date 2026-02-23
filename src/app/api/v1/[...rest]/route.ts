import { NextResponse } from "next/server";

function handle(req: Request) {
  // fallback for any unimplemented API calls
  const url = new URL(req.url);
  const path = url.pathname.replace(/\/api\/v1/, "");
  console.warn(`[Mock API] unhandled path ${path} ${req.method}`);

  // generic response object expected by hooks
  const body = {
    success: false,
    error: "unimplemented",
    code: 404,
  };
  return NextResponse.json(body, { status: 404 });
}

export function GET(req: Request) {
  return handle(req);
}
export function POST(req: Request) {
  return handle(req);
}
export function PUT(req: Request) {
  return handle(req);
}
export function PATCH(req: Request) {
  return handle(req);
}
export function DELETE(req: Request) {
  return handle(req);
}