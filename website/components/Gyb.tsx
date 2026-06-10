'use client';

import { motion } from 'framer-motion';

const GYB_INQUIRY_URL = 'https://www.engindearing.soy/hire';

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
                  'Ships ready to pair, no flashing or setup',
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
                href={GYB_INQUIRY_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="btn-secondary inline-flex items-center gap-2 text-sm"
              >
                Ask about gyb units
              </a>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
