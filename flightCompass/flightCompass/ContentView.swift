//
//  ContentView.swift
//  flightCompass
//
//  Created by Kushal Yadav on 18/11/25.
//

import SwiftUI
import CoreLocation
import MapKit
import UIKit

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var priceCache = FlightPriceCache()
    @State private var nearestAirport: Airport?
    @State private var airportsInDirection: [Airport] = []
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var isRotating = false
    @State private var rotationTimer: Task<Void, Never>?
    @State private var lastHapticHeading: Double = 0
    private let hapticGenerator = UISelectionFeedbackGenerator()
    private let hapticThreshold: Double = 5.0 // Trigger haptic every 5 degrees
    
    var body: some View {
        compassView
            .onAppear {
                // Load airports FIRST
                AirportService.shared.loadAirports()
                // Prepare haptic generator for better responsiveness
                hapticGenerator.prepare()
            }
            .onChange(of: locationManager.currentLocation) { newValue in
                if let location = newValue {
                    nearestAirport = AirportService.shared.findNearestAirport(to: location)
                    updateAirportsInDirection()
                }
            }
            .onChange(of: locationManager.heading) { _ in
                updateAirportsInDirection()
                handleRotation()
            }
    }
    
    private var compassView: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.ignoresSafeArea()
                
                compassContent(geometry: geometry)
                
                authorizationMessage
            }
        }
    }
    
    private func compassContent(geometry: GeometryProxy) -> some View {
        ZStack {
            AirportListView(
                airports: airportsInDirection,
                maxHeight: geometry.size.height / 2 - 170,
                userCountryCode: locationManager.userCountryCode,
                priceCache: priceCache
            )
            
            compassDial
            centerDisplay
        }
    }
    
    private var compassDial: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                .frame(width: 300, height: 300)
            
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .frame(width: 280, height: 280)
            
            ForEach(directions, id: \.self) { direction in
                DirectionLabel(direction: direction)
            }
            
            ForEach(0..<36) { index in
                Rectangle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: index % 9 == 0 ? 2 : 1,
                           height: index % 9 == 0 ? 15 : 8)
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(index) * 10))
            }
        }
        .rotationEffect(.degrees(-locationManager.heading))
        .animation(.linear(duration: 0.1), value: locationManager.heading)
    }
    
    private var centerDisplay: some View {
        let circleSize: CGFloat = isRotating ? 300 : 280
        
        return ZStack {
            // Map circle showing nearest airport
            if let airport = nearestAirport {
                MapView(airport: airport, heading: locationManager.heading)
                    .frame(width: circleSize, height: circleSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.green, lineWidth: 3)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRotating)
            } else {
                // Fallback when no airport is found
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        VStack(spacing: 4) {
                            Text("\(Int(locationManager.heading))°")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(directionText(for: locationManager.heading))
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRotating)
            }
            
            // Overlay heading and airport code on top of map
            if let airport = nearestAirport {
                VStack(spacing: 4) {
                    Text("\(Int(locationManager.heading))°")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 0)
                    
                    Text(airport.code)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 0)
                }
            }
        }
    }
    
    private var authorizationMessage: some View {
        VStack {
            Spacer()
            if locationManager.authorizationStatus == .denied ||
               locationManager.authorizationStatus == .restricted {
                Text("Please enable location access in Settings")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
    
    // Handle rotation state and timer
    private func handleRotation() {
        // Cancel existing timer
        rotationTimer?.cancel()
        
        // Set rotating state to true
        isRotating = true
        
        // Trigger haptic feedback only when heading changes significantly
        let headingChange = abs(locationManager.heading - lastHapticHeading)
        let normalizedChange = min(headingChange, 360 - headingChange) // Handle wrap-around
        
        if normalizedChange >= hapticThreshold {
            hapticGenerator.selectionChanged()
            lastHapticHeading = locationManager.heading
        }
        
        // Create new timer to reset after 1 second of stability
        rotationTimer = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Check if task wasn't cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    isRotating = false
                }
            }
        }
    }
    
    // Update the list of airports in the current direction
    private func updateAirportsInDirection() {
        guard let location = nearestAirport?.coordinate else { return }
        
        let airports = AirportService.shared.findAirports(
            from: location,
            heading: locationManager.heading,
            tolerance: 30.0
        )
        
        // Limit to reasonable number for display (e.g., max 10)
        let displayedAirports = Array(airports.prefix(10))
        airportsInDirection = displayedAirports
        
        // Cancel any pending search
        searchDebounceTask?.cancel()
        
        // Debounce: Only search after user stops for 2 seconds
        searchDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                if !Task.isCancelled {
                    print("⏰ User stopped for 2s - triggering searches")
                    triggerFlightSearches(for: displayedAirports)
                }
            } catch {
                print("❌ Search cancelled - user still moving")
            }
        }
    }
    
    // Trigger flight searches for airports that don't have cached prices
    private func triggerFlightSearches(for airports: [Airport]) {
        guard let originCode = nearestAirport?.code else {
            return
        }
        
        // Calculate date 7 days from today
        let dateString = dateSevenDaysFromNow()
        
        // Use TaskGroup for concurrent searches - ONLY search airports that need it
        Task { @MainActor in
            for airport in airports {
                let arrivalCode = airport.code
                
                // Check if we should search (not cached, not already searching)
                if priceCache.shouldSearch(for: arrivalCode) {
                    print("🔎 NEW SEARCH: \(originCode) -> \(arrivalCode)")
                    
                    // Launch async search task
                    Task {
                        if let price = await FlightService.shared.searchFlight(
                            from: originCode,
                            to: arrivalCode,
                            date: dateString
                        ) {
                            await priceCache.setPrice(price, for: arrivalCode)
                        } else {
                            await priceCache.searchFailed(for: arrivalCode)
                        }
                    }
                }
            }
        }
    }
    
    // Calculate date string 7 days from today in YYYY-MM-DD format
    private func dateSevenDaysFromNow() -> String {
        let calendar = Calendar.current
        let today = Date()
        
        guard let futureDate = calendar.date(byAdding: .day, value: 7, to: today) else {
            // Fallback to today if calculation fails
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: today)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: futureDate)
    }
    
    // 8 cardinal directions
    private let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    
    // Convert heading to direction text
    private func directionText(for heading: Double) -> String {
        let index = Int((heading + 22.5) / 45.0) % 8
        return directions[index]
    }
}

// Airport list view along the green line
struct AirportListView: View {
    let airports: [Airport]
    let maxHeight: CGFloat
    let userCountryCode: String?
    @ObservedObject var priceCache: FlightPriceCache
    
    var body: some View {
        VStack(spacing: 0) {
            // Airports along the line (top = farthest, bottom = closest)
            if !airports.isEmpty {
                VStack(spacing: 8) {
                    ForEach(airports.reversed()) { airport in
                        HStack(spacing: 4) {
                            // Show flag only if different country
                            if let userCountry = userCountryCode,
                               airport.countryCode != userCountry {
                                Text(airport.flagEmoji)
                                    .font(.system(size: 12))
                            }
                            
                            Text(airport.code)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.black)
                            
                            // Show price if available
                            if let price = priceCache.getPrice(for: airport.code) {
                                Text("$\(price)")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                    }
                }
                .frame(maxHeight: maxHeight)
            }
            
            // Green line
            Rectangle()
                .fill(Color.green)
                .frame(width: 3, height: 20)
            
            Spacer()
        }
    }
}

// Direction label view positioned around the circle
struct DirectionLabel: View {
    let direction: String
    
    var body: some View {
        Text(direction)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(direction == "N" ? .red : .white)
            .offset(y: -150)
            .rotationEffect(.degrees(angle(for: direction)))
            .rotationEffect(.degrees(-angle(for: direction)), anchor: .center)
    }
    
    // Calculate angle for each direction
    private func angle(for direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "NE": return 45
        case "E": return 90
        case "SE": return 135
        case "S": return 180
        case "SW": return 225
        case "W": return 270
        case "NW": return 315
        default: return 0
        }
    }
}

// Map view showing the airport location
struct MapView: View {
    let airport: Airport
    let heading: Double
    
    var body: some View {
        RotatingMapView(airport: airport, heading: heading)
    }
}

// UIViewRepresentable wrapper for MKMapView to handle rotation properly
struct RotatingMapView: UIViewRepresentable {
    let airport: Airport
    let heading: Double
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isRotateEnabled = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = false
        
        // Add annotation for airport
        let annotation = MKPointAnnotation()
        annotation.coordinate = airport.coordinate
        annotation.title = airport.code
        mapView.addAnnotation(annotation)
        
        // Set initial region and camera
        let region = MKCoordinateRegion(
            center: airport.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        mapView.setRegion(region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update camera heading to rotate map
        let camera = MKMapCamera(
            lookingAtCenter: airport.coordinate,
            fromDistance: 5000,
            pitch: 0,
            heading: heading
        )
        mapView.setCamera(camera, animated: true)
    }
}

// Custom annotation view
class AirportAnnotationView: MKAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        // Create custom view with airplane icon
        let size: CGFloat = 40
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        centerOffset = CGPoint(x: 0, y: -size/2)
        
        let imageView = UIImageView(frame: bounds)
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        imageView.image = UIImage(systemName: "airplane.circle.fill", withConfiguration: config)
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        
        addSubview(imageView)
    }
}

#Preview {
    ContentView()
}
