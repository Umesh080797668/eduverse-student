# Update System Guide

## Overview
The student app uses an automatic update system that checks for new versions from GitHub.

## How It Works

### 1. Update Check Process
- The app checks for updates every 6 hours in the background
- Users can manually check for updates in Settings
- If an update hasn't been installed for 10+ days, it becomes forced (required)

### 2. The `update.json` File

This file **MUST** be manually maintained in your GitHub repository at:
```
https://raw.githubusercontent.com/YOUR_USERNAME/eduverse-student/main/update.json
```

**Location**: Place this file in the root of your repository (same level as `pubspec.yaml`)

**Format**:
```json
{
  "version": "1.0.0",
  "downloadUrl": "https://github.com/YOUR_USERNAME/eduverse-student/releases/download/1.0.0/app-release.apk",
  "releaseNotes": "What's new in this version",
  "isForced": false
}
```

### 3. Release Process

Every time you release a new version:

#### Step 1: Update `pubspec.yaml`
```yaml
version: 1.0.1+2  # Increment version number
```

#### Step 2: Build the APK
```bash
flutter build apk --release
```

#### Step 3: Create GitHub Release
1. Go to your GitHub repository
2. Click "Releases" → "Create a new release"
3. Tag version: `1.0.1` (match your app version)
4. Upload the APK from: `build/app/outputs/flutter-apk/app-release.apk`
5. Publish the release

#### Step 4: Update `update.json`
Update the file with new version info:
```json
{
  "version": "1.0.1",
  "downloadUrl": "https://github.com/YOUR_USERNAME/eduverse-student/releases/download/1.0.1/app-release.apk",
  "releaseNotes": "🐛 Bug fixes\n✨ New features\n🎨 UI improvements",
  "isForced": false
}
```

#### Step 5: Commit and Push
```bash
git add update.json
git commit -m "Update version to 1.0.1"
git push origin main
```

### 4. Configuration

Update the GitHub repository URL in the code if needed:

**File**: `lib/services/update_service.dart`
```dart
static String get _updateCheckUrl =>
    dotenv.env['UPDATE_CHECK_URL'] ??
    'https://raw.githubusercontent.com/YOUR_USERNAME/eduverse-student/main/update.json';
```

**Replace**:
- `YOUR_USERNAME` with your actual GitHub username
- `eduverse-student` with your actual repository name

### 5. Testing Updates

#### Test Update Check:
1. Open Settings
2. Tap "Check for Updates"
3. Should show "You are using the latest version" if current

#### Test Update Available:
1. In `update.json`, set version to `1.0.1` (higher than your current version)
2. Restart the app or check for updates
3. Should show "Update Available" dialog

#### Test Forced Update:
1. Set `"isForced": true` in `update.json`
2. The app will require the update to continue

### 6. Important Notes

⚠️ **Critical Points**:
- The `update.json` file is **NOT auto-generated** - you must update it manually
- Always upload the APK to GitHub Releases before updating `update.json`
- The download URL must point to a valid, publicly accessible APK file
- Version comparison uses semantic versioning (e.g., 1.0.1 > 1.0.0)
- The app caches update checks for 6 hours to avoid excessive API calls

### 7. Troubleshooting

**Update check fails**:
- Verify the GitHub repository is public
- Check the raw.githubusercontent.com URL is accessible
- Ensure `update.json` is in the main branch

**Download fails**:
- Verify the APK is uploaded to GitHub Releases
- Check the download URL is correct and public
- Ensure the APK file is not corrupted

**Version not detected**:
- Verify version format matches: `major.minor.patch` (e.g., `1.0.0`)
- Check `pubspec.yaml` version matches the app version
- Clear app cache and try again

### 8. Example Workflow

```bash
# 1. Update version in pubspec.yaml
version: 1.0.2+3

# 2. Build release APK
flutter build apk --release

# 3. Create GitHub release and upload APK
# (Done via GitHub web interface)

# 4. Update update.json
{
  "version": "1.0.2",
  "downloadUrl": "https://github.com/username/repo/releases/download/1.0.2/app-release.apk",
  "releaseNotes": "• Fixed login button\n• Added dark mode\n• Improved performance",
  "isForced": false
}

# 5. Commit and push
git add update.json pubspec.yaml
git commit -m "Release version 1.0.2"
git push origin main

# Done! Users will receive update notification within 6 hours
```

### 9. Best Practices

✅ **Do**:
- Always test the APK before releasing
- Write clear, user-friendly release notes
- Increment version numbers properly
- Keep `update.json` in sync with releases
- Use semantic versioning

❌ **Don't**:
- Don't force updates unless critical
- Don't change download URLs after release
- Don't skip version numbers
- Don't forget to commit `update.json`
- Don't use development builds in production

---

For more information, see the teacher app's update system which follows the same pattern.
