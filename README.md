# FlightCompass - Airport & Flight Price Finder

An iOS app that shows airports in the direction you're facing and displays the cheapest flight prices from your nearest airport.

![iOS](https://img.shields.io/badge/iOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-2.0-green.svg)

## Features

- 🧭 **Compass-based Airport Discovery**: Shows airports within ±30° of your current heading
- 📍 **Nearest Airport Detection**: Automatically finds your nearest airport as the origin
- 💰 **Real-time Flight Pricing**: Searches for one-way flights 7 days from today
- 💾 **Smart Caching**: Stores prices per airport for the session (no redundant API calls)
- ⏱️ **2-Second Debounce**: Only searches when you stop rotating for 2 seconds
- 🗺️ **Rotating Map View**: Interactive map that rotates with device heading
- 🌍 **Country Flags**: Shows flag emoji for international airports
- 🎨 **Clean UI**: White background with rotating map visualization

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/compassSearch.git
cd compassSearch/flightCompass
```

### 2. Get a searchapi.io API Key

1. Sign up at [searchapi.io](https://www.searchapi.io)
2. Get your API key from the dashboard
3. Open `flightCompass/FlightService.swift`
4. Add your API key:

```swift
private var apiKey: String? {
    let key = "YOUR_API_KEY_HERE"  // Replace with your actual key
    // ...
}
```

### 3. Build & Run

```bash
open flightCompass.xcodeproj
```

Or via command line:
```bash
xcodebuild -project flightCompass.xcodeproj -scheme flightCompass -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Then press ⌘R in Xcode to run.

## How It Works

### Smart Search Behavior

1. **User rotates device** → Updates airport list
2. **2-second delay** → Waits for user to stop moving
3. **Check cache** → Skips already-searched airports
4. **Concurrent searches** → Searches all visible airports at once
5. **Display prices** → Shows prices next to airport codes

### Console Output
```
📡 Direction: 45° | Found: 19 airports | Showing: 10
🛫 Displayed: DEL, BOM, CCU, HYD, MAA, BLR, AMD, GOI, COK, TRV

⏰ User stopped for 2s - triggering searches
🔎 NEW SEARCH: BLR -> DEL
🔎 NEW SEARCH: BLR -> BOM
💾 Cached: DEL = 245 | Total cached: 1
💾 Cached: BOM = 198 | Total cached: 2
```

### Cost Optimization

- ✅ Only searches visible airports (max 10)
- ✅ 2-second debounce prevents searches while rotating
- ✅ Session caching prevents duplicate API calls
- ✅ In-flight tracking prevents concurrent duplicates

## Project Structure

```
flightCompass/
├── flightCompass/
│   ├── Airport.swift              # Airport model with distance/bearing
│   ├── AirportService.swift       # Loads CSV, finds airports
│   ├── ContentView.swift          # Main UI with map & compass
│   ├── FlightModels.swift         # API response models
│   ├── FlightService.swift        # searchapi.io integration
│   ├── FlightPriceCache.swift     # Price caching system
│   ├── LocationManager.swift      # CoreLocation wrapper
│   ├── flightCompassApp.swift     # App entry point
│   └── airports.csv               # 83K+ airports database
```

## API Details

### Flight Search Parameters
- **Type**: One-way
- **Date**: 7 days from today (YYYY-MM-DD)
- **Currency**: USD
- **Origin**: User's nearest airport (IATA code)
- **Destinations**: Airports in current direction (up to 10)

### searchapi.io Endpoint
```
GET https://www.searchapi.io/api/v1/search
Parameters:
  - engine: google_flights
  - departure_id: BLR
  - arrival_id: DEL
  - outbound_date: 2025-11-26
  - flight_type: one_way
  - currency: USD
  - api_key: YOUR_KEY
```

## Requirements

- iOS 14.0+
- Xcode 13.0+
- Swift 5.0+
- Device with magnetometer (for heading)
- Location permissions

## Permissions

The app requires:
- **Location (When In Use)**: To find nearest airport and heading
- **Motion**: For compass/heading data

## Troubleshooting

### "No API key configured"
- Add your searchapi.io API key to `FlightService.swift`
- Rebuild the project (⌘⇧K then ⌘B)

### "No flights found"
- API might not have routes for that origin/destination
- Check if airport codes are valid IATA codes
- Verify API key has remaining credits

### Prices not showing
- Wait 2 seconds after stopping rotation
- Check Xcode console for API errors
- Verify internet connection

### Map not rotating
- Requires physical device or simulator with motion support
- Grant location permissions in Settings

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is open source and available under the MIT License.

## Credits

- Airport data: [OpenFlights Airport Database](https://openflights.org/data.html)
- Flight data: [searchapi.io](https://www.searchapi.io) Google Flights API
- Built with SwiftUI, MapKit & CoreLocation

## Author

Built with ❤️ using SwiftUI

---

**Note**: Remember to add your own searchapi.io API key before running the app!
