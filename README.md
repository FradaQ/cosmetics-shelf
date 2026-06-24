# Cosmetics Shelf

<p align="center">
  <img src="docs/assets/app-icon.png" alt="Cosmetics Shelf app icon" width="180">
</p>

An iPhone app prototype for tracking beauty inventory across skincare, makeup, fragrance, hair/body, and other categories.

The app is built with SwiftUI and SwiftData for iOS 17+. It stores products locally, estimates shelf life, and helps prioritize items before they expire.

## Visual Direction

Cosmetics Shelf uses a soft, chic skincare-inspired visual system with muted sage, dusty rose, warm cream, and small red/yellow/green status accents for expiry reminders.

![Cosmetics Shelf color palette](docs/assets/color-palette.png)

## Features

- Categorize products by skincare, makeup, fragrance, hair/body, and other
- Record brand, product names, batch code, purchase date, manufacture date, opened date, and notes
- Support local/Chinese product name plus English or official product name
- Follow the iPhone system language for the main app UI
- Estimate expiry from manufacture date, period after opening, or manual expiry date
- Use the earliest available expiry date as the recommended expiry
- Show products in the reminder list 6 months before suggested expiry
- Schedule local notifications for use-soon reminders
- Search the companion lookup API by name and fill in candidate name, brand, image URL, source URL, source, and confidence
- Keep manual entry as a fallback when product or batch-code lookup is unavailable

## Current Status

This is a working local prototype. Product info lookup now tries the companion lookup API first, then falls back to a public beauty product database if the local API is unavailable. Official product URLs and image URLs can still be entered manually. Batch-code parsing calls the companion API, but brand-specific reliable parsing rules still need to be added on the API side.

## Planning Docs

- [Product info lookup PRD](docs/product-info-lookup-prd.md)
- [Product info and batch lookup design doc](docs/product-info-lookup-design.md)
- [Prompt for a future lookup API project](docs/api-project-prompt.md)

## Run Locally

1. Open `CosmeticsShelf.xcodeproj` in Xcode.
2. Select an iPhone Simulator or connected iPhone.
3. In `Signing & Capabilities`, choose your Apple ID team if running on a physical device.
4. Press `Run`.

## Local API

The app defaults to the local API base URL:

```text
http://127.0.0.1:8000
```

For iPhone Simulator testing, run the companion API on the Mac:

```bash
cd /Users/fqin/Documents/Codex/2026-06-24/i-want-to-build-a-lightweight/work/cosmetics-shelf-api
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

For physical iPhone testing, `127.0.0.1` points to the phone itself. Run the API with `--host 0.0.0.0` and configure the app to use the Mac's local network IP, or deploy the API and use its HTTPS URL.

The API base URL is read from the generated Info.plist key `CosmeticsShelfAPIBaseURL`.

## Validation

The project has been built successfully with Xcode using the iPhone Simulator SDK.
