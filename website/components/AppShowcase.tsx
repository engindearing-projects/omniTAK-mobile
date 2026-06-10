'use client';

import { motion } from 'framer-motion';
import Image from 'next/image';

const screenshots = [
  {
    image: '/screenshots/01-map.jpg',
    title: 'Live map',
    description: 'Contacts, drones, overlays, and your own track on satellite imagery',
  },
  {
    image: '/screenshots/02-chat.png',
    title: 'GeoChat',
    description: 'All Chat, direct messages, and mesh threads in one place',
  },
  {
    image: '/screenshots/03-servers.png',
    title: 'Servers',
    description: 'Multiple simultaneous TAK server connections with per-server status',
  },
  {
    image: '/screenshots/04-mesh.png',
    title: 'Meshtastic',
    description: 'Radio pairing, node list, and off-grid position reporting',
  },
  {
    image: '/screenshots/05-settings.png',
    title: 'Settings',
    description: 'Callsign, team color, units, and UI language switched at runtime',
  },
];

export default function AppShowcase() {
  return (
    <section id="showcase" className="relative py-24 md:py-32 overflow-hidden scroll-mt-20">
      <div className="max-w-7xl mx-auto px-6">
        {/* Section header */}
        <div className="text-center mb-16">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="font-mono text-xs text-omni-accent tracking-widest mb-3"
          >
            {'// SCREENSHOTS'}
          </motion.div>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.1 }}
            className="text-4xl md:text-5xl font-bold mb-6 text-omni-white"
          >
            Straight from the app
          </motion.h2>
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.2 }}
            className="text-lg text-omni-grey max-w-2xl mx-auto"
          >
            Real screens, no mockups. These are the production builds shipping to the
            App Store and Google Play.
          </motion.p>
        </div>

        {/* Screenshot strip */}
        <div className="relative">
          <div className="flex gap-8 overflow-x-auto pb-8 snap-x snap-mandatory no-scrollbar">
            {screenshots.map((screenshot, i) => (
              <motion.div
                key={screenshot.title}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.08 }}
                className="flex-shrink-0 snap-center first:pl-2 last:pr-2"
              >
                <div className="w-[260px] md:w-[300px]">
                  {/* Phone frame */}
                  <div className="relative bg-omni-surface-light rounded-[2.5rem] p-2 border border-omni-border">
                    <div className="relative bg-black rounded-[2rem] overflow-hidden">
                      <div className="relative aspect-[1080/2400]">
                        <Image
                          src={screenshot.image}
                          alt={`OmniTAK ${screenshot.title} screen`}
                          fill
                          className="object-cover"
                          sizes="(max-width: 768px) 260px, 300px"
                        />
                      </div>
                    </div>
                  </div>
                  {/* Caption below the frame, never over the map */}
                  <div className="mt-4 text-center px-2">
                    <h3 className="text-sm font-semibold font-mono text-omni-white mb-1">
                      {screenshot.title}
                    </h3>
                    <p className="text-xs text-omni-grey leading-relaxed">
                      {screenshot.description}
                    </p>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>

          {/* Scroll hint */}
          <div className="flex justify-center items-center gap-2 mt-2">
            <span className="text-xs text-omni-grey-dark uppercase tracking-wider font-mono">Scroll for more</span>
            <svg className="w-4 h-4 text-omni-grey-dark" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" />
            </svg>
          </div>
        </div>
      </div>
    </section>
  );
}
