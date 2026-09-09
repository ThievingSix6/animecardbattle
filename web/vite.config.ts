import { defineConfig } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";

// Everything is inlined into one HTML file so `dist/index.html` can be
// opened straight from disk with no server and no build tooling.
export default defineConfig({
  base: "./",
  plugins: [viteSingleFile()],
  build: { target: "es2020", assetsInlineLimit: 100_000_000, cssCodeSplit: false },
  server: { open: true },
});
