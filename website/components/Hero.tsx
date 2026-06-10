'use client';

import { motion } from 'framer-motion';

const APP_STORE_URL = 'https://apps.apple.com/us/app/omnitakmobile/id6755246992';
const PLAY_TESTING_URL = 'https://play.google.com/apps/testing/soy.engindearing.omnitak.mobile';
const GITHUB_IOS = 'https://github.com/engindearing-projects/OmniTAK-iOS';

const proof = [
  'Live on the App Store',
  'Android in Play testing',
  'Apache 2.0 on GitHub',
  '7 languages on iOS',
  'Works with ATAK, WinTAK, iTAK',
];

export default function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden pt-24 pb-16">
      <div className="relative z-10 max-w-6xl mx-auto px-6 text-center">
        {/* Badge */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="mb-8"
        >
          <span className="tag">
            [ Open-source TAK client ]
          </span>
        </motion.div>

        {/* Headline */}
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.1 }}
          className="text-5xl md:text-7xl font-bold mb-6 tracking-tight leading-[1.05]"
        >
          <span className="text-omni-white">One shared map.</span>
          <br />
          <span className="text-gradient font-mono">iOS and Android.</span>
        </motion.h1>

        {/* Subheadline */}
        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="text-lg md:text-xl text-omni-grey mb-10 max-w-3xl mx-auto leading-relaxed"
        >
          OmniTAK is an open-source TAK client that puts your whole team on the same
          tactical picture: live positions, chat, missions, off-grid mesh, and drone
          detection. Built by one engineer, shipped to the App Store, with Android in
          Play testing.
        </motion.p>

        {/* CTA row: App Store, Play, GitHub */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.3 }}
          className="flex flex-col sm:flex-row gap-4 justify-center items-center mb-12"
        >
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary inline-flex items-center gap-3"
          >
            <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
            </svg>
            <span className="text-left">
              <span className="text-xs block opacity-80">Download on the</span>
              <span className="text-base font-semibold leading-tight">App Store</span>
            </span>
          </a>
          <a
            href={PLAY_TESTING_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-secondary inline-flex items-center gap-3"
          >
            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M3.609 1.814L13.792 12 3.61 22.186a2.012 2.012 0 01-.497-1.33V3.145c0-.504.186-.972.496-1.331zm10.831 10.833l2.27 2.27-2.745 1.586-6.778 3.914 7.253-7.77zm3.355-1.085l2.668 1.54a1.346 1.346 0 010 2.337l-2.668 1.54-2.522-2.708 2.522-2.709zm-3.355-1.083L7.187 2.71l6.778 3.914 2.745 1.586-2.27 2.269z"/>
            </svg>
            Join the Play test
          </a>
          <a
            href={GITHUB_IOS}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-secondary inline-flex items-center gap-2"
          >
            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
            </svg>
            GitHub
          </a>
        </motion.div>

        {/* Proof strip */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.4 }}
          className="flex flex-wrap justify-center gap-2 sm:gap-3"
        >
          {proof.map((item) => (
            <div key={item} className="card px-3 py-1.5 flex items-center gap-2">
              <svg className="w-3.5 h-3.5 text-omni-accent shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
              </svg>
              <span className="font-mono text-xs sm:text-sm text-omni-grey-light">{item}</span>
            </div>
          ))}
        </motion.div>

        {/* Composite traction line */}
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.5 }}
          className="mt-10 text-sm text-omni-grey-dark font-mono"
        >
          Field-tested by a volunteer fire brigade in Asia and an airsoft team in Europe.
        </motion.p>
      </div>
    </section>
  );
}
