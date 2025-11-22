'use client';

import { motion } from 'framer-motion';
import { ReactNode } from 'react';

interface FeatureCardProps {
  icon: ReactNode;
  title: string;
  description: string;
  delay?: number;
}

export default function FeatureCard({ icon, title, description, delay = 0 }: FeatureCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 50 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.6, delay }}
      whileHover={{ scale: 1.05, rotateY: 5 }}
      className="glass rounded-2xl p-8 hover:glow-teal transition-all duration-300 group cursor-pointer"
    >
      <motion.div
        whileHover={{ rotate: 360 }}
        transition={{ duration: 0.6 }}
        className="mb-4 text-omni-teal"
      >
        {icon}
      </motion.div>
      <h3 className="text-2xl font-bold mb-3 text-omni-olive">{title}</h3>
      <p className="text-omni-grey-light leading-relaxed">{description}</p>
      <motion.div
        initial={{ width: 0 }}
        whileHover={{ width: '100%' }}
        className="h-0.5 bg-gradient-to-r from-omni-olive to-omni-teal mt-4"
      />
    </motion.div>
  );
}
