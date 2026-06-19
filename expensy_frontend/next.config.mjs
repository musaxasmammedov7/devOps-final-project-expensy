/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Required for distroless Docker image — produces .next/standalone bundle
  output: 'standalone',
}

export default nextConfig
