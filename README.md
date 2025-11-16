# CameraPreview

A minimal SwiftUI macOS app that launches straight into a live camera view, lets you finger-paint directly on the feed using Vision hand-pose tracking, and includes quick orientation toggles (mirror + vertical flip) to match however your camera is mounted.

## Requirements

- macOS 13+ with a connected camera
- Xcode Command Line Tools (`xcode-select --install`) for `swiftc`, `xcrun`, and `plutil`

## Build & Run

```bash
cd Desktop/repos/mac-camera-app
./build.sh
open build/CameraPreview.app
```

The first run triggers a camera permission prompt; if you tap “Don’t Allow”, re-enable it under **System Settings → Privacy & Security → Camera → CameraPreview**.

## Controls

All controls sit in the translucent bar at the top of the window:

| Control | Description |
|---------|-------------|
| **Start Painting / Stop Painting** | Enables Vision tracking of your index finger so it draws on the live view. |
| **Clear Paint** | Clears the currently drawn stroke path. |
| **Color** | Cycles through a set of bright, high-contrast stroke colors. |
| **Mirror / Unmirror** | Switches between reflection-style view (good for gestures) and true-to-life orientation. |
| **Flip Vertical / Unflip** | Inverts the feed vertically; useful for upside-down camera mounts. |

A small debug badge in the bottom-left shows camera state, whether tracking is on, path-point count, and the mirror/flip states.

## Project Layout

- `Sources/CameraPreviewApp.swift` – SwiftUI app entry point.
- `Sources/ContentView.swift` – UI layer plus overlay rendering, control bar, and orientation logic.
- `Sources/CameraController.swift` – Handles authorization, `AVCaptureSession` setup, and Vision hand-pose detection.
- `Info.plist` – Includes `NSCameraUsageDescription` to explain why the app needs camera access.
- `build.sh` – Convenience script that compiles everything into a `.app` bundle (linking SwiftUI, AVFoundation, Vision).

## Troubleshooting

- If the preview stays black, quit the app, make sure no other app is monopolizing the camera, then relaunch (`open build/CameraPreview.app`).
- Grant access via **System Settings → Privacy & Security → Camera** if the badge shows `State: denied`.
- When tracking feels inverted, toggle **Mirror** or **Flip Vertical** so the overlay matches your gestures.
