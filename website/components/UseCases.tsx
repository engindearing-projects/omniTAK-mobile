'use client';

import { motion } from 'framer-motion';
import GlassCard from './GlassCard';

export default function UseCases() {
  const useCases = [
    {
      title: 'Search & Rescue',
      description: 'Coordinate multi-team search operations with real-time position sharing, waypoint navigation, and off-grid mesh communication.',
      color: 'from-orange-500 to-red-500',
    },
    {
      title: 'Military Operations',
      description: 'Full ATAK compatibility ensures seamless integration with existing TAK infrastructure for tactical coordination.',
      color: 'from-green-500 to-emerald-500',
    },
    {
      title: 'First Responders',
      description: 'Emergency services can deploy quickly with GeoChat, tactical mapping, and secure team communication.',
      color: 'from-blue-500 to-cyan-500',
    },
    {
      title: 'Disaster Response',
      description: 'When infrastructure fails, Meshtastic mesh networking keeps teams connected without cellular or WiFi.',
      color: 'from-purple-500 to-pink-500',
    },
  ];

  return (
    <section className="relative py-32 px-4">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-20">
          <h2 className="text-5xl md:text-6xl font-bold mb-6">
            <span className="text-gradient">Built For</span>
            <br />
            <span className="text-white">Real Missions</span>
          </h2>
          <p className="text-xl text-gray-400 max-w-2xl mx-auto">
            Deployed by professionals who can't afford to lose communication
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-8">
          {useCases.map((useCase, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, scale: 0.9 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1 }}
            >
              <GlassCard glow="teal">
                <h3 className="text-3xl font-bold mb-4 text-omni-olive">{useCase.title}</h3>
                <p className="text-omni-grey-light leading-relaxed">{useCase.description}</p>
                <div className={`h-1 bg-gradient-to-r ${useCase.color} mt-6 rounded-full`} />
              </GlassCard>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
