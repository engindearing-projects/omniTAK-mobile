'use client';

import { motion } from 'framer-motion';
import { useState, useEffect } from 'react';

export default function Navigation() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 50);
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <motion.nav
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled ? 'glass-dark shadow-lg' : 'bg-transparent'
      }`}
    >
      <div className="max-w-7xl mx-auto px-4 py-4">
        <div className="flex items-center justify-between">
          <motion.a
            href="#"
            className="text-2xl font-bold text-gradient"
            whileHover={{ scale: 1.05 }}
          >
            OmniTAK
          </motion.a>

          <div className="hidden md:flex items-center space-x-8">
            {[
              { name: 'Features', href: '#features' },
              { name: 'Technology', href: '#tech' },
              { name: 'Changelog', href: '#changelog' },
              { name: 'Download', href: '#download' },
            ].map((item) => (
              <motion.a
                key={item.name}
                href={item.href}
                className="text-omni-grey-light hover:text-omni-teal transition-colors font-medium"
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.95 }}
              >
                {item.name}
              </motion.a>
            ))}
            <motion.a
              href="https://github.com/engindearing-projects/omniTAK-mobile"
              target="_blank"
              rel="noopener noreferrer"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="px-6 py-2 glass rounded-full hover:glow-olive transition-all duration-300"
            >
              GitHub
            </motion.a>
          </div>

          {/* Mobile menu button */}
          <motion.button
            whileTap={{ scale: 0.95 }}
            className="md:hidden text-omni-olive"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </motion.button>
        </div>
      </div>
    </motion.nav>
  );
}
