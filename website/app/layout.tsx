import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-geist-sans" });
const jetbrainsMono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-geist-mono" });

export const metadata: Metadata = {
  title: "OmniTAK | Open-source TAK client for iOS and Android",
  description:
    "OmniTAK puts your team on one shared TAK map: multi-server mTLS connections, Mission Sync, GeoChat, MIL-STD-2525 symbology, Meshtastic off-grid comms, and Remote ID drone detection. Live on the App Store, Android in Play testing, Apache 2.0 on GitHub.",
  keywords: ["TAK", "ATAK", "iTAK", "TAK client", "tactical", "situational awareness", "Meshtastic", "Remote ID", "drone detection", "CoT"],
  metadataBase: new URL("https://omnitak.engindearing.soy"),
  icons: {
    icon: [
      { url: "/favicon.ico" },
      { url: "/brand/favicon.svg", type: "image/svg+xml" },
      { url: "/favicon-16x16.png", sizes: "16x16", type: "image/png" },
      { url: "/favicon-32x32.png", sizes: "32x32", type: "image/png" },
    ],
    apple: [
      { url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" },
    ],
  },
  openGraph: {
    title: "OmniTAK | Open-source TAK client for iOS and Android",
    description:
      "One shared map for the whole team. Live on the App Store, Android in Play testing, Apache 2.0 on GitHub.",
    type: "website",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "OmniTAK, open-source TAK client for iOS and Android, by Engindearing",
      },
    ],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth">
      <body className={`${inter.variable} ${jetbrainsMono.variable} font-sans antialiased bg-omni-base text-omni-white`}>
        {children}
      </body>
    </html>
  );
}
