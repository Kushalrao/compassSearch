//
//  FlightPriceCache.swift
//  flightCompass
//
//  Created by Kushal Yadav on 18/11/25.
//

import Foundation
import Combine

@MainActor
class FlightPriceCache: ObservableObject {
    @Published private(set) var prices: [String: Int] = [:]
    private var searchingCodes: Set<String> = []  // Track in-flight searches
    
    // Get price for airport code
    func getPrice(for airportCode: String) -> Int? {
        return prices[airportCode]
    }
    
    // Set price for airport code
    func setPrice(_ price: Int, for airportCode: String) {
        prices[airportCode] = price
        searchingCodes.remove(airportCode)
        print("💾 Cached: \(airportCode) = $\(price) | Total cached: \(prices.count)")
    }
    
    // Check if price exists for airport code
    func hasPrice(for airportCode: String) -> Bool {
        return prices[airportCode] != nil
    }
    
    // Check if we should search for this airport (not cached and not currently searching)
    func shouldSearch(for airportCode: String) -> Bool {
        let should = !hasPrice(for: airportCode) && !searchingCodes.contains(airportCode)
        if should {
            searchingCodes.insert(airportCode)
        }
        return should
    }
    
    // Mark search as failed
    func searchFailed(for airportCode: String) {
        searchingCodes.remove(airportCode)
    }
}
