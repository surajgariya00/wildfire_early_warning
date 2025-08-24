# Wildfire Early Warning (Flutter: Web + Mobile)

An offline-first Flutter app that:

- Displays **active wildfire events** (NASA EONET) on a map.
- Computes a **simple, explainable Fire Risk score** for your location using **Open-Meteo** (free, no key).
- Works on **Web** and **Android** (and iOS once you set up signing).
- Uses **OpenStreetMap** tiles via `flutter_map` (with attribution).

> ⚠️ **Disclaimer**: Risk score is a heuristic based on temperature, humidity, wind and recent precipitation. It is **not** an official forecast or the Canadian FWI. Always follow guidance from local authorities.

## Quick start

1. Ensure Flutter SDK is installed and web enabled:

```bash
flutter --version
flutter config --enable-web
```

2. Create platform scaffolding (Android/iOS/web) in the project folder after extracting:

```bash
flutter create .
```

3. Run on web or Android:

```bash
flutter pub get
flutter run -d chrome
# or
flutter run -d android
```

> If Android location permission doesn't show, make sure to accept prompts. On iOS, add usage descriptions in `Info.plist` (see comments inside `lib/services/location.dart` if you add one).

## Free data sources

- **Wildfires**: NASA EONET v3 `events` filtered for `wildfires`.
- **Weather**: Open-Meteo hourly API (`temperature_2m`, `relative_humidity_2m`, `wind_speed_10m`, `precipitation`, `precipitation_probability`, `vapour_pressure_deficit`).
- **Maps**: OpenStreetMap tiles via `flutter_map`.

## How the Fire Risk score works (heuristic)

We rescale and combine:

- High temp (↑risk)
- Low humidity (↑risk when RH < 35%)
- Strong wind (↑risk when > 20 km/h)
- Lack of recent rain (↑risk when last 72h precipitation is low)
- High VPD (↑risk when > 1.6 kPa)  
  Weights are in code and commented for tuning. This creates a 0–100 score and a 5-level badge (Very Low → Extreme).

## Attribution

- © OpenStreetMap contributors, ODbL. Tile usage policy respected; please avoid bulk downloads.
- NASA EONET for event curation.
- Open-Meteo for weather forecasts (no API key).

## Production notes

- For heavy traffic, consider using a commercial tile provider (Stadia Maps, MapTiler, etc.).
- EONET is curated and may not include all fires; combine with regional feeds if needed.
- You can tune the risk thresholds for your region in `open_meteo_service.dart`.

### Android/iOS permissions

**Android**: After `flutter create .`, open `android/app/src/main/AndroidManifest.xml` and add inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**iOS**: Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is used to show local wildfire risk on the map.</string>
```
