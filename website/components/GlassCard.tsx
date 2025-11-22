'use client';

import { motion } from 'framer-motion';
import { ReactNode } from 'react';

interface GlassCardProps {
  children: ReactNode;
  className?: string;
  hover?: boolean;
  glow?: 'olive' | 'teal' | 'yellow' | 'cyan' | 'none';
}

export default function GlassCard({ children, className = '', hover = true, glow = 'none' }: GlassCardProps) {
  const glowClass = glow === 'olive' ? 'hover:glow-olive' :
                    glow === 'teal' ? 'hover:glow-teal' :
                    glow === 'yellow' ? 'hover:glow-olive' :
                    glow === 'cyan' ? 'hover:glow-teal' : '';

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5 }}
      whileHover={hover ? { scale: 1.02, y: -5 } : {}}
      className={`glass rounded-2xl p-6 ${glowClass} transition-all duration-300 ${className}`}
    >
      {children}
    </motion.div>
  );
}
