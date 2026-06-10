import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        omni: {
          // Engindearing brand, locked 2026-05-25.
          // Emerald #3E9E66 primary, Indigo #1A1267 secondary, #1A1A1A base.
          base: "#1A1A1A",            // page background
          surface: "#212121",         // raised surfaces
          "surface-light": "#2A2A2A", // cards, inputs
          border: "#2E2E2E",          // hairlines
          accent: "#3E9E66",          // emerald primary
          "accent-light": "#6BBE93",  // emerald, one step lighter
          "accent-dark": "#2E7A4F",   // emerald, one step darker
          indigo: "#1A1267",          // indigo secondary (glows, gradients)
          "indigo-light": "#2B1FA8",  // indigo gradient stop
          white: "#F8FAFC",           // headings
          grey: "#94A3B8",            // body text (slate-400)
          "grey-light": "#CBD5E1",    // emphasized body (slate-300)
          "grey-dark": "#64748B",     // muted (slate-500)
        },
      },
      fontFamily: {
        sans: ["var(--font-geist-sans)"],
        mono: ["var(--font-geist-mono)"],
      },
      animation: {
        "fade-in": "fade-in 0.5s ease-out",
        "slide-up": "slide-up 0.5s ease-out",
      },
      keyframes: {
        "slide-up": {
          "0%": { transform: "translateY(20px)", opacity: "0" },
          "100%": { transform: "translateY(0)", opacity: "1" },
        },
        "fade-in": {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
      },
    },
  },
  plugins: [],
};
export default config;
