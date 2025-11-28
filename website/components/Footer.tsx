'use client';

export default function Footer() {
  return (
    <footer className="relative py-16 px-4 border-t border-white/10">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-12 mb-12">
          <div>
            <h3 className="text-2xl font-bold text-gradient mb-4">OmniTAK</h3>
            <p className="text-gray-400 text-sm">
              Professional tactical awareness for mobile platforms.
            </p>
          </div>

          <div>
            <h4 className="font-bold mb-4 text-omni-olive">Product</h4>
            <ul className="space-y-2 text-sm">
              <li><a href="#features" className="text-omni-grey-light hover:text-omni-teal transition-colors">Features</a></li>
              <li><a href="#download" className="text-omni-grey-light hover:text-omni-teal transition-colors">Download</a></li>
              <li><a href="#changelog" className="text-omni-grey-light hover:text-omni-teal transition-colors">Changelog</a></li>
              <li><a href="https://github.com/engindearing-projects/omniTAK-mobile/blob/main/apps/omnitak/README.md" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">Documentation</a></li>
            </ul>
          </div>

          <div>
            <h4 className="font-bold mb-4 text-omni-olive">Community</h4>
            <ul className="space-y-2 text-sm">
              <li><a href="https://discord.gg/VSUjDddRt3" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">Discord</a></li>
              <li><a href="https://github.com/engindearing-projects/omniTAK-mobile" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">GitHub</a></li>
              <li><a href="https://github.com/engindearing-projects/omniTAK-mobile/issues" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">Issues</a></li>
              <li><a href="https://github.com/engindearing-projects/omniTAK-mobile/blob/main/CONTRIBUTING.md" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">Contributing</a></li>
              <li><a href="https://github.com/engindearing-projects/omniTAK-mobile/blob/main/CODE_OF_CONDUCT.md" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">Code of Conduct</a></li>
            </ul>
          </div>

          <div>
            <h4 className="font-bold mb-4 text-omni-olive">Developers</h4>
            <ul className="space-y-2 text-sm">
              <li><a href="https://github.com/engindearing-projects/omniTAK-mobile/blob/main/docs/PLUGIN_DEVELOPMENT_GUIDE.md" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">Plugin Development</a></li>
              <li><a href="https://github.com/engindearing-projects/omniTAK-mobile/blob/main/BUILD_ANDROID.md" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">Build Android</a></li>
              <li><a href="https://github.com/engindearing-projects/omniTAK-mobile/blob/main/DEPENDENCIES.md" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">Dependencies</a></li>
              <li><a href="https://github.com/engindearing-projects/omniTAK-mobile/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">MIT License</a></li>
            </ul>
          </div>

          <div>
            <h4 className="font-bold mb-4 text-omni-olive">Company</h4>
            <ul className="space-y-2 text-sm">
              <li><a href="https://www.engindearing.soy" target="_blank" rel="noopener noreferrer" className="text-omni-grey-light hover:text-omni-teal transition-colors">Engindearing</a></li>
            </ul>
          </div>
        </div>

        <div className="border-t border-white/10 pt-8 text-center text-sm text-gray-400">
          <p>© 2025 OmniTAK Mobile. Open source and MIT licensed.</p>
          <p className="mt-2">Built for tactical professionals and first responders worldwide.</p>
          <p className="mt-2">
            A project by <a href="https://www.engindearing.soy" target="_blank" rel="noopener noreferrer" className="text-omni-teal hover:text-omni-olive transition-colors font-medium">Engindearing</a>
          </p>
        </div>
      </div>
    </footer>
  );
}
