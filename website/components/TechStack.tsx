'use client';

import { motion } from 'framer-motion';
import GlassCard from './GlassCard';

export default function TechStack() {
  const technologies = [
    { name: 'SwiftUI', desc: 'Modern iOS UI', color: 'text-orange-500' },
    { name: 'Rust', desc: 'Core library', color: 'text-orange-600' },
    { name: 'TypeScript', desc: 'Android logic', color: 'text-blue-500' },
    { name: 'Kotlin', desc: 'Native Android', color: 'text-purple-500' },
    { name: 'MapKit', desc: 'iOS mapping', color: 'text-green-500' },
    { name: 'MapLibre', desc: 'Android maps', color: 'text-cyan-500' },
    { name: 'Bazel', desc: 'Build system', color: 'text-green-600' },
    { name: 'Meshtastic', desc: 'Mesh networking', color: 'text-pink-500' },
  ];

  return (
    <section className="relative py-32 px-4">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-5xl md:text-6xl font-bold mb-6">
            <span className="text-gradient">Cutting-Edge</span>
            <br />
            <span className="text-white">Technology</span>
          </h2>
          <p className="text-xl text-gray-400 max-w-2xl mx-auto">
            Built with modern tools for maximum performance and reliability
          </p>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
          {technologies.map((tech, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.05 }}
            >
              <GlassCard hover={true} glow="olive">
                <div className="text-center">
                  <div className={`text-3xl font-bold ${tech.color} mb-2`}>{tech.name}</div>
                  <div className="text-sm text-gray-400">{tech.desc}</div>
                </div>
              </GlassCard>
            </motion.div>
          ))}
        </div>

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="mt-16 text-center"
        >
          <GlassCard hover={false}>
            <div className="py-8">
              <h3 className="text-2xl font-bold mb-4 text-white">Open Standards</h3>
              <p className="text-gray-300 mb-6 max-w-2xl mx-auto">
                Full compliance with TAK CoT XML protocol, TLS 1.2/1.3 security standards,
                and support for industry-standard formats like KML/KMZ.
              </p>
              <div className="flex flex-wrap justify-center gap-4 text-sm font-mono">
                <span className="px-4 py-2 glass-dark rounded-full text-omni-teal">CoT XML</span>
                <span className="px-4 py-2 glass-dark rounded-full text-omni-teal">TLS 1.2/1.3</span>
                <span className="px-4 py-2 glass-dark rounded-full text-omni-teal">TCP/UDP</span>
                <span className="px-4 py-2 glass-dark rounded-full text-omni-teal">WebSocket</span>
                <span className="px-4 py-2 glass-dark rounded-full text-omni-teal">KML/KMZ</span>
                <span className="px-4 py-2 glass-dark rounded-full text-omni-teal">MGRS</span>
              </div>
            </div>
          </GlassCard>
        </motion.div>
      </div>
    </section>
  );
}
