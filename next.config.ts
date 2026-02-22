import type { NextConfig } from "next";

const isDev = process.env.NODE_ENV !== "production";

const nextConfig: NextConfig = {
  // only enable static HTML export in production build; dev server must remain dynamic
  output: isDev ? undefined : "export",
  trailingSlash: true, // file:// protocol compat (Capacitor)
  images: {
    unoptimized: true, // Required for static export
  },
};

export default nextConfig;
