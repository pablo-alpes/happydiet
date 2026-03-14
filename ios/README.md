# HappyDiet iOS App

SwiftUI app for HappyDiet: meal capture, analysis, and dashboard.

## Prerequisites

- Xcode 16+ (or 15+)
- iOS 17+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (optional, for project generation)

## Setup

### 1. Generate Xcode project

If XcodeGen is installed:

```bash
brew install xcodegen
cd ios
xcodegen generate
open -a Xcode HappyDiet.xcodeproj
```

If not using XcodeGen, create a new SwiftUI iOS App in Xcode and add the source files from `HappyDiet/` manually.

### 2. Configure backend URL

Edit `HappyDiet/HappyDietConfig.plist` (or use `HappyDiet.xcconfig` if wired to your build):

- **BACKEND_URL**: Default `http://localhost:8080` for dev. For Cloud Run, set your deployed URL (e.g. `https://your-service-xxx.run.app`).
- **API_KEY**: Optional. Set if your backend requires `X-API-Key` header.

### 3. Run backend locally

```bash
cd ../backend
npm run dev
```

The app will POST to `http://localhost:8080/analyze-meal` and GET from `http://localhost:8080/meals?user_id=demo`.

## Features

- **Tab 1 — Analyze**: Capture meal (camera or photo library) → analyze → show compliance (score, message, items). Optional TTS via speaker button.
- **Tab 2 — Dashboard**: Meal list with compliance scores and ingredients.

## Info.plist

- Camera, photo library, and microphone usage descriptions are included.
- `NSAppTransportSecurity` allows localhost for dev; use HTTPS for production.
