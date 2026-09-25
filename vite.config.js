import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  base: "/portal/",
  server: {
    proxy: { "/portal/api": "http://localhost:52773" },
  },
  // The portal is served by IRIS own web application
  build: { outDir: "dist", emptyOutDir: true },
});
