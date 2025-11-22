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
          // ATAK-inspired military color palette
          olive: "#6B7C5A",        // Primary accent - military olive
          'olive-dark': "#4A5C3A", // Darker olive
          teal: "#5FABA5",         // Secondary accent - muted teal
          'teal-dark': "#4A9B9B",  // Darker teal
          charcoal: "#1A1A1A",     // Primary dark background
          slate: "#2A2A2A",        // Secondary background
          'slate-light': "#3A3A3A",// Lighter slate for cards
          grey: "#4A4A4A",         // Medium grey
          'grey-light': "#6A6A6A", // Light grey for text
          'grey-border': "#333333",// Border grey
          light: "#D0D0D0",        // Light text
        },
      },
      fontFamily: {
        sans: ["var(--font-geist-sans)"],
        mono: ["var(--font-geist-mono)"],
      },
      animation: {
        "float": "float 6s ease-in-out infinite",
        "glow": "glow 2s ease-in-out infinite alternate",
        "slide-up": "slide-up 0.5s ease-out",
        "fade-in": "fade-in 0.5s ease-out",
        "shimmer": "shimmer 2s linear infinite",
      },
      keyframes: {
        float: {
          "0%, 100%": { transform: "translateY(0px)" },
          "50%": { transform: "translateY(-20px)" },
        },
        glow: {
          "0%": { boxShadow: "0 0 5px rgba(107, 124, 90, 0.5)" },
          "100%": { boxShadow: "0 0 20px rgba(107, 124, 90, 0.8)" },
        },
        "slide-up": {
          "0%": { transform: "translateY(100px)", opacity: "0" },
          "100%": { transform: "translateY(0)", opacity: "1" },
        },
        "fade-in": {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        shimmer: {
          "0%": { backgroundPosition: "-1000px 0" },
          "100%": { backgroundPosition: "1000px 0" },
        },
      },
      backgroundImage: {
        "gradient-radial": "radial-gradient(var(--tw-gradient-stops))",
        "gradient-conic": "conic-gradient(from 180deg at 50% 50%, var(--tw-gradient-stops))",
      },
    },
  },
  plugins: [],
};
export default config;
