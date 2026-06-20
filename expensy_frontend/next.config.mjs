/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Produces the minimal .next/standalone bundle used by the Docker image.
  output: 'standalone',
}

export default nextConfig
