//
//  ContentView.swift
//  flightCompass
//
//  Created by Kushal Yadav on 18/11/25.
//

import SwiftUI
import CoreLocation

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var nearestAirport: Airport?
    @State private var airportsInDirection: [Airport] = []
    
    var body: some View {
        compassView
            .onAppear {
                // Load airports FIRST
                AirportService.shared.loadAirports()
            }
            .onChange(of: locationManager.currentLocation) { newValue in
                if let location = newValue {
                    nearestAirport = AirportService.shared.findNearestAirport(to: location)
                    updateAirportsInDirection()
                }
            }
            .onChange(of: locationManager.heading) { _ in
                updateAirportsInDirection()
            }
    }
    
    private var compassView: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
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
                userCountryCode: locationManager.userCountryCode
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
        VStack(spacing: 4) {
            Text("\(Int(locationManager.heading))°")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if let airport = nearestAirport {
                Text(airport.code)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            } else {
                Text(directionText(for: locationManager.heading))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.gray)
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
    
    // Update the list of airports in the current direction
    private func updateAirportsInDirection() {
        guard let location = nearestAirport?.coordinate else { return }
        
        let airports = AirportService.shared.findAirports(
            from: location,
            heading: locationManager.heading,
            tolerance: 30.0
        )
        
        // Limit to reasonable number for display (e.g., max 10)
        airportsInDirection = Array(airports.prefix(10))
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
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.3))
                        .cornerRadius(4)
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


#Preview {
    ContentView()
}
