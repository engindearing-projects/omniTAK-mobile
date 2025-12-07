//
//  ADSBTrafficService.swift
//  OmniTAKMobile
//
//  Multi-provider ADS-B aircraft traffic service
//

import Foundation
import CoreLocation
import Combine

class ADSBTrafficService: ObservableObject {
    static let shared = ADSBTrafficService()

    // MARK: - Published Properties

    @Published var aircraft: [Aircraft] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdate: Date?
    @Published var currentProvider: ADSBProvider = .openSky
    @Published var settings: ADSBTrafficSettings = ADSBTrafficSettings() {
        didSet {
            saveSettings()

            // Restart tracking if enabled and settings changed
            if settings.isEnabled {
                let intervalChanged = oldValue.refreshIntervalSeconds != settings.refreshIntervalSeconds
                let locationChanged = oldValue.useCurrentLocation != settings.useCurrentLocation ||
                                     oldValue.customLatitude != settings.customLatitude ||
                                     oldValue.customLongitude != settings.customLongitude
                let radiusChanged = oldValue.radiusNM != settings.radiusNM
                let providerChanged = oldValue.activeProvider != settings.activeProvider

                if intervalChanged || !oldValue.isEnabled || providerChanged {
                    startTracking()
                } else if locationChanged || radiusChanged {
                    fetchAircraft()
                }
            } else {
                stopTracking()
            }
        }
    }

    // MARK: - Private Properties

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "adsb_traffic_settings_v2"

    // MARK: - API Endpoints

    private enum APIEndpoints {
        static let openSky = "https://opensky-network.org/api/states/all"
        static let adsbExchange = "https://adsbexchange-com1.p.rapidapi.com/v2/lat/%@/lon/%@/dist/%@/"
        static let adsbLol = "https://api.adsb.lol/v2/lat/%@/lon/%@/dist/%@"
        // Official FR24 API - Live Flight Positions endpoint
        static let flightRadar24 = "https://fr24api.flightradar24.com/api/live/flight-positions/light"
        static let flightAware = "https://aeroapi.flightaware.com/aeroapi/flights/search"
    }

    // MARK: - Initialization

    private init() {
        var savedSettings = loadSettings()
        savedSettings.migrateOldCredentials()
        self.settings = savedSettings
        self.currentProvider = savedSettings.activeProvider
        if savedSettings.isEnabled {
            startTracking()
        }
    }

    // MARK: - Public Methods

    func startTracking() {
        stopTracking()
        guard settings.isEnabled else { return }

        fetchAircraft()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.refreshIntervalSeconds), repeats: true) { [weak self] _ in
            self?.fetchAircraft()
        }
    }

    func stopTracking() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        aircraft = []
    }

    func fetchAircraft() {
        guard settings.isEnabled else { return }

        let center = getSearchCenter()
        guard let center = center else {
            error = "Unable to determine location"
            return
        }

        isLoading = true
        error = nil
        currentProvider = settings.activeProvider

        switch settings.activeProvider {
        case .openSky:
            fetchFromOpenSky(center: center)
        case .adsbExchange:
            fetchFromADSBExchange(center: center)
        case .adsbLol:
            fetchFromADSBLol(center: center)
        case .flightRadar24:
            fetchFromFlightRadar24(center: center)
        case .flightAware:
            fetchFromFlightAware(center: center)
        case .custom:
            fetchFromCustomSource(center: center)
        }
    }

    func lookupZipCode(_ zipCode: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(zipCode) { placemarks, error in
            DispatchQueue.main.async {
                if let location = placemarks?.first?.location?.coordinate {
                    completion(location)
                } else {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Provider Fetchers

    private func fetchFromOpenSky(center: CLLocationCoordinate2D) {
        let radiusDeg = settings.radiusDegrees
        let minLat = center.latitude - radiusDeg
        let maxLat = center.latitude + radiusDeg
        let minLon = center.longitude - radiusDeg
        let maxLon = center.longitude + radiusDeg

        let urlString = "\(APIEndpoints.openSky)?lamin=\(minLat)&lomin=\(minLon)&lamax=\(maxLat)&lomax=\(maxLon)"

        guard let url = URL(string: urlString) else {
            handleError("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        // Add authentication if configured
        if let config = settings.providers.first(where: { $0.provider == .openSky }),
           !config.apiKey.isEmpty {
            let credentials = "\(config.apiKey):\(config.apiSecret)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }

        performRequest(request) { [weak self] data in
            try self?.parseOpenSkyResponse(data: data, center: center) ?? []
        }
    }

    private func fetchFromADSBExchange(center: CLLocationCoordinate2D) {
        guard let config = settings.providers.first(where: { $0.provider == .adsbExchange }),
              !config.apiKey.isEmpty else {
            handleError("ADS-B Exchange requires a RapidAPI key")
            return
        }

        let distanceNM = Int(settings.radiusNM)
        let urlString = String(format: APIEndpoints.adsbExchange,
                              String(center.latitude),
                              String(center.longitude),
                              String(distanceNM))

        guard let url = URL(string: urlString) else {
            handleError("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(config.apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("adsbexchange-com1.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")

        performRequest(request) { [weak self] data in
            try self?.parseADSBExchangeResponse(data: data, center: center) ?? []
        }
    }

    private func fetchFromADSBLol(center: CLLocationCoordinate2D) {
        let distanceNM = Int(settings.radiusNM)
        let urlString = String(format: APIEndpoints.adsbLol,
                              String(center.latitude),
                              String(center.longitude),
                              String(distanceNM))

        guard let url = URL(string: urlString) else {
            handleError("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        performRequest(request) { [weak self] data in
            try self?.parseADSBLolResponse(data: data, center: center) ?? []
        }
    }

    private func fetchFromFlightRadar24(center: CLLocationCoordinate2D) {
        guard let config = settings.providers.first(where: { $0.provider == .flightRadar24 }),
              !config.apiKey.isEmpty else {
            handleError("FlightRadar24 requires an API key")
            return
        }

        // FR24 API uses bounding box: north,south,west,east
        let radiusDeg = settings.radiusDegrees
        let north = center.latitude + radiusDeg
        let south = center.latitude - radiusDeg
        let west = center.longitude - radiusDeg
        let east = center.longitude + radiusDeg

        var components = URLComponents(string: APIEndpoints.flightRadar24)
        components?.queryItems = [
            URLQueryItem(name: "bounds", value: "\(north),\(south),\(west),\(east)")
        ]

        guard let url = components?.url else {
            handleError("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        // Debug logging
        print("FR24 Request URL: \(url)")
        print("FR24 API Key (first 20 chars): \(String(config.apiKey.prefix(20)))...")

        performRequest(request) { [weak self] data in
            try self?.parseFlightRadar24Response(data: data, center: center) ?? []
        }
    }

    private func fetchFromFlightAware(center: CLLocationCoordinate2D) {
        guard let config = settings.providers.first(where: { $0.provider == .flightAware }),
              !config.apiKey.isEmpty else {
            handleError("FlightAware requires an API key")
            return
        }

        var components = URLComponents(string: APIEndpoints.flightAware)
        components?.queryItems = [
            URLQueryItem(name: "query", value: "-latlong \"\(center.latitude - settings.radiusDegrees) \(center.longitude - settings.radiusDegrees) \(center.latitude + settings.radiusDegrees) \(center.longitude + settings.radiusDegrees)\"")
        ]

        guard let url = components?.url else {
            handleError("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(config.apiKey, forHTTPHeaderField: "x-apikey")

        performRequest(request) { [weak self] data in
            try self?.parseFlightAwareResponse(data: data, center: center) ?? []
        }
    }

    private func fetchFromCustomSource(center: CLLocationCoordinate2D) {
        guard let config = settings.providers.first(where: { $0.provider == .custom }),
              !config.customURL.isEmpty else {
            handleError("Custom source URL not configured")
            return
        }

        // Support placeholders in custom URL
        let urlString = config.customURL
            .replacingOccurrences(of: "{lat}", with: String(center.latitude))
            .replacingOccurrences(of: "{lon}", with: String(center.longitude))
            .replacingOccurrences(of: "{radius}", with: String(Int(settings.radiusNM)))
            .replacingOccurrences(of: "{radius_km}", with: String(Int(settings.radiusKM)))

        guard let url = URL(string: urlString) else {
            handleError("Invalid custom URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        performRequest(request) { [weak self] data in
            // Try to auto-detect format
            try self?.parseAutoDetectResponse(data: data, center: center) ?? []
        }
    }

    // MARK: - Response Parsers

    private func parseOpenSkyResponse(data: Data, center: CLLocationCoordinate2D) throws -> [Aircraft] {
        guard !data.isEmpty else {
            throw ADSBError.emptyResponse
        }

        if let responseString = String(data: data, encoding: .utf8) {
            let trimmed = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("<!") || trimmed.hasPrefix("<html") || trimmed.hasPrefix("<HTML") {
                if responseString.contains("429") || responseString.contains("Too Many Requests") {
                    throw ADSBError.rateLimited
                }
                throw ADSBError.serverError
            }
        }

        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ADSBError.invalidFormat
            }
            json = parsed
        } catch {
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? "Unable to decode"
            print("OpenSky parse error: \(error.localizedDescription), response: \(preview)")
            throw ADSBError.parseError
        }

        guard let states = json["states"] as? [[Any]] else {
            return []
        }

        return parseOpenSkyStates(states, center: center)
    }

    private func parseOpenSkyStates(_ states: [[Any]], center: CLLocationCoordinate2D) -> [Aircraft] {
        var aircraftList: [Aircraft] = []
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        for state in states {
            guard state.count >= 17,
                  let icao24 = state[0] as? String,
                  let longitude = state[5] as? Double,
                  let latitude = state[6] as? Double else {
                continue
            }

            let callsign = (state[1] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
            let originCountry = state[2] as? String ?? ""
            let altitude = state[7] as? Double ?? state[13] as? Double ?? 0
            let onGround = state[8] as? Bool ?? false
            let velocity = state[9] as? Double ?? 0
            let heading = state[10] as? Double ?? 0
            let verticalRate = state[11] as? Double ?? 0

            let altitudeFeet = Int(altitude * 3.28084)
            if altitudeFeet < settings.minAltitudeFeet || altitudeFeet > settings.maxAltitudeFeet {
                continue
            }

            if onGround && !settings.showOnGround {
                continue
            }

            let aircraftLocation = CLLocation(latitude: latitude, longitude: longitude)
            let distanceKM = centerLocation.distance(from: aircraftLocation) / 1000
            if distanceKM > settings.radiusKM {
                continue
            }

            aircraftList.append(Aircraft(
                id: icao24,
                callsign: callsign,
                originCountry: originCountry,
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                altitude: altitude,
                velocity: velocity,
                heading: heading,
                verticalRate: verticalRate,
                onGround: onGround,
                lastUpdate: Date()
            ))
        }

        return aircraftList.sorted { $0.altitude > $1.altitude }
    }

    private func parseADSBExchangeResponse(data: Data, center: CLLocationCoordinate2D) throws -> [Aircraft] {
        guard !data.isEmpty else {
            throw ADSBError.emptyResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ac = json["ac"] as? [[String: Any]] else {
            throw ADSBError.invalidFormat
        }

        var aircraftList: [Aircraft] = []

        for entry in ac {
            guard let hex = entry["hex"] as? String,
                  let lat = entry["lat"] as? Double,
                  let lon = entry["lon"] as? Double else {
                continue
            }

            let flight = (entry["flight"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
            let altBaro = entry["alt_baro"] as? Double ?? entry["alt_geom"] as? Double ?? 0
            let gs = entry["gs"] as? Double ?? 0
            let track = entry["track"] as? Double ?? 0
            let baroRate = entry["baro_rate"] as? Double ?? 0
            let onGround = (entry["alt_baro"] as? String) == "ground"

            if onGround && !settings.showOnGround {
                continue
            }

            let altitudeMeters = altBaro * 0.3048
            aircraftList.append(Aircraft(
                id: hex,
                callsign: flight,
                originCountry: "",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: altitudeMeters,
                velocity: gs * 0.514444,
                heading: track,
                verticalRate: baroRate * 0.00508,
                onGround: onGround,
                lastUpdate: Date()
            ))
        }

        return aircraftList.sorted { $0.altitude > $1.altitude }
    }

    private func parseADSBLolResponse(data: Data, center: CLLocationCoordinate2D) throws -> [Aircraft] {
        // ADSB.lol uses same format as ADS-B Exchange
        return try parseADSBExchangeResponse(data: data, center: center)
    }

    private func parseFlightRadar24Response(data: Data, center: CLLocationCoordinate2D) throws -> [Aircraft] {
        guard !data.isEmpty else {
            throw ADSBError.emptyResponse
        }

        // Log response for debugging
        if let responseString = String(data: data.prefix(500), encoding: .utf8) {
            print("FR24 Response: \(responseString)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ADSBError.invalidFormat
        }

        var aircraftList: [Aircraft] = []

        // Official FR24 API format: { "data": [...] }
        if let dataArray = json["data"] as? [[String: Any]] {
            for flight in dataArray {
                guard let lat = flight["lat"] as? Double,
                      let lon = flight["lon"] as? Double else {
                    continue
                }

                let flightId = flight["fr24_id"] as? String ?? flight["hex"] as? String ?? UUID().uuidString
                let callsign = (flight["callsign"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                let altitude = (flight["alt"] as? Double ?? 0) * 0.3048  // feet to meters
                let speed = (flight["gspeed"] as? Double ?? 0) * 0.514444  // knots to m/s
                let track = flight["track"] as? Double ?? 0
                let vspeed = (flight["vspeed"] as? Double ?? 0) * 0.00508  // fpm to m/s
                let onGround = flight["on_ground"] as? Bool ?? (altitude < 100)

                aircraftList.append(Aircraft(
                    id: flightId,
                    callsign: callsign,
                    originCountry: "",
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    altitude: altitude,
                    velocity: speed,
                    heading: track,
                    verticalRate: vspeed,
                    onGround: onGround,
                    lastUpdate: Date()
                ))
            }
        }
        // Legacy/fallback format: { "key": [array] }
        else {
            for (key, value) in json {
                guard !["full_count", "version", "stats", "error", "message"].contains(key),
                      let flightData = value as? [Any],
                      flightData.count >= 14 else {
                    continue
                }

                let lat = flightData[1] as? Double ?? 0
                let lon = flightData[2] as? Double ?? 0
                let track = flightData[3] as? Double ?? 0
                let altitude = (flightData[4] as? Double ?? 0) * 0.3048
                let speed = (flightData[5] as? Double ?? 0) * 0.514444
                let callsign = (flightData[13] as? String) ?? key

                aircraftList.append(Aircraft(
                    id: key,
                    callsign: callsign,
                    originCountry: "",
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    altitude: altitude,
                    velocity: speed,
                    heading: track,
                    verticalRate: 0,
                    onGround: altitude < 100,
                    lastUpdate: Date()
                ))
            }
        }

        // Check for error response
        if aircraftList.isEmpty {
            if let error = json["error"] as? String {
                throw ADSBError.networkError(error)
            }
            if let message = json["message"] as? String {
                throw ADSBError.networkError(message)
            }
        }

        return aircraftList.sorted { $0.altitude > $1.altitude }
    }

    private func parseFlightAwareResponse(data: Data, center: CLLocationCoordinate2D) throws -> [Aircraft] {
        guard !data.isEmpty else {
            throw ADSBError.emptyResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let flights = json["flights"] as? [[String: Any]] else {
            throw ADSBError.invalidFormat
        }

        var aircraftList: [Aircraft] = []

        for flight in flights {
            guard let ident = flight["ident"] as? String,
                  let lastPosition = flight["last_position"] as? [String: Any],
                  let lat = lastPosition["latitude"] as? Double,
                  let lon = lastPosition["longitude"] as? Double else {
                continue
            }

            let altitude = (lastPosition["altitude"] as? Double ?? 0) * 0.3048
            let heading = lastPosition["heading"] as? Double ?? 0
            let speed = (lastPosition["groundspeed"] as? Double ?? 0) * 0.514444

            aircraftList.append(Aircraft(
                id: flight["fa_flight_id"] as? String ?? ident,
                callsign: ident,
                originCountry: "",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: altitude,
                velocity: speed,
                heading: heading,
                verticalRate: 0,
                onGround: altitude < 100,
                lastUpdate: Date()
            ))
        }

        return aircraftList.sorted { $0.altitude > $1.altitude }
    }

    private func parseAutoDetectResponse(data: Data, center: CLLocationCoordinate2D) throws -> [Aircraft] {
        // Try different formats in order
        if let aircraft = try? parseADSBExchangeResponse(data: data, center: center), !aircraft.isEmpty {
            return aircraft
        }
        if let aircraft = try? parseOpenSkyResponse(data: data, center: center), !aircraft.isEmpty {
            return aircraft
        }
        if let aircraft = try? parseFlightRadar24Response(data: data, center: center), !aircraft.isEmpty {
            return aircraft
        }

        throw ADSBError.invalidFormat
    }

    // MARK: - Helper Methods

    private func performRequest(_ request: URLRequest, parser: @escaping (Data) throws -> [Aircraft]) {
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output -> Data in
                // Check HTTP status code
                if let httpResponse = output.response as? HTTPURLResponse {
                    print("ADSB API Response: \(httpResponse.statusCode) for \(request.url?.host ?? "unknown")")

                    switch httpResponse.statusCode {
                    case 200...299:
                        return output.data
                    case 401:
                        // Log the response body for debugging
                        if let body = String(data: output.data, encoding: .utf8) {
                            print("401 Unauthorized response: \(body)")
                        }
                        throw ADSBError.networkError("Invalid API key - check your credentials")
                    case 403:
                        throw ADSBError.networkError("Access forbidden - API key may lack permissions")
                    case 429:
                        throw ADSBError.rateLimited
                    default:
                        if let body = String(data: output.data, encoding: .utf8) {
                            print("API Error (\(httpResponse.statusCode)): \(body)")
                        }
                        throw ADSBError.networkError("Server error: \(httpResponse.statusCode)")
                    }
                }
                return output.data
            }
            .tryMap { data -> [Aircraft] in
                try parser(data)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let err) = completion {
                        if let adsbError = err as? ADSBError {
                            self?.error = adsbError.localizedDescription
                        } else {
                            self?.error = err.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] aircraft in
                    self?.aircraft = aircraft
                    self?.lastUpdate = Date()
                    self?.error = nil
                }
            )
            .store(in: &cancellables)
    }

    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.error = message
        }
    }

    private func getSearchCenter() -> CLLocationCoordinate2D? {
        if settings.useCurrentLocation {
            return LocationManager.shared.location?.coordinate
        } else if let lat = settings.customLatitude, let lon = settings.customLongitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }

    // MARK: - Settings Persistence

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    private func loadSettings() -> ADSBTrafficSettings {
        // Try new key first
        if let data = userDefaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(ADSBTrafficSettings.self, from: data) {
            return settings
        }
        // Try legacy key
        if let data = userDefaults.data(forKey: "adsb_traffic_settings"),
           let settings = try? JSONDecoder().decode(ADSBTrafficSettings.self, from: data) {
            return settings
        }
        return ADSBTrafficSettings()
    }
}

// MARK: - Error Types

enum ADSBError: LocalizedError {
    case emptyResponse
    case rateLimited
    case serverError
    case invalidFormat
    case parseError
    case apiKeyRequired
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Empty response from server"
        case .rateLimited:
            return "Rate limit exceeded. Try again in a few minutes."
        case .serverError:
            return "Server returned an error. Try again later."
        case .invalidFormat:
            return "Unexpected response format"
        case .parseError:
            return "Failed to parse response data"
        case .apiKeyRequired:
            return "API key required for this provider"
        case .networkError(let message):
            return message
        }
    }
}
