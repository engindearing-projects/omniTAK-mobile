# Contributing to OmniTAK

Welcome. We're thrilled you want to contribute. This guide will walk you through making your first contribution, even if you've never done it before.

## Quick Start: I Just Want to Fix a Typo

If you just want to fix a typo or make a small change:

1. **Click the "Edit" button** on GitHub (looks like a pencil)
2. **Make your change** in the browser
3. **Scroll down and click "Propose changes"**
4. **Click "Create pull request"**

Done. We'll review it and merge it. Easy.

## Making Your First Real Contribution

### Step 1: Get a Copy of the Code

**Option A: Using GitHub Desktop (Easiest)**

1. Download [GitHub Desktop](https://desktop.github.com/)
2. Install and sign in with your GitHub account
3. Click "Clone Repository from the Internet..."
4. Search for `omni-BASE` and click "Clone"
5. Choose where to save it on your computer

**Option B: Using Command Line**

```bash
git clone https://gitlab.com/engindearing/omni-BASE.git
cd omni-BASE
```

### Step 2: Make Your Change

Find the file you want to change and edit it with any text editor:
- **TextEdit** (Mac)
- **Notepad** (Windows)
- **VS Code** (recommended, free download)

Save your changes.
### Step 3: Test Your Changes (Optional but Nice)

If you changed code:
```bash
# Test it still builds
./scripts/build_ios.sh simulator debug
```

If you just changed documentation (like README.md), you're good to go.
### Step 4: Submit Your Changes

**Option A: Using GitHub Desktop**

1. Open GitHub Desktop
2. You'll see your changes listed
3. In the bottom left, type a short description like "Fix typo in README"
4. Click "Commit to main"
5. Click "Push origin"
6. Click "Create Pull Request"
7. Click "Create pull request" on the web page that opens

**Option B: Using Command Line**

```bash
# Save your changes
git add .
git commit -m "Fix typo in README"  # Describe what you changed
git push

# Then go to GitHub and click "Create Pull Request"
```

### Step 5: Wait for Review

We'll review your pull request within a few days and either:
- Merge it (yay!)
- Ask questions or request small changes
- Explain if we can't merge it (rare!)

## What Can You Contribute?

### Super Easy (No Coding Required!)

- **Fix typos** in README or documentation
- **Improve wording** to make things clearer
- **Add examples** to documentation
- **Report bugs** you found
- **Suggest features** you want

### Easy (Minimal Coding)

- **Add comments** to explain confusing code
- **Update configuration files** with better defaults
- **Add new documentation** files
- **Create example plugins**

### Medium (Some Coding)

- **Fix small bugs** you can figure out
- **Add unit tests** for existing code
- **Improve error messages**
- **Add logging** to help debug issues

### Advanced (More Coding)

- **Implement new features**
- **Refactor code** for better performance
- **Add Android support**
- **Create complex plugins**

## Plugin Contributions

Want to create a plugin? It's easy.
### Quick Plugin Contribution

```bash
# 1. Go to the plugin template
cd plugin-template

# 2. Copy the example and customize it
cp .bazelrc.local.example .bazelrc.local
# Edit .bazelrc.local with your Apple Developer Team ID

# 3. Edit plugin.json with your plugin info
nano plugin.json  # or use any text editor

# 4. Edit ios/Sources/PluginMain.swift with your code
nano ios/Sources/PluginMain.swift

# 5. Build it
./scripts/build_plugin_ios.sh simulator debug

# 6. Test it works.# ... integrate into OmniTAK and test ...

# 7. Submit it (same as above - commit and push)
git add .
git commit -m "Add my awesome plugin"
git push
```

See [Plugin Development Guide](docs/PLUGIN_DEVELOPMENT_GUIDE.md) for details.

## Before You Submit

Please check:

- [ ] **Did you test it?** (if code changed)
- [ ] **Did you explain what you changed?** (in commit message)
- [ ] **Is your code formatted nicely?** (readable, has comments)
- [ ] **Did you update documentation?** (if you added features)

Don't worry if you're not perfect - we'll help you improve it.

## Reporting Bugs

Found a bug? Help us fix it.
1. **Go to Issues** on GitHub
2. **Click "New Issue"**
3. **Tell us:**
   - What you expected to happen
   - What actually happened
   - Steps to reproduce it
   - Screenshots if helpful
4. **Click "Submit new issue"**

### Good Bug Report Example

```
Title: App crashes when switching servers

Description:
- I was on "Taky Server"
- I tapped the status bar to open server list
- I tapped "Switch" on "My Custom Server"
- App immediately crashed

Expected: Should switch to new server smoothly

Environment:
- iPhone 15 Pro
- iOS 17.5.1
- OmniTAK version 1.0.0

Screenshot: [attached]
```

## Suggesting Features

Have an idea? We'd love to hear it.
1. **Go to Issues** on GitHub
2. **Click "New Issue"**
3. **Select "Feature Request"** (if available)
4. **Tell us:**
   - What feature you want
   - Why it would be useful
   - How you imagine it working
5. **Click "Submit new issue"**

### Good Feature Request Example

```
Title: Add dark mode toggle

Description:
I'd love to have a dark mode option for night operations.

Currently the map is always in satellite view with a light UI,
which is bright at night.

Suggested implementation:
- Add a toggle in settings for "Dark Mode"
- When enabled, use dark colors for all UI elements
- Keep map in satellite view (already dark)
- Use yellow accents (already used) for visibility

This would be useful for:
- Night operations
- Battery saving
- Eye strain reduction

Happy to help test this if implemented.```

## Documentation Contributions

Documentation is code too. Help us make our docs better:

- **README.md** - Main project description
- **docs/PLUGIN_*.md** - Plugin system docs
- **plugin-template/README.md** - Plugin template docs
- **CONTRIBUTING.md** - This file.
### Making Docs Better

Good documentation:
- Uses simple language
- Has examples
- Has screenshots (for UI things)
- Explains *why*, not just *how*
- Assumes the reader is smart but new

Bad documentation:
- Uses lots of jargon
- Says "it's obvious" or "simply do X"
- Skips steps
- Has no examples
- Is condescending

## Code of Conduct

Be nice. Specifically:

- **Be respectful** - Everyone's learning
- **Be patient** - Reviews take time
- **Be constructive** - Suggest improvements, don't just criticize
- **Be welcoming** - Help newcomers
- **No harassment** - Treat everyone with respect
- **No spam** - Keep it relevant

## Learning Resources

New to contributing? Check these out:

### Git & GitHub
- [GitHub's Hello World Tutorial](https://guides.github.com/activities/hello-world/)
- [Git Basics](https://git-scm.com/book/en/v2/Getting-Started-Git-Basics)
- [How to Write a Good Commit Message](https://chris.beams.io/posts/git-commit/)

### iOS Development
- [Swift Programming Language](https://docs.swift.org/swift-book/)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios)
- [Bazel for iOS](https://bazel.build/tutorials/ios-app)

### TAK Protocol
- [TAK.gov](https://tak.gov/) - Official TAK resources
- [CoT Protocol](https://tak.gov/docs) - Cursor-on-Target docs

## Getting Help

Stuck? We're here to help.
- **Issues** - Ask questions in GitHub Issues
- **Discord** - Join our Discord (link in README)
- **Email** - Email us at support@omnitak.io

Questions are welcome. Don't be shy.

## Recognition

All contributors are added to:
- GitHub's contributor list (automatic)
- Special thanks in release notes (for significant contributions)

Your name will live forever in the git history.

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

This means:
- Your code will be free and open source
- Anyone can use it
- You keep credit for your contribution
- You're not liable if something breaks

## Advanced: Setting Up Development Environment

For serious contributors who want to make bigger changes:

### macOS Setup

```bash
# Install Xcode from Mac App Store

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Bazel
brew install bazel

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Clone and build
git clone https://gitlab.com/engindearing/omni-BASE.git
cd omni-BASE
./scripts/build_ios.sh simulator debug
```

### Configure Your Editor

We recommend **VS Code** with these extensions:
- Swift
- Rust Analyzer
- GitLens
- Prettier (for formatting)

### Code Style

We follow:
- **Swift**: [Swift Style Guide](https://google.github.io/swift/)
- **Rust**: Standard `rustfmt`
- **TypeScript**: Prettier with default settings

Run formatters before committing:
```bash
# Swift
swiftformat .

# Rust
cargo fmt

# TypeScript
npm run format
```

## Contribution Workflow

The complete flow for bigger contributions:

```
1. Fork the repo on GitHub
   ↓
2. Clone your fork to your computer
   ↓
3. Create a new branch: git checkout -b my-feature
   ↓
4. Make your changes
   ↓
5. Test your changes
   ↓
6. Commit: git commit -m "Add feature X"
   ↓
7. Push: git push origin my-feature
   ↓
8. Create Pull Request on GitHub
   ↓
9. Address review feedback (if any)
   ↓
10. Merged.
```

## Types of Contributions We Love

| Type | Difficulty | Impact | Examples |
|------|-----------|--------|----------|
| **Documentation** | ⭐ Easy |  High | Fix typos, add examples, improve clarity |
| **Bug Reports** | ⭐ Easy |  Very High | Find and report issues |
| **Bug Fixes** | ⭐⭐ Medium |  Very High | Fix reported issues |
| **Tests** | ⭐⭐ Medium |  Very High | Add unit/integration tests |
| **Plugins** | ⭐⭐ Medium |  High | Extend functionality |
| **Features** | ⭐⭐⭐ Hard |  Huge | Add new capabilities |
| **Architecture** | ⭐⭐⭐ Hard |  Very High | Refactor, optimize |

## Thank You

Every contribution, no matter how small, makes a difference. Whether you're fixing a typo or adding a major feature, we appreciate you taking the time to make OmniTAK better.

Welcome to the team.
---

**Questions?** Open an issue and ask - we're happy to help.
**Ready to contribute?** Pick an issue labeled `good first issue` to get started.