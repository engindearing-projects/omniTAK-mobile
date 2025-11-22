'use client';

import { motion } from 'framer-motion';
import AnimatedText from './AnimatedText';

export default function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden px-4">
      {/* Animated gradient orbs */}
      <div className="absolute top-20 left-10 w-96 h-96 bg-omni-olive/20 rounded-full blur-3xl animate-float" />
      <div className="absolute bottom-20 right-10 w-96 h-96 bg-omni-teal/20 rounded-full blur-3xl animate-float" style={{ animationDelay: '3s' }} />

      <div className="relative z-10 max-w-7xl mx-auto text-center">
        <motion.div
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 1 }}
          className="mb-8"
        >
          <motion.div
            animate={{
              boxShadow: [
                '0 0 20px rgba(107,124,90,0.3)',
                '0 0 60px rgba(95,171,165,0.5)',
                '0 0 20px rgba(107,124,90,0.3)',
              ],
            }}
            transition={{ duration: 3, repeat: Infinity }}
            className="inline-block px-6 py-3 rounded-full glass mb-6"
          >
            <span className="text-omni-teal font-mono text-sm">ATAK-COMPATIBLE · TACTICAL · MISSION-READY</span>
          </motion.div>
        </motion.div>

        <AnimatedText delay={0.2}>
          <h1 className="text-6xl md:text-8xl font-bold mb-6 leading-tight">
            <span className="text-gradient">OmniTAK</span>
            <br />
            <span className="text-white">Mobile</span>
          </h1>
        </AnimatedText>

        <AnimatedText delay={0.4}>
          <p className="text-xl md:text-2xl text-gray-300 mb-12 max-w-3xl mx-auto">
            Professional tactical awareness for mobile platforms. Real-time team coordination,
            off-grid communication, and mission-critical situational awareness.
          </p>
        </AnimatedText>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6, duration: 0.8 }}
          className="flex flex-col sm:flex-row gap-4 justify-center items-center"
        >
          <motion.a
            href="#download"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            className="px-8 py-4 bg-gradient-to-r from-omni-olive to-omni-teal text-white font-bold rounded-full hover:shadow-2xl transition-all duration-300 glow-olive"
          >
            Download Now
          </motion.a>
          <motion.a
            href="#features"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            className="px-8 py-4 glass rounded-full font-bold hover:glow-teal transition-all duration-300"
          >
            Explore Features
          </motion.a>
        </motion.div>

        {/* Floating stats */}
        <motion.div
          initial={{ opacity: 0, y: 50 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8, duration: 0.8 }}
          className="mt-20 grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto"
        >
          {[
            { label: 'ATAK Compatible', value: '100%' },
            { label: 'Off-Grid Ready', value: 'Mesh' },
            { label: 'Platforms', value: 'iOS + Android' },
          ].map((stat, i) => (
            <motion.div
              key={i}
              whileHover={{ scale: 1.05 }}
              className="glass rounded-xl p-6 hover:glow-olive transition-all duration-300"
            >
              <div className="text-4xl font-bold text-gradient mb-2">{stat.value}</div>
              <div className="text-omni-grey-light text-sm font-mono">{stat.label}</div>
            </motion.div>
          ))}
        </motion.div>
      </div>

      {/* Scroll indicator */}
      <motion.div
        animate={{ y: [0, 10, 0] }}
        transition={{ duration: 1.5, repeat: Infinity }}
        className="absolute bottom-10 left-1/2 transform -translate-x-1/2"
      >
        <div className="w-6 h-10 border-2 border-omni-teal rounded-full flex justify-center">
          <motion.div
            animate={{ y: [0, 12, 0] }}
            transition={{ duration: 1.5, repeat: Infinity }}
            className="w-1.5 h-1.5 bg-omni-teal rounded-full mt-2"
          />
        </div>
      </motion.div>
    </section>
  );
}
