'use client';

import { motion } from 'framer-motion';
import { useEffect, useState } from 'react';
import GlassCard from './GlassCard';

interface ChangelogEntry {
  version: string;
  date: string;
  changes: string[];
}

export default function Changelog() {
  const [changelog, setChangelog] = useState<ChangelogEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/changelog')
      .then(res => res.json())
      .then(data => {
        setChangelog(data.slice(0, 5)); // Show only latest 5 versions
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <section id="changelog" className="relative py-32 px-4">
        <div className="max-w-5xl mx-auto text-center">
          <div className="text-omni-teal">Loading changelog...</div>
        </div>
      </section>
    );
  }

  return (
    <section id="changelog" className="relative py-32 px-4">
      <div className="max-w-5xl mx-auto">
        <div className="text-center mb-20">
          <h2 className="text-5xl md:text-6xl font-bold mb-6">
            <span className="text-gradient">Latest</span>
            <br />
            <span className="text-white">Updates</span>
          </h2>
          <p className="text-xl text-gray-400">
            Continuous improvements and new features
          </p>
        </div>

        <div className="space-y-6">
          {changelog.map((entry, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, x: -50 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1 }}
            >
              <GlassCard hover={false} glow="teal">
                <div className="flex flex-col md:flex-row md:items-start md:justify-between mb-4">
                  <h3 className="text-2xl font-bold text-omni-olive">{entry.version}</h3>
                  <span className="text-sm text-omni-grey-light font-mono">{entry.date}</span>
                </div>
                <ul className="space-y-2">
                  {entry.changes.map((change, j) => (
                    <li key={j} className="flex items-start">
                      <span className="text-omni-teal mr-2">▸</span>
                      <span className="text-omni-grey-light">{change}</span>
                    </li>
                  ))}
                </ul>
              </GlassCard>
            </motion.div>
          ))}
        </div>

        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          className="text-center mt-12"
        >
          <a
            href="https://github.com/engindearing-projects/omniTAK-mobile/blob/main/CHANGELOG.md"
            target="_blank"
            rel="noopener noreferrer"
            className="text-omni-teal hover:text-omni-olive transition-colors font-mono"
          >
            View Full Changelog →
          </a>
        </motion.div>
      </div>
    </section>
  );
}
