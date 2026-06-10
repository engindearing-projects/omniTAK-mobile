'use client';

import { motion } from 'framer-motion';

const GYB_REPO = 'https://github.com/jfuginay/gyb_detect';

export default function Gyb() {
  return (
    <section id="gyb" className="relative py-24 md:py-28 scroll-mt-20">
      <div className="max-w-5xl mx-auto px-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="card p-8 md:p-12"
        >
          <div className="font-mono text-xs text-omni-accent tracking-widest mb-3">
            {'// HARDWARE'}
          </div>
          <h2 className="text-3xl md:text-4xl font-bold mb-6">
            <span className="text-omni-white">gyb:</span>{' '}
            <span className="text-gradient">a pocket Remote ID sensor</span>
          </h2>
          <div className="grid md:grid-cols-2 gap-8 items-start">
            <div className="space-y-4 text-omni-grey leading-relaxed">
              <p>
                gyb is a low-cost ESP32 board that listens for FAA Remote ID broadcasts
                on WiFi, where most phones cannot, and feeds detections to OmniTAK over
                BLE. The app merges them with its own Bluetooth scanning into a single
                track per drone, with the operator plotted too.
              </p>
              <p>
                Detection range scales with the drone&apos;s broadcast power and your
                antenna, not with marketing claims. It hears Remote ID broadcasts; it
                does not see every drone in the sky, and nothing does.
              </p>
            </div>
            <div className="space-y-4">
              <ul className="space-y-3">
                {[
                  'WiFi Remote ID capture the phone radios miss',
                  'BLE GATT link into OmniTAK on iOS and Android',
                  'Drone and operator markers on the shared map',
                  'Open firmware you can flash and audit yourself',
                ].map((item) => (
                  <li key={item} className="flex items-start gap-3 text-sm text-omni-grey-light">
                    <svg className="w-4 h-4 text-omni-accent shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
                    </svg>
                    {item}
                  </li>
                ))}
              </ul>
              <a
                href={GYB_REPO}
                target="_blank"
                rel="noopener noreferrer"
                className="btn-secondary inline-flex items-center gap-2 text-sm"
              >
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                </svg>
                gyb_detect firmware on GitHub
              </a>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
