import Navigation from '@/components/Navigation';
import Hero from '@/components/Hero';
import Features from '@/components/Features';
import AppShowcase from '@/components/AppShowcase';
import Gyb from '@/components/Gyb';
import Studio from '@/components/Studio';
import Download from '@/components/Download';
import Footer from '@/components/Footer';

export default function Home() {
  return (
    <main className="relative bg-omni-base min-h-screen">
      {/* Brand treatment: emerald rail, faint grid, soft indigo glow */}
      <div className="brand-rail hidden md:block" />
      <div className="fixed inset-0 indigo-glow pointer-events-none" />
      <div className="fixed inset-0 grid-bg pointer-events-none" />

      <Navigation />

      <div className="relative z-10">
        <Hero />
        <div className="section-divider max-w-6xl mx-auto" />
        <Features />
        <div className="section-divider max-w-6xl mx-auto" />
        <AppShowcase />
        <div className="section-divider max-w-6xl mx-auto" />
        <Gyb />
        <div className="section-divider max-w-6xl mx-auto" />
        <Download />
        <Studio />
        <Footer />
      </div>
    </main>
  );
}
