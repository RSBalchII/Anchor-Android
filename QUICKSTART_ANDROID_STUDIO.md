# Quick Start Guide for Android Studio

## Step 1: Open Project

1. Launch **Android Studio**
2. Click **"Open an Existing Project"**
3. Navigate to `C:\Users\rsbiiw\Projects\anchor-android`
4. Click **"OK"**

Android Studio will:
- Sync Gradle
- Download dependencies (~2-5 minutes first time)
- Index the project

---

## Step 2: Configure Emulator

### Create a New Emulator

1. **Tools → Device Manager**
2. Click **"Create Device"**
3. Select **Pixel 6** (or any modern phone)
4. Click **"Next"**
5. Select **Android 14 (API 34)**
6. Click **"Next"** → **"Finish"**

### Emulator Settings

- **RAM**: 4096MB (recommended)
- **VM Heap**: 512MB
- **Internal Storage**: 8192MB

---

## Step 3: Build and Run

### First Build

1. Click the **green play button** (▶️) in toolbar
2. Or press **Shift + F10**
3. Select the emulator you created
4. Wait for build (~1-2 minutes first time)

### Expected Output

You should see:
```
> Task :app:compileDebugKotlin
> Task :app:compileDebugJavaWithJavac
> Task :app:packageDebug
> Task :app:installDebug
> BUILD SUCCESSFUL in 45s
```

### What You'll See

- Emulator launches
- App installs
- WebView shows (currently blank/loading since engine isn't bundled yet)

---

## Step 4: View Logs

### Logcat Filter

1. **View → Tool Windows → Logcat**
2. Set filter to: `EngineService`
3. You should see:
   ```
   I/EngineService: Starting Anchor Engine service
   I/EngineService: Engine initialization would happen here
   ```

---

## Step 5: Test with Your Laptop

### Check Connectivity

Once the app is running:

```bash
# From your laptop (in same tailnet)
curl http://localhost:3160/health
```

**Note**: This will fail for now because the engine isn't actually running yet. This is expected.

---

## Next Steps for Development

### 1. Bundle Node.js Runtime

You need to add nodejs-mobile:

**Option A: Manual Integration**
1. Download nodejs-mobile from GitHub
2. Extract to `app/src/main/jniLibs/`
3. Update `EngineService.kt` to call native methods

**Option B: Use Pre-built Library**
```kotlin
// In app/build.gradle.kts
dependencies {
    implementation("com.nicollite:nodejs-mobile-android:0.1.0")
}
```

### 2. Bundle Engine Code

1. Build the engine:
   ```bash
   cd C:\Users\rsbiiw\Projects\anchor-os\packages\anchor-engine
   npm run build
   ```

2. Copy to Android project:
   ```bash
   # Create assets directory
   mkdir C:\Users\rsbiiw\Projects\anchor-android\app\src\main\assets\engine
   
   # Copy built engine
   cp -r anchor-engine/dist/* anchor-android/app/src/main/assets/engine/
   cp anchor-engine/package.json anchor-android/app/src/main/assets/engine/
   ```

### 3. Update EngineService

Modify `EngineService.kt` to actually start Node.js:

```kotlin
private fun initializeEngine() {
    val nodeJS = NodeJS.getInstance(applicationContext)
    
    // Copy assets to app storage
    copyAssets("engine", filesDir.absolutePath)
    
    // Start engine
    nodeJS.start(
        script = "${filesDir.absolutePath}/engine/dist/index.js",
        args = arrayOf("--port", "3160", "--db-path", "${filesDir.absolutePath}/anchor.db")
    )
    
    Log.i(TAG, "Engine started on port 3160")
}
```

---

## Troubleshooting

### Build Fails: "SDK not found"
- **File → Project Structure → SDK Location**
- Ensure Android SDK path is set

### Emulator Won't Start
- **Tools → Device Manager**
- Delete and recreate the emulator
- Ensure VT-x/AMD-V is enabled in BIOS

### App Crashes on Launch
- Check Logcat for errors
- Ensure `minSdk = 24` in `build.gradle.kts`
- Try a different emulator API level

### WebView Shows Blank Page
- Engine isn't running yet (expected)
- Once Node.js is integrated, it will load

---

## Testing Checklist

Once Node.js is integrated:

- [ ] App launches without crashes
- [ ] Logcat shows "Engine started on port 3160"
- [ ] `curl http://localhost:3160/health` returns `{"status": "healthy"}`
- [ ] WebView displays the engine UI
- [ ] Tailscale IP is detectable
- [ ] Another device can query the engine via Tailscale

---

## Resources

- **Android Studio Docs**: https://developer.android.com/studio/intro
- **nodejs-mobile**: https://github.com/nicollite/nodejs-mobile
- **Tailscale Android**: https://tailscale.com/kb/1065/android/
- **Anchor Engine**: https://github.com/RSBalchII/Anchor

---

**Need help?** Reach out with specific errors from Logcat and we'll debug together.
