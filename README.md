# PropertyMap — iOS MVP source project

A SwiftUI + MapKit iPhone app with a Node.js API proxy for RentCast data.

## Current capabilities
- US map, pan/zoom, search for city/address via Apple MapKit
- Map price markers for active listings and off-market records
- Toggle all/for-sale/off-market; property detail sheet
- On-demand automated value estimate; saved markers for the current session
- Backend holds the API key (never ship the key inside the app)

## Setup
1. Get a RentCast API key and verify licensing/redisplay terms: https://developers.rentcast.io/reference/introduction
2. Deploy `backend/` to any Node.js 20+ host. Set `RENTCAST_API_KEY` in host environment. Start with `npm start`.
3. Set `PropertyAPI.baseURL` in `ios/PropertyMap/API.swift` to the deployed HTTPS origin.
4. On a Mac with Xcode, create an iOS App project named `PropertyMap`, SwiftUI lifecycle, Swift language, deployment target iOS 17+. Replace the generated Swift source with the files in `ios/PropertyMap/`. Set your bundle identifier and development team.
5. Build and test on an iPhone, then archive and submit through App Store Connect.

## Important limitations / before shipping
- This is an **MVP source code package**, not a signed IPA or a validated App Store submission. Xcode compilation/device testing have not been run in this environment.
- Off-market markers show **tax assessment** when available, otherwise **last sale price**; a market value estimate is fetched only when the user taps its button. Never call these all 'current market value'.
- RentCast responses are limited to 250 records per endpoint per request; dense neighborhoods require pagination/tiling and map clustering to claim complete coverage.
- The map starts zoomed out; zoom into a neighborhood and tap 'Search this area'.
- Saved properties persist only for the current app session; add persistence before shipping if needed.
- Add authentication/rate limiting to backend, monitoring, privacy policy, terms, data provider attribution and display-license checks, accessibility testing, QA, proper icons/screenshots, and production-grade caching.
- Tax assessment fields vary by jurisdiction and schema. Verify actual RentCast response samples before production.
- No data or photos are bundled. API costs and coverage depend on your provider plan.
