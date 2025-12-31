# OmniTAK Plugin CI/CD Setup Guide

Guide for setting up GitLab CI/CD for plugin builds, signing, and publishing.

## Overview

The OmniTAK plugin system uses GitLab CI/CD to automatically:
1. Validate plugin manifest and structure
2. Build plugin for iOS
3. Run tests
4. Code sign with OmniTAK developer keys
5. Package into .omniplugin bundle
6. Publish to plugin registry

## GitLab Setup

### 1. Create Plugin Repository

1. Go to GitLab: https://gitlab.com
2. Create new project
3. Name: `omnitak-plugin-yourname`
4. Visibility: Private (recommended) or Public
5. Initialize with README: No (we'll push template)

### 2. Push Plugin Template

```bash
# Clone template
git clone https://github.com/engindearing-projects/omniTAK-mobile/tree/main/plugin-template.git my-plugin
cd my-plugin

# Update remote
git remote remove origin
git remote add origin https://gitlab.com/yourgroup/omnitak-plugin-yourname.git

# Push
git push -u origin main
```

### 3. Configure GitLab Runner

For iOS builds, you need a macOS runner.

#### Option A: Use Shared macOS Runner (Recommended)

If your GitLab group has shared macOS runners, add tags to your `.gitlab-ci.yml`:

```yaml
build_ios:
  tags:
    - macos
    - xcode
```

#### Option B: Set Up Your Own Runner

Install GitLab Runner on a Mac:

```bash
# Install GitLab Runner
brew install gitlab-runner

# Register runner
gitlab-runner register \
  --url https://gitlab.com/ \
  --registration-token YOUR_TOKEN \
  --executor shell \
  --description "macOS iOS Builder" \
  --tag-list "macos,xcode,ios"

# Start runner
gitlab-runner start
```

## CI/CD Variables

Configure these variables at the GitLab group or project level.

### Navigate to CI/CD Settings

1. Go to your GitLab group or project
2. Settings → CI/CD
3. Variables → Expand
4. Add variables

### Required Variables

#### 1. IOS_SIGNING_CERT

Base64-encoded Apple Developer certificate (P12 format).

**Generate:**

```bash
# Export certificate from Keychain
# File → Export → Select certificate → Save as .p12

# Base64 encode
base64 -i certificate.p12 -o certificate.txt

# Copy contents of certificate.txt
cat certificate.txt
```

**Add to GitLab:**
- Key: `IOS_SIGNING_CERT`
- Value: (paste base64 string)
- Type: Variable
- Protected: Yes
- Masked: No (too long to mask)
- Environment scope: All

#### 2. IOS_SIGNING_CERT_PASSWORD

Password for the P12 certificate.

**Add to GitLab:**
- Key: `IOS_SIGNING_CERT_PASSWORD`
- Value: (certificate password)
- Type: Variable
- Protected: Yes
- Masked: Yes
- Environment scope: All

#### 3. IOS_PROVISIONING_PROFILE

Base64-encoded provisioning profile.

**Generate:**

```bash
# Get provisioning profile from Apple Developer Portal
# Download .mobileprovision file

# Base64 encode
base64 -i profile.mobileprovision -o profile.txt

# Copy contents
cat profile.txt
```

**Add to GitLab:**
- Key: `IOS_PROVISIONING_PROFILE`
- Value: (paste base64 string)
- Type: Variable
- Protected: Yes
- Masked: No
- Environment scope: All

#### 4. PLUGIN_REGISTRY_TOKEN

GitLab access token for publishing to package registry.

**Generate:**

1. GitLab → User Settings → Access Tokens
2. Name: `Plugin Publishing`
3. Scopes: `api`, `write_repository`, `read_repository`
4. Expiration: 1 year
5. Create token
6. Copy token

**Add to GitLab:**
- Key: `PLUGIN_REGISTRY_TOKEN`
- Value: (paste token)
- Type: Variable
- Protected: Yes
- Masked: Yes
- Environment scope: All

#### 5. CODE_SIGNING_IDENTITY (Optional)

Name of the signing certificate.

**Add to GitLab:**
- Key: `CODE_SIGNING_IDENTITY`
- Value: `Apple Development` or `Apple Distribution`
- Type: Variable
- Protected: No
- Masked: No
- Environment scope: All

## Apple Developer Portal Setup

### 1. Create App ID

1. Go to https://developer.apple.com
2. Certificates, Identifiers & Profiles
3. Identifiers → App IDs → +
4. Description: `OmniTAK Plugin - YourPlugin`
5. Bundle ID: `com.engindearing.omnitak.plugin.yourplugin`
6. Capabilities: (select what your plugin needs)
7. Continue → Register

### 2. Create Provisioning Profile

1. Profiles → +
2. Development or Distribution
3. App ID: Select your plugin's App ID
4. Select Certificates: Choose OmniTAK development certificate
5. Select Devices: (for development) or skip (for distribution)
6. Profile Name: `OmniTAK Plugin YourPlugin`
7. Generate → Download

### 3. Share Certificate (If Needed)

If you need to use the same certificate across multiple machines/projects:

1. Export from Keychain (File → Export)
2. Save as P12 with password
3. Share securely with team
4. Import on other machines

**Security Note:** Protect your certificates! Anyone with the certificate can sign apps as you.

## Pipeline Configuration

### Pipeline Stages

The `.gitlab-ci.yml` defines these stages:

```yaml
stages:
  - validate   # Check manifest and structure
  - build      # Compile plugin
  - test       # Run tests
  - sign       # Code sign
  - package    # Create .omniplugin bundle
  - publish    # Upload to registry
```

### Stage Details

#### Validate Stage

- Runs on: All branches and tags
- Script: `scripts/validate_plugin.py`
- Checks: Manifest format, required files, permissions

#### Build Stage

- Runs on: All branches and tags
- Script: `scripts/build_plugin_ios.sh`
- Output: `bazel-bin/ios/MyPlugin.framework`
- Modes: `debug` (branches) and `release` (main/tags)

#### Test Stage

- Runs on: All branches and tags
- Script: `scripts/test_plugin_ios.sh`
- Coverage: Reported in merge requests

#### Sign Stage

- Runs on: **main branch and tags only**
- Script: `scripts/sign_plugin_ios.sh`
- Uses: CI/CD variables for certificate and profile
- Output: Signed framework in `dist/signed/`

#### Package Stage

- Runs on: **main branch and tags only**
- Script: `scripts/package_plugin.sh`
- Output: `.omniplugin` bundle in `dist/`

#### Publish Stage

- Runs on: **tags only**
- Uploads to GitLab Package Registry
- URL: `${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${PLUGIN_ID}/${VERSION}/`

### Customizing Pipeline

Edit `.gitlab-ci.yml` carefully. Common customizations:

#### Change Runner Tags

```yaml
build_ios:
  tags:
    - your-runner-tag
```

#### Add Notifications

```yaml
publish:
  after_script:
    - 'curl -X POST https://hooks.slack.com/... -d "Plugin published!"'
```

#### Add Deployment

```yaml
deploy:
  stage: deploy
  script:
    - ./scripts/deploy_to_production.sh
  only:
    - tags
```

## Workflow

### Development Workflow

```
Developer → Push to branch → CI validates & builds → Merge request
```

1. Developer creates feature branch
2. Pushes commits
3. CI runs validate, build, test stages
4. Developer creates merge request
5. Code review
6. Merge to main

### Release Workflow

```
Main branch → Tag → CI signs, packages, publishes → Plugin Registry
```

1. Merge approved changes to main
2. CI runs all stages (including sign, package)
3. Developer creates version tag
4. CI publishes to registry
5. Plugin available for installation

### Branch Protection

Recommended branch protection rules:

1. GitLab → Settings → Repository → Protected Branches
2. Protect `main` branch:
   - Allowed to push: Maintainers
   - Allowed to merge: Maintainers
   - Require pipeline success before merge: Yes
   - Require approval before merge: Yes (1+ approvers)

## Troubleshooting

### Build Fails: "Bazel not found"

**Solution:** Install Bazel on runner

```bash
brew install bazel
```

### Build Fails: "Xcode not found"

**Solution:** Install Xcode Command Line Tools

```bash
xcode-select --install
```

### Sign Fails: "Certificate not found"

**Solution:** Check CI/CD variables

1. Verify `IOS_SIGNING_CERT` is set
2. Verify `IOS_SIGNING_CERT_PASSWORD` is correct
3. Check certificate expiration

### Sign Fails: "Profile doesn't match certificate"

**Solution:** Regenerate provisioning profile

1. Apple Developer Portal → Profiles
2. Delete old profile
3. Create new profile with correct certificate
4. Update `IOS_PROVISIONING_PROFILE` variable

### Publish Fails: "403 Forbidden"

**Solution:** Check registry token

1. Verify `PLUGIN_REGISTRY_TOKEN` is set
2. Check token has `api` and `write_repository` scopes
3. Verify token hasn't expired

### Pipeline Slow: "Bazel download takes forever"

**Solution:** Cache Bazel artifacts

Add to `.gitlab-ci.yml`:

```yaml
.cache_template: &cache_template
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - bazel-cache/

build_ios:
  <<: *cache_template
  before_script:
    - export BAZEL_CACHE_DIR=bazel-cache
```

## Security Best Practices

### 1. Protect Variables

- Mark sensitive variables as "Protected"
- Mark passwords/tokens as "Masked"
- Limit environment scope when possible

### 2. Limit Runner Access

- Use specific runner tags
- Restrict runner to protected branches
- Don't share runners between untrusted projects

### 3. Audit Access

- Regularly review who has access to:
  - GitLab project
  - CI/CD variables
  - Runners
  - Apple Developer account

### 4. Rotate Credentials

- Rotate access tokens every 6-12 months
- Update certificates before expiration
- Review and revoke unused credentials

### 5. Monitor Pipeline

- Watch for unexpected builds
- Review pipeline logs for sensitive data
- Set up alerts for failed pipelines

## Support

- **GitLab CI/CD Docs**: https://docs.gitlab.com/ee/ci/
- **OmniTAK Plugin Docs**: https://docs.omnitak.io/plugins
- **Issues**: https://github.com/engindearing-projects/omniTAK-mobile/tree/main/plugin-template/issues
- **Email**: plugins@omnitak.io
