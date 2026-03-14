# HappyDiet — Test on Your Phone

Two ways to try the app on your phone: **web dev playground** (fastest) or **native iOS app**.

---

## Option 1: Web Dev Playground (fastest)

No Xcode, no install. Use your phone’s browser.

### Steps

1. **Start the backend on your Mac:**
   ```bash
   cd backend
   npm run dev
   ```

2. **Get your Mac’s IP:**
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   Example: `192.168.1.5`

3. **On your phone:**
   - Connect to the **same Wi‑Fi** as your Mac
   - Open Safari (or Chrome) and go to:
     ```
     http://YOUR_MAC_IP:8080/dev.html
     ```
     Example: `http://192.168.1.5:8080/dev.html`

4. **Use the app:**
   - Enter diet rules (e.g. "No soda, no bread")
   - Tap **Parse & Save** or leave blank for default rules
   - Tap **Take photo** or **Upload file** to add a meal image
   - Tap **Analyze Meal**
   - Tap **Speak** to hear the result

---

## Option 2: Native iOS App

Full app with Camera + Photo Library, Dashboard, TTS.

### Prerequisites

- Mac with Xcode 15+
- iPhone with iOS 17+
- Same Wi‑Fi for Mac and iPhone

### Steps

1. **Generate the Xcode project:**
   ```bash
   brew install xcodegen   # if needed
   cd happydiet/ios
   xcodegen generate
   open HappyDiet.xcodeproj
   ```

2. **Point the app to your backend:**
   - Edit `HappyDiet/HappyDietConfig.plist`
   - Set `BACKEND_URL` to `http://YOUR_MAC_IP:8080` (e.g. `http://192.168.1.5:8080`)
   - Use your Mac’s IP from step 2 in Option 1

3. **Run the backend on your Mac:**
   ```bash
   cd happydiet/backend
   npm run dev
   ```

4. **Install on your iPhone:**
   - Connect the iPhone via USB
   - In Xcode: select your device in the toolbar
   - Press **Run** (⌘R)
   - Trust the developer certificate on the device if asked

5. **Use the app:**
   - **Analyze** tab: Camera or Photo Library → capture/select meal → see compliance
   - **Dashboard** tab: meal history

---

## Cloud Run (production)

For testing without your Mac running:

1. Deploy the backend:
   ```bash
   cd backend
   gcloud run deploy happydiet-backend --source . --region us-central1 --allow-unauthenticated
   ```

2. Use the Cloud Run URL:
   - **Web:** `https://YOUR-SERVICE-xxx.run.app/dev.html`
   - **iOS:** Set `BACKEND_URL` in `HappyDietConfig.plist` to that URL

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Could not connect" on phone | Same Wi‑Fi as Mac; correct IP in URL/plist |
| Camera not working (web) | Use HTTPS or localhost; grant camera permission |
| 503 from backend | Set `GOOGLE_CLOUD_PROJECT` in `backend/.env` |
| iOS "Untrusted Developer" | Settings → General → VPN & Device Management → Trust |
