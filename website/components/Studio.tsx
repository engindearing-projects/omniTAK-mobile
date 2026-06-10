'use client';

import { motion } from 'framer-motion';
import Image from 'next/image';

const STUDIO_URL = 'https://www.engindearing.soy';

export default function Studio() {
  return (
    <section id="studio" className="relative py-20 md:py-24">
      <div className="max-w-4xl mx-auto px-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="card p-8 md:p-12 text-center"
        >
          <div className="flex justify-center mb-6">
            <Image
              src="/brand/crt_mark_white.svg"
              alt="Engindearing CRT mark"
              width={72}
              height={70}
              className="w-16 h-16 md:w-[72px] md:h-[70px]"
            />
          </div>
          <div className="font-mono text-xs text-omni-accent tracking-widest mb-3">
            {'// BUILT BY ENGINDEARING'}
          </div>
          <h2 className="text-3xl md:text-4xl font-bold mb-5 text-omni-white">
            Need custom <span className="text-gradient">TAK tooling?</span>
          </h2>
          <p className="text-lg text-omni-grey max-w-2xl mx-auto mb-4 leading-relaxed">
            OmniTAK is the flagship of Engindearing, a one-engineer tactical software
            studio. The studio builds TAK clients, Cursor-on-Target integrations,
            sensor-to-CoT adapters, and counter-UAS situational awareness for teams in
            the field.
          </p>
          <p className="text-base text-omni-grey-dark max-w-2xl mx-auto mb-8 leading-relaxed">
            If your detections are stuck in a vendor UI, or your team needs a client
            that fits how it actually operates, that is the day job.
          </p>
          <a
            href={STUDIO_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary inline-flex items-center gap-2"
          >
            Start a project at engindearing.soy
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" />
            </svg>
          </a>
        </motion.div>
      </div>
    </section>
  );
}
