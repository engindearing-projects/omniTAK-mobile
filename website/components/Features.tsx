'use client';

import { motion } from 'framer-motion';

// Feature inventory sourced from OMNITAK-CAPABILITIES.md (2026-06-10).
// Platform badges reflect what is actually shipped on each platform.
const features = [
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
      </svg>
    ),
    title: 'Multi-server connections',
    platforms: 'iOS + Android',
    description:
      'Run several TAK server connections at once over TLS and mTLS, with per-server status. Certificate auto-enrollment, QR enrollment, and data package import get a new phone onto the server in minutes.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
      </svg>
    ),
    title: 'Mission Sync',
    platforms: 'iOS + Android',
    description:
      'A mission dashboard across every enabled server over the Marti REST API, including the dialect quirks between TAK Server builds. Create missions and push data packages from the field.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
      </svg>
    ),
    title: 'GeoChat',
    platforms: 'iOS + Android',
    description:
      'All Chat, direct messages, and group threads with unread counts, routed per server when you run more than one. Photo attachments on iOS.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 2l3 5h5l-4 4 1.5 6L12 14l-5.5 3L8 11 4 7h5l3-5z" />
      </svg>
    ),
    title: 'MIL-STD-2525 symbology',
    platforms: 'iOS + Android',
    description:
      'Contacts, drones, and your own marker rendered as proper 2525 symbols with team colors, on both map engines. FEMA and incident command icon sets included.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    title: '2D + 3D map engines',
    platforms: 'iOS + Android',
    description:
      'Switch engines at runtime: Mapbox and Cesium on iOS, MapLibre and 3D terrain on Android. Live contacts on the globe, not just the flat map.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
      </svg>
    ),
    title: 'Offline maps',
    platforms: 'iOS + Android',
    description:
      'Import MBTiles, KML/KMZ, GeoTIFF, GeoPDF, and GeoPackage overlays on both platforms. Download offline map regions on iOS before you lose the network.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.14 0M1.394 9.393c5.857-5.857 15.355-5.857 21.213 0" />
      </svg>
    ),
    title: 'Meshtastic off-grid',
    platforms: 'iOS + Android',
    description:
      'Position reports and chat over LoRa when there is no network and no server, speaking the same protobuf the ATAK Meshtastic plugin uses. Mixed OmniTAK and ATAK teams stay on one map.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
      </svg>
    ),
    title: 'Remote ID drone detection',
    platforms: 'iOS + Android',
    description:
      'The phone listens for FAA Remote ID broadcasts over Bluetooth and plots both the drone and its operator as live tracks. Pair the gyb ESP32 sensor over BLE to add WiFi Remote ID coverage.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
      </svg>
    ),
    title: 'Coordinate systems',
    platforms: 'iOS + Android',
    description:
      'DD, DMS, MGRS, UTM, BNG (iOS), and Taiwan TWD97 in both 7+7 and 5+5 digit forms, honored app-wide. Type a grid, get a marker.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
      </svg>
    ),
    title: 'Runtime language switching',
    platforms: '7 languages on iOS',
    description:
      'Switch the UI language without a restart. Seven languages on iOS, including a Traditional Chinese translation contributed by a volunteer firefighter in Taiwan and shipped within the week.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
      </svg>
    ),
    title: 'Military reports',
    platforms: 'iOS',
    description:
      'CASEVAC/MEDEVAC, 9-Line, SPOTREP, and SALUTE built as standard CoT, so the request lands correctly in every TAK client on the net.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M11 4a2 2 0 114 0v1a1 1 0 001 1h3a1 1 0 011 1v3a1 1 0 01-1 1h-1a2 2 0 100 4h1a1 1 0 011 1v3a1 1 0 01-1 1h-3a1 1 0 01-1-1v-1a2 2 0 10-4 0v1a1 1 0 01-1 1H7a1 1 0 01-1-1v-3a1 1 0 00-1-1H4a2 2 0 110-4h1a1 1 0 001-1V7a1 1 0 011-1h3a1 1 0 001-1V4z" />
      </svg>
    ),
    title: 'Interoperable by design',
    platforms: 'TAK ecosystem',
    description:
      'Standard CoT over TLS, tested against TAK Server, OpenTAKServer, and taky. If your team already runs ATAK, WinTAK, or iTAK, OmniTAK joins the same picture.',
  },
];

export default function Features() {
  return (
    <section id="features" className="relative py-24 md:py-32 scroll-mt-20">
      <div className="max-w-7xl mx-auto px-6">
        {/* Section header */}
        <div className="text-center mb-16">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="font-mono text-xs text-omni-accent tracking-widest mb-3"
          >
            {'// FEATURES'}
          </motion.div>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.1 }}
            className="text-4xl md:text-5xl font-bold mb-6"
          >
            <span className="text-omni-white">What it does</span>{' '}
            <span className="text-gradient">in the field</span>
          </motion.h2>
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.2 }}
            className="text-lg text-omni-grey max-w-2xl mx-auto"
          >
            The capability list below is the shipped feature set, not a roadmap.
            Platform tags tell you exactly where each one runs today.
          </motion.p>
        </div>

        {/* Features grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5">
          {features.map((feature, i) => (
            <motion.div
              key={feature.title}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: (i % 3) * 0.05 }}
              className="card card-hover p-6 group"
            >
              <div className="flex items-start justify-between mb-4">
                <div className="feature-icon text-omni-accent">
                  {feature.icon}
                </div>
                <span className="platform-badge">{feature.platforms}</span>
              </div>
              <h3 className="text-lg font-semibold font-mono text-omni-white mb-2 group-hover:text-omni-accent-light transition-colors">
                {feature.title}
              </h3>
              <p className="text-sm text-omni-grey leading-relaxed">
                {feature.description}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
