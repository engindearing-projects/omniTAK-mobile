'use client';

import { motion } from 'framer-motion';

const APP_STORE_URL = 'https://apps.apple.com/us/app/omnitakmobile/id6755246992';
const TESTFLIGHT_URL = 'https://testflight.apple.com/join/SzxQGmMM';
const PLAY_TESTING_URL = 'https://play.google.com/apps/testing/soy.engindearing.omnitak.mobile';
const GITHUB_IOS = 'https://github.com/engindearing-projects/OmniTAK-iOS';
const GITHUB_ANDROID = 'https://github.com/engindearing-projects/OmniTAK-Android';

export default function Download() {
  return (
    <section id="download" className="relative py-24 md:py-32 scroll-mt-20">
      <div className="max-w-6xl mx-auto px-6">
        {/* Section header */}
        <div className="text-center mb-16">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="font-mono text-xs text-omni-accent tracking-widest mb-3"
          >
            {'// GET IT'}
          </motion.div>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.1 }}
            className="text-4xl md:text-5xl font-bold mb-6 text-omni-white"
          >
            Download OmniTAK
          </motion.h2>
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.2 }}
            className="text-lg text-omni-grey max-w-2xl mx-auto"
          >
            iOS is live on the App Store. Android is in Google Play closed testing
            and open to join.
          </motion.p>
        </div>

        {/* Platform cards */}
        <div className="grid md:grid-cols-2 gap-6 mb-8">
          {/* iOS */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.1 }}
            className="card p-8"
          >
            <div className="flex flex-col items-center text-center">
              <div className="feature-icon mb-6 text-omni-accent">
                <svg className="w-7 h-7" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                </svg>
              </div>
              <h3 className="text-2xl font-semibold font-mono text-omni-white mb-2">iOS</h3>
              <p className="text-omni-grey mb-6">
                Live on the App Store. Requires iOS 15.0 or later.
              </p>
              <div className="flex flex-col sm:flex-row gap-3">
                <a
                  href={APP_STORE_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn-primary inline-flex items-center justify-center gap-2"
                >
                  App Store
                </a>
                <a
                  href={TESTFLIGHT_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn-secondary inline-flex items-center justify-center gap-2"
                >
                  TestFlight beta
                </a>
              </div>
              <p className="text-xs text-omni-grey-dark mt-4 font-mono">
                TestFlight gets new builds before the App Store does.
              </p>
            </div>
          </motion.div>

          {/* Android */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.2 }}
            className="card p-8"
          >
            <div className="flex flex-col items-center text-center">
              <div className="feature-icon mb-6 text-omni-accent">
                <svg className="w-7 h-7" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M3.609 1.814L13.792 12 3.61 22.186a2.012 2.012 0 01-.497-1.33V3.145c0-.504.186-.972.496-1.331zm10.831 10.833l2.27 2.27-2.745 1.586-6.778 3.914 7.253-7.77zm3.355-1.085l2.668 1.54a1.346 1.346 0 010 2.337l-2.668 1.54-2.522-2.708 2.522-2.709zm-3.355-1.083L7.187 2.71l6.778 3.914 2.745 1.586-2.27 2.269z"/>
                </svg>
              </div>
              <h3 className="text-2xl font-semibold font-mono text-omni-white mb-2">Android</h3>
              <p className="text-omni-grey mb-6">
                In Google Play closed testing. Join from the link below and the build
                installs through Play like any other app.
              </p>
              <a
                href={PLAY_TESTING_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="btn-primary inline-flex items-center justify-center gap-2"
              >
                Join the Play test
              </a>
              <p className="text-xs text-omni-grey-dark mt-4 font-mono">
                Or build from source. The repo is public.
              </p>
            </div>
          </motion.div>
        </div>

        {/* Open source */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="card p-8 text-center"
        >
          <div className="flex items-center justify-center gap-3 mb-4">
            <svg className="w-7 h-7 text-omni-grey-light" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
            </svg>
            <h3 className="text-xl font-semibold font-mono text-omni-white">Open source, Apache 2.0</h3>
          </div>
          <p className="text-omni-grey mb-6 max-w-2xl mx-auto">
            Both clients are public. Audit the code, build it yourself, file issues,
            or send a PR. Your team owns its picture and never rents it back.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 justify-center">
            <a
              href={GITHUB_IOS}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-secondary inline-flex items-center justify-center gap-2"
            >
              OmniTAK-iOS
            </a>
            <a
              href={GITHUB_ANDROID}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-secondary inline-flex items-center justify-center gap-2"
            >
              OmniTAK-Android
            </a>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
