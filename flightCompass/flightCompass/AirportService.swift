//
//  AirportService.swift
//  flightCompass
//
//  Created by Kushal Yadav on 18/11/25.
//

import Foundation
import CoreLocation

class AirportService {
    static let shared = AirportService()
    
    private var airports: [Airport] = []
    private var isLoaded = false
    
    private init() {}
    
    // Load airports from CSV file
    func loadAirports() {
        guard !isLoaded else {
            print("⚠️ Airports already loaded, skipping")
            return
        }
        
        guard let filepath = Bundle.main.path(forResource: "airports", ofType: "csv") else {
            print("❌ Could not find airports.csv in bundle!")
            print("📁 Bundle path: \(Bundle.main.bundlePath)")
            return
        }
        
        print("✅ Found airports.csv at: \(filepath)")
        
        do {
            let contents = try String(contentsOfFile: filepath, encoding: .utf8)
            let lines = contents.components(separatedBy: .newlines)
            
            // Skip header row
            for line in lines.dropFirst() {
                guard !line.isEmpty else { continue }
                
                if let airport = parseAirportLine(line) {
                    // Filter to only include airports with IATA codes (commercial airports)
                    // IATA codes are 3 letters (like BLR, DEL, BOM)
                    if airport.code.count == 3 && !airport.code.contains(where: { $0.isNumber }) {
                        airports.append(airport)
                    }
                }
            }
            
            isLoaded = true
            print("✅ Loaded \(airports.count) airports (large/medium only)")
            
            // Debug: Check if BLR is loaded
            if let blr = airports.first(where: { $0.code == "BLR" }) {
                print("✅ BLR found: \(blr.name) at \(blr.latitude), \(blr.longitude)")
            } else {
                print("⚠️ BLR not found in loaded airports!")
            }
        } catch {
            print("Error loading airports: \(error)")
        }
    }
    
    // Parse a single CSV line into an Airport
    private func parseAirportLine(_ line: String) -> Airport? {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        fields.append(currentField) // Add last field
        
        guard fields.count >= 14 else { return nil }
        
        let id = fields[0]
        let ident = fields[1]
        let type = fields[2]
        let name = fields[3]
        
        guard let latitude = Double(fields[4]),
              let longitude = Double(fields[5]) else {
            return nil
        }
        
        let countryCode = fields[8]  // iso_country
        
        // Prefer IATA code, fall back to ICAO or ident
        let iataCode = fields[13]
        let icaoCode = fields[12]
        let code = !iataCode.isEmpty ? iataCode : (!icaoCode.isEmpty ? icaoCode : ident)
        
        return Airport(
            id: id,
            code: code,
            name: name,
            latitude: latitude,
            longitude: longitude,
            type: type,
            countryCode: countryCode
        )
    }
    
    // Find nearest airport to given coordinate
    func findNearestAirport(to coordinate: CLLocationCoordinate2D) -> Airport? {
        guard !airports.isEmpty else {
            print("⚠️ No airports loaded!")
            return nil
        }
        
        print("📍 Finding nearest airport to: \(coordinate.latitude), \(coordinate.longitude)")
        print("🛫 Total airports loaded: \(airports.count)")
        
        let nearest = airports.min(by: { airport1, airport2 in
            let dist1 = airport1.distance(to: coordinate)
            let dist2 = airport2.distance(to: coordinate)
            return dist1 < dist2
        })
        
        if let airport = nearest {
            let distance = airport.distance(to: coordinate)
            print("✈️ Nearest airport: \(airport.code) (\(airport.name)) - \(String(format: "%.1f", distance)) km away")
        }
        
        return nearest
    }
    
    // Find airports within bearing range (±tolerance degrees) from a location
    func findAirports(
        from coordinate: CLLocationCoordinate2D,
        heading: Double,
        tolerance: Double = 30.0
    ) -> [Airport] {
        var matchingAirports: [Airport] = []
        
        for airport in airports {
            let bearing = Airport.bearing(from: coordinate, to: airport)
            let difference = angleDifference(heading, bearing)
            
            if difference <= tolerance {
                matchingAirports.append(airport)
            }
        }
        
        // Sort by distance (closest first)
        matchingAirports.sort { airport1, airport2 in
            let dist1 = airport1.distance(to: coordinate)
            let dist2 = airport2.distance(to: coordinate)
            return dist1 < dist2
        }
        
        return matchingAirports
    }
    
    // Calculate the smallest angle difference between two bearings
    private func angleDifference(_ angle1: Double, _ angle2: Double) -> Double {
        let diff = abs(angle1 - angle2)
        return min(diff, 360 - diff)
    }
}

