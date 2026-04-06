import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [],
  },
  async redirects() {
    return [{ source: "/download", destination: "/buy", permanent: true }];
  },
};

export default nextConfig;
