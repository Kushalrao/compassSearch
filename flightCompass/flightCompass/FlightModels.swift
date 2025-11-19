//
//  FlightModels.swift
//  flightCompass
//
//  Created by Kushal Yadav on 18/11/25.
//

import Foundation

// Response model for searchapi.io Google Flights API
struct FlightSearchResponse: Codable {
    let bestFlights: [Flight]?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case bestFlights = "best_flights"
        case error
    }
}

struct Flight: Codable {
    let price: Int?
}

