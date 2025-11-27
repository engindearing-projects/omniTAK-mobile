'use client';

import { motion } from 'framer-motion';
import GlassCard from './GlassCard';

export default function Download() {
  return (
    <section id="download" className="relative py-32 px-4">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-5xl md:text-6xl font-bold mb-6">
            <span className="text-gradient">Get</span>
            <br />
            <span className="text-white">OmniTAK</span>
          </h2>
          <p className="text-xl text-gray-400 max-w-2xl mx-auto">
            Available on iOS and Android. Deploy to your team today.
          </p>
        </div>

        {/* TestFlight Early Access Banner */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="mb-12"
        >
          <div className="relative overflow-hidden rounded-2xl">
            {/* Animated gradient border */}
            <div className="absolute inset-0 bg-gradient-to-r from-omni-olive via-omni-teal to-omni-olive bg-[length:200%_100%] animate-gradient-x rounded-2xl" />
            <div className="relative m-[2px] bg-omni-black rounded-2xl p-8">
              <div className="flex flex-col md:flex-row items-center justify-between gap-6">
                <div className="flex items-center gap-4">
                  <div className="relative">
                    <motion.div
                      animate={{
                        boxShadow: [
                          '0 0 20px rgba(95,171,165,0.5)',
                          '0 0 40px rgba(95,171,165,0.8)',
                          '0 0 20px rgba(95,171,165,0.5)',
                        ],
                      }}
                      transition={{ duration: 2, repeat: Infinity }}
                      className="w-16 h-16 bg-gradient-to-br from-omni-teal to-omni-olive rounded-xl flex items-center justify-center"
                    >
                      <svg className="w-10 h-10 text-white" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                      </svg>
                    </motion.div>
                    <span className="absolute -top-1 -right-1 px-2 py-0.5 bg-omni-teal text-xs font-bold rounded-full text-white">BETA</span>
                  </div>
                  <div className="text-left">
                    <h3 className="text-2xl font-bold text-white mb-1">Get Early Access via TestFlight</h3>
                    <p className="text-gray-400">
                      Test new features <span className="text-omni-teal font-semibold">48 hours before</span> they hit the App Store
                    </p>
                  </div>
                </div>
                <motion.a
                  href="https://testflight.apple.com/join/SzxQGmMM"
                  target="_blank"
                  rel="noopener noreferrer"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="px-8 py-4 bg-gradient-to-r from-omni-teal to-omni-olive text-white font-bold rounded-full hover:shadow-2xl transition-all duration-300 glow-teal whitespace-nowrap flex items-center gap-2"
                >
                  <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                  </svg>
                  Join TestFlight
                </motion.a>
              </div>
            </div>
          </div>
        </motion.div>

        <div className="grid md:grid-cols-2 gap-8 mb-16">
          <motion.div
            initial={{ opacity: 0, x: -50 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
          >
            <GlassCard glow="olive" className="h-full">
              <div className="flex flex-col items-center text-center p-4">
                <svg className="w-20 h-20 text-omni-olive mb-6" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                </svg>
                <h3 className="text-3xl font-bold mb-4 text-white">iOS</h3>
                <p className="text-omni-grey-light mb-8">
                  Available on the App Store. Requires iOS 15.0 or later.
                </p>
                <motion.a
                  href="https://apps.apple.com/us/app/omnitakmobile/id6755246992"
                  target="_blank"
                  rel="noopener noreferrer"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="px-8 py-4 bg-omni-olive text-white font-bold rounded-full hover:shadow-2xl transition-all duration-300 glow-olive inline-block"
                >
                  Download on App Store
                </motion.a>
              </div>
            </GlassCard>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 50 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
          >
            <GlassCard glow="teal" className="h-full">
              <div className="flex flex-col items-center text-center p-4">
                <svg className="w-20 h-20 text-omni-teal mb-6" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M17.523 15.341l-5.155 2.98a.734.734 0 01-.369.099.734.734 0 01-.368-.1l-5.155-2.98a.734.734 0 010-1.269l5.155-2.98a.734.734 0 01.737 0l5.155 2.98a.734.734 0 010 1.27M2.994 15.341l-.734-.635V8.564l.734-.634 5.155 2.98v1.902l-5.155 2.529zm18.012 0l-5.155-2.529v-1.902l5.155-2.98.734.634v6.142l-.734.635zM12 1.583L3.728 6.341v9.317L12 20.417l8.272-4.759V6.341L12 1.583z"/>
                </svg>
                <h3 className="text-3xl font-bold mb-4 text-white">Android</h3>
                <p className="text-omni-grey-light mb-8">
                  Coming soon. Built with Valdi framework and Bazel.
                </p>
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="px-8 py-4 bg-omni-teal text-white font-bold rounded-full hover:shadow-2xl transition-all duration-300 glow-teal opacity-50 cursor-not-allowed"
                  disabled
                >
                  Coming Soon
                </motion.button>
              </div>
            </GlassCard>
          </motion.div>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
        >
          <GlassCard hover={false}>
            <div className="text-center">
              <h3 className="text-2xl font-bold mb-4 text-white">Open Source</h3>
              <p className="text-gray-300 mb-6">
                OmniTAK is open source and MIT licensed. Contribute, fork, or build your own plugins.
              </p>
              <motion.a
                href="https://github.com/engindearing-projects/omniTAK-mobile"
                target="_blank"
                rel="noopener noreferrer"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="inline-flex items-center px-6 py-3 glass rounded-full font-bold hover:glow-olive transition-all duration-300"
              >
                <svg className="w-6 h-6 mr-2" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                </svg>
                View on GitHub
              </motion.a>
            </div>
          </GlassCard>
        </motion.div>
      </div>
    </section>
  );
}
