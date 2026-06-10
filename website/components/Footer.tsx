'use client';

import Image from 'next/image';

const GITHUB_IOS = 'https://github.com/engindearing-projects/OmniTAK-iOS';
const GITHUB_ANDROID = 'https://github.com/engindearing-projects/OmniTAK-Android';

export default function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="relative py-16 px-6 border-t border-omni-border bg-omni-surface/50">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-2 md:grid-cols-5 gap-8 mb-12">
          {/* Brand */}
          <div className="col-span-2">
            <div className="flex items-center gap-3 mb-4">
              <Image
                src="/brand/crt_mark_white.svg"
                alt="Engindearing CRT mark"
                width={36}
                height={35}
                className="w-9 h-9"
              />
              <span className="text-xl font-bold font-mono text-omni-white">
                Omni<span className="text-omni-accent">TAK</span>
              </span>
            </div>
            <p className="text-sm text-omni-grey max-w-xs">
              Open-source TAK client for iOS and Android. One shared map for teams
              that work where the network does not.
            </p>
          </div>

          {/* Product */}
          <div>
            <h4 className="font-semibold font-mono text-omni-white mb-4">Product</h4>
            <ul className="space-y-3 text-sm">
              <li><a href="#features" className="text-omni-grey hover:text-omni-accent-light transition-colors">Features</a></li>
              <li><a href="#showcase" className="text-omni-grey hover:text-omni-accent-light transition-colors">Screenshots</a></li>
              <li><a href="#gyb" className="text-omni-grey hover:text-omni-accent-light transition-colors">gyb sensor</a></li>
              <li><a href="#download" className="text-omni-grey hover:text-omni-accent-light transition-colors">Download</a></li>
            </ul>
          </div>

          {/* Community */}
          <div>
            <h4 className="font-semibold font-mono text-omni-white mb-4">Community</h4>
            <ul className="space-y-3 text-sm">
              <li><a href="https://discord.gg/VSUjDddRt3" target="_blank" rel="noopener noreferrer" className="text-omni-grey hover:text-omni-accent-light transition-colors">Discord</a></li>
              <li><a href={`${GITHUB_IOS}/issues`} target="_blank" rel="noopener noreferrer" className="text-omni-grey hover:text-omni-accent-light transition-colors">iOS issues</a></li>
              <li><a href={`${GITHUB_ANDROID}/issues`} target="_blank" rel="noopener noreferrer" className="text-omni-grey hover:text-omni-accent-light transition-colors">Android issues</a></li>
            </ul>
          </div>

          {/* Source */}
          <div>
            <h4 className="font-semibold font-mono text-omni-white mb-4">Source</h4>
            <ul className="space-y-3 text-sm">
              <li><a href={GITHUB_IOS} target="_blank" rel="noopener noreferrer" className="text-omni-grey hover:text-omni-accent-light transition-colors">OmniTAK-iOS</a></li>
              <li><a href={GITHUB_ANDROID} target="_blank" rel="noopener noreferrer" className="text-omni-grey hover:text-omni-accent-light transition-colors">OmniTAK-Android</a></li>
              <li><a href="https://www.engindearing.soy/hire" target="_blank" rel="noopener noreferrer" className="text-omni-grey hover:text-omni-accent-light transition-colors">gyb detector</a></li>
              <li><a href={`${GITHUB_IOS}/blob/main/LICENSE`} target="_blank" rel="noopener noreferrer" className="text-omni-grey hover:text-omni-accent-light transition-colors">Apache 2.0 license</a></li>
            </ul>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="border-t border-omni-border pt-8 flex flex-col md:flex-row justify-between items-center gap-4">
          <div className="text-sm text-omni-grey-dark font-mono">
            © {currentYear} OmniTAK. Open source, Apache 2.0.
          </div>
          <div className="flex items-center gap-2 text-sm text-omni-grey-dark font-mono">
            <span>Built by</span>
            <a
              href="https://www.engindearing.soy"
              target="_blank"
              rel="noopener noreferrer"
              className="text-omni-accent hover:text-omni-accent-light transition-colors"
            >
              Engindearing
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
