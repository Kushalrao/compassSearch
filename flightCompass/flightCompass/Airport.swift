//
//  Airport.swift
//  flightCompass
//
//  Created by Kushal Yadav on 18/11/25.
//

import Foundation
import CoreLocation

struct Airport: Identifiable {
    let id: String
    let code: String  // IATA or ICAO code for display
    let name: String
    let latitude: Double
    let longitude: Double
    let type: String
    let countryCode: String  // ISO country code (e.g., "IN", "US", "GB")
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Convert country code to flag emoji
    var flagEmoji: String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let scalarValue = UnicodeScalar(base + scalar.value) {
                emoji.append(String(scalarValue))
            }
        }
        return emoji
    }
    
    // Calculate distance to another coordinate (in kilometers)
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2) / 1000.0 // Convert to km
    }
    
    // Calculate bearing to this airport from given coordinate (in degrees)
    static func bearing(from coordinate: CLLocationCoordinate2D, to airport: Airport) -> Double {
        let lat1 = coordinate.latitude.degreesToRadians
        let lon1 = coordinate.longitude.degreesToRadians
        let lat2 = airport.latitude.degreesToRadians
        let lon2 = airport.longitude.degreesToRadians
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x)
        
        return (bearing.radiansToDegrees + 360).truncatingRemainder(dividingBy: 360)
    }
}

extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}

