# Deployment Guide

This guide covers deploying the OmniTAK promotional website to Vercel.

## Prerequisites

- GitHub account
- Vercel account (free tier works great)
- Git repository pushed to GitHub

## Deploy to Vercel

### Option 1: Vercel Dashboard (Recommended)

1. **Connect Repository**
   - Go to [vercel.com](https://vercel.com)
   - Click "Add New Project"
   - Import your GitHub repository

2. **Configure Project** ⚠️ **CRITICAL: Root Directory MUST be set to `website`**
   - **Framework Preset**: Next.js
   - **Root Directory**: `website` ← **REQUIRED! The website code is in a subdirectory**
   - **Build Command**: Leave as default (auto-detected from vercel.json)
   - **Output Directory**: Leave as default (auto-detected from vercel.json)
   - **Install Command**: Leave as default (auto-detected from vercel.json)

3. **Environment Variables**
   - No environment variables required for basic deployment
   - The changelog API automatically reads from `../CHANGELOG.md`

4. **Deploy**
   - Click "Deploy"
   - Vercel will build and deploy automatically
   - You'll get a production URL like `omnitak.vercel.app`

### Option 2: Vercel CLI

1. **Install Vercel CLI**
   ```bash
   npm install -g vercel
   ```

2. **Navigate to website directory**
   ```bash
   cd website
   ```

3. **Deploy**
   ```bash
   vercel
   ```

4. **Follow prompts**
   - Link to existing project or create new
   - Confirm settings
   - Deploy!

## Custom Domain

### Add Custom Domain in Vercel

1. Go to your project in Vercel Dashboard
2. Click "Settings" → "Domains"
3. Add your custom domain (e.g., `omnitak.com`)
4. Follow DNS configuration instructions
5. Vercel automatically provisions SSL certificate

### Example DNS Configuration

For apex domain:
```
Type: A
Name: @
Value: 76.76.21.21
```

For www subdomain:
```
Type: CNAME
Name: www
Value: cname.vercel-dns.com
```

## Automatic Deployments

Vercel automatically deploys:

- **Production**: Every push to `main` branch
- **Preview**: Every push to feature branches
- **Comments**: Preview URLs posted to PRs

### Configure Auto-Deploy Branches

In Vercel Dashboard:
1. Go to Settings → Git
2. Configure production branch (default: `main`)
3. Enable/disable preview deployments

## Changelog Updates

The website automatically pulls from `CHANGELOG.md` in the root of the repository:

1. Edit `/CHANGELOG.md` in your repository
2. Push changes to GitHub
3. Vercel automatically rebuilds
4. New changelog appears on website

Format CHANGELOG.md like this:

```markdown
# Changelog

## [1.2.0] - 2024-01-20

- Added new feature X
- Fixed bug Y
- Improved performance Z

## [1.1.0] - 2024-01-15

- Initial release
```

## Build Settings

The `vercel.json` in the root directory configures:

```json
{
  "buildCommand": "cd website && npm install && npm run build",
  "outputDirectory": "website/.next",
  "installCommand": "cd website && npm install"
}
```

You can also configure these in the Vercel Dashboard under Settings → General.

## Performance Optimization

The website is already optimized:

- ✅ Static generation for fast loads
- ✅ Automatic image optimization
- ✅ Edge caching
- ✅ Brotli compression
- ✅ HTTP/2 & HTTP/3

Vercel handles all of this automatically!

## Monitoring

### Analytics

Enable Vercel Analytics:
1. Go to your project
2. Click "Analytics" tab
3. Enable "Web Analytics"
4. Free tier: 100k pageviews/month

### Build Logs

View build logs:
1. Go to "Deployments"
2. Click on any deployment
3. View "Building" logs
4. Debug any build issues

## Troubleshooting

### Build Failures

**Error: Cannot find module**
- Make sure all dependencies are in `package.json`
- Run `npm install` locally first
- Check Node.js version compatibility

**Changelog not loading**
- Verify `CHANGELOG.md` exists in repository root
- Check file format matches expected structure
- View build logs for errors

**Styles not loading**
- Clear Vercel cache: Settings → General → "Clear Cache"
- Rebuild from dashboard

### Preview Deployments

Every PR gets a preview URL:
- Test changes before merging
- Share with team for review
- Automatic cleanup after PR merge

## Environment Variables (Future)

If you add features requiring secrets:

1. Go to Settings → Environment Variables
2. Add variables for:
   - `Production` - Live site
   - `Preview` - PR previews
   - `Development` - Local dev

Example:
```
Name: NEXT_PUBLIC_API_URL
Value: https://api.example.com
```

## Rollback

To rollback to previous deployment:

1. Go to "Deployments"
2. Find working deployment
3. Click "..." menu
4. Select "Promote to Production"

## Resources

- [Vercel Documentation](https://vercel.com/docs)
- [Next.js Deployment](https://nextjs.org/docs/deployment)
- [Custom Domains](https://vercel.com/docs/concepts/projects/domains)

## Support

- Vercel Support: https://vercel.com/support
- GitHub Issues: https://github.com/engindearing-projects/omniTAK-mobile/issues
