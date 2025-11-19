//
//  FlightService.swift
//  flightCompass
//
//  Created by Kushal Yadav on 18/11/25.
//

import Foundation

class FlightService {
    static let shared = FlightService()
    
    private let baseURL = "https://www.searchapi.io/api/v1/search"
    
    private init() {}
    
    // API key - add your searchapi.io key here
    private var apiKey: String? {
        // TODO: Add your API key from searchapi.io
        let key = "" // Add your key here: "YOUR_API_KEY_HERE"
        
        guard !key.isEmpty else {
            print("❌ No API key configured. Add your searchapi.io API key to FlightService.swift")
            return nil
        }
        
        print("✅ Using API Key: \(String(key.prefix(10)))...")
        return key
    }
    
    // Search for flights between two airports
    // Returns the cheapest price found, or nil if no results or error
    func searchFlight(from departureCode: String, to arrivalCode: String, date: String) async -> Int? {
        guard let apiKey = apiKey else {
            print("⚠️ SEARCHAPI_API_KEY not found in Info.plist")
            return nil
        }
        
        guard var urlComponents = URLComponents(string: baseURL) else {
            print("❌ Invalid base URL")
            return nil
        }
        
        // Build query parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "engine", value: "google_flights"),
            URLQueryItem(name: "departure_id", value: departureCode),
            URLQueryItem(name: "arrival_id", value: arrivalCode),
            URLQueryItem(name: "outbound_date", value: date),
            URLQueryItem(name: "flight_type", value: "one_way"),
            URLQueryItem(name: "currency", value: "USD"),
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        guard let url = urlComponents.url else {
            print("❌ Failed to construct URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ API error: HTTP \(httpResponse.statusCode)")
                if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMessage = errorData["error"] {
                    print("   Error message: \(errorMessage)")
                }
                return nil
            }
            
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(FlightSearchResponse.self, from: data)
            
            // Check for API-level error
            if let error = searchResponse.error {
                print("⚠️ API returned error: \(error)")
                return nil
            }
            
            // Extract cheapest price from best_flights array
            guard let flights = searchResponse.bestFlights, !flights.isEmpty else {
                print("⚠️ No flights found for \(departureCode) -> \(arrivalCode)")
                return nil
            }
            
            // Find minimum price from all flights
            let prices = flights.compactMap { $0.price }
            guard let cheapestPrice = prices.min() else {
                print("⚠️ No valid prices found")
                return nil
            }
            
            print("✅ Found flight \(departureCode) -> \(arrivalCode): $\(cheapestPrice)")
            return cheapestPrice
            
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            return nil
        }
    }
}

