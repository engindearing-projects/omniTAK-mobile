# Building OmniTAK Android

This guide covers two methods for building the Android APK.

## Prerequisites

- **macOS**: iOS builds work natively
- **Android builds**: Require Linux (use Docker or CI/CD)

## Method 1: Docker Build (Local on macOS) ⭐

### Setup

1. **Install Docker Desktop**
   - Download from https://www.docker.com/products/docker-desktop
   - Start Docker Desktop

2. **Build the Android APK**
   ```bash
   ./build-android-docker.sh
   ```

   This script will:
   - Build a Linux Docker image with Android SDK/NDK, Bazel, and Rust
   - Compile Rust native libraries for all Android architectures
   - Build the APK with Bazel
   - Output: `build-output/omnitak_android.apk`

3. **First build takes ~20-30 minutes** (downloads dependencies)
   - Subsequent builds are much faster (cached)

### Troubleshooting Docker

**Docker not running**
```bash
# Start Docker Desktop from Applications
open -a Docker
```

**Out of disk space**
```bash
# Clean up Docker
docker system prune -a
```

**Build failed**
```bash
# Clean and rebuild
docker-compose down -v
./build-android-docker.sh
```

## Method 2: GitLab CI/CD (Automatic) 🚀

### Setup GitLab CI/CD

1. **Push to GitLab**
   ```bash
   cd ~/omniTAK-mobile

   # If not already set up
   git remote add origin <your-gitlab-repo-url>

   # Push your code
   git add .
   git commit -m "Setup Android build"
   git push origin main
   ```

2. **The CI pipeline will automatically:**
   - Setup build environment (Bazel, Rust, Android SDK/NDK)
   - Build Rust native libraries
   - Build the Android APK
   - Store APK as artifact (download from GitLab UI)

3. **View build progress:**
   - Go to your GitLab project
   - Navigate to: **CI/CD → Pipelines**
   - Click on the running pipeline to see logs

4. **Download the APK:**
   - Wait for pipeline to complete
   - Click **Download artifacts** on the pipeline page
   - APK will be in: `build-outputs/omnitak-debug.apk`

### GitLab Runner (Optional - For Private Repos)

If you have a private GitLab instance, you might need to set up a runner:

```bash
# On a Linux machine with Docker
docker run -d --name gitlab-runner --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v gitlab-runner-config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest

# Register the runner
docker exec -it gitlab-runner gitlab-runner register
# Follow prompts:
# - GitLab URL: https://gitlab.com
# - Token: (from GitLab project Settings → CI/CD → Runners)
# - Executor: docker
# - Default image: mingc/android-build-box:latest
```

## Comparison

| Method | Build Time (First) | Build Time (Cached) | Setup Difficulty |
|--------|-------------------|---------------------|------------------|
| **Docker** | ~30 min | ~5 min | Easy (install Docker) |
| **CI/CD** | ~25 min | ~5 min | Easy (git push) |

## iOS Building (Works Natively on macOS)

```bash
# Build iOS
cd ~/omniTAK-mobile/apps/omnitak
xcodebuild -project OmniTAKMobile.xcodeproj -scheme OmniTAKMobile -sdk iphonesimulator clean build

# Or open in Xcode
open OmniTAKMobile.xcodeproj
```

## Quick Reference

```bash
# Docker build
./build-android-docker.sh

# iOS build (Xcode)
open ~/omniTAK-mobile/apps/omnitak/OmniTAKMobile.xcodeproj

# CI/CD build
git push origin main
# Then download APK from GitLab Pipelines

# View build status
cd ~/omniTAK-mobile
ls -lh build-output/  # Docker output
```

## Troubleshooting

### "Bazel cache too large"
```bash
# Clean Bazel cache
docker-compose run --rm android-builder bazel clean --expunge
```

### "Rust compilation failed"
```bash
# Rebuild from scratch
docker-compose down -v
rm -rf crates/target
./build-android-docker.sh
```

### "APK not found after build"
```bash
# Check Bazel output
docker-compose run --rm android-builder ls -la bazel-bin/apps/omnitak_android/
```

## Support

- **iOS issues**: Works natively - check Xcode console
- **Android Docker issues**: Check `docker-compose logs`
- **CI/CD issues**: Check GitLab pipeline logs
