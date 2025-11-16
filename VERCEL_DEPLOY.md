# Deploying ArtYug to Vercel

This guide will help you deploy your Flutter web app to Vercel.

## Prerequisites

1. A Vercel account (sign up at [vercel.com](https://vercel.com))
2. Vercel CLI installed (optional, for CLI deployment)
3. Git repository (recommended)

## Deployment Methods

### Method 1: Deploy via Vercel Dashboard (Recommended)

1. **Push your code to GitHub/GitLab/Bitbucket**
   ```bash
   git add .
   git commit -m "Configure for Vercel deployment"
   git push origin main
   ```

2. **Import Project in Vercel**
   - Go to [vercel.com/new](https://vercel.com/new)
   - Import your Git repository
   - Vercel will auto-detect the Flutter project

3. **Configure Build Settings**
   - Framework Preset: Other
   - Build Command: `bash build.sh` (or `flutter build web --release` if Flutter is pre-installed)
   - Output Directory: `build/web`
   - Install Command: (leave empty, build script handles it)
   
   **Note:** If Vercel doesn't have Flutter pre-installed, the `build.sh` script will install it automatically.

4. **Environment Variables** (if needed)
   - If you need to use environment variables for API keys:
     - Go to Project Settings → Environment Variables
     - Add any required variables
   - Note: Currently, Supabase config is in `lib/config/supabase_config.dart`

5. **Deploy**
   - Click "Deploy"
   - Wait for the build to complete
   - Your app will be live at `your-project.vercel.app`

### Method 2: Deploy via Vercel CLI

1. **Install Vercel CLI**
   ```bash
   npm i -g vercel
   ```

2. **Login to Vercel**
   ```bash
   vercel login
   ```

3. **Deploy**
   ```bash
   cd flutter_app
   vercel
   ```

4. **For Production Deployment**
   ```bash
   vercel --prod
   ```

## Configuration Files

- `vercel.json` - Vercel configuration with build settings and routing
- `.vercelignore` - Files to exclude from deployment

## Build Output

The Flutter web build outputs to `build/web/`, which Vercel serves as static files.

## Custom Domain

1. Go to your project settings in Vercel
2. Navigate to "Domains"
3. Add your custom domain
4. Follow DNS configuration instructions

## Troubleshooting

### Build Fails
- Ensure Flutter is installed on Vercel's build environment
- Check that all dependencies are in `pubspec.yaml`
- Review build logs in Vercel dashboard

### Routing Issues
- The `vercel.json` includes a rewrite rule to handle Flutter's routing
- All routes redirect to `index.html` for client-side routing

### Environment Variables
- For sensitive data, use Vercel's Environment Variables feature
- Update your Dart code to read from environment variables if needed

## Notes

- The app uses Supabase for backend (configured in `lib/config/supabase_config.dart`)
- For production, consider moving API keys to environment variables
- The build process may take 2-5 minutes depending on project size

