//
//  TurnByTurnNavigationService.swift
//  OmniTAKMobile
//
//  Comprehensive turn-by-turn navigation service with voice guidance
//

import Foundation
import CoreLocation
import MapKit
import Combine
import AVFoundation
import UIKit

// MARK: - Navigation Instruction Types

/// Types of navigation maneuvers
enum ManeuverType: String, Codable {
    case turnLeft = "turn_left"
    case turnRight = "turn_right"
    case turnSlightLeft = "turn_slight_left"
    case turnSlightRight = "turn_slight_right"
    case turnSharpLeft = "turn_sharp_left"
    case turnSharpRight = "turn_sharp_right"
    case uTurn = "u_turn"
    case straight = "straight"
    case merge = "merge"
    case takeRamp = "take_ramp"
    case keepLeft = "keep_left"
    case keepRight = "keep_right"
    case roundabout = "roundabout"
    case arrive = "arrive"
    case depart = "depart"

    var icon: String {
        switch self {
        case .turnLeft: return "arrow.turn.up.left"
        case .turnRight: return "arrow.turn.up.right"
        case .turnSlightLeft: return "arrow.up.left"
        case .turnSlightRight: return "arrow.up.right"
        case .turnSharpLeft: return "arrow.turn.left.up"
        case .turnSharpRight: return "arrow.turn.right.up"
        case .uTurn: return "arrow.uturn.left"
        case .straight: return "arrow.up"
        case .merge: return "arrow.merge"
        case .takeRamp: return "arrow.up.right.square"
        case .keepLeft: return "arrow.up.left.square"
        case .keepRight: return "arrow.up.right.square"
        case .roundabout: return "arrow.triangle.2.circlepath"
        case .arrive: return "flag.checkered"
        case .depart: return "location.fill"
        }
    }

    var voiceInstruction: String {
        switch self {
        case .turnLeft: return "Turn left"
        case .turnRight: return "Turn right"
        case .turnSlightLeft: return "Bear left"
        case .turnSlightRight: return "Bear right"
        case .turnSharpLeft: return "Turn sharp left"
        case .turnSharpRight: return "Turn sharp right"
        case .uTurn: return "Make a U-turn"
        case .straight: return "Continue straight"
        case .merge: return "Merge"
        case .takeRamp: return "Take the ramp"
        case .keepLeft: return "Keep left"
        case .keepRight: return "Keep right"
        case .roundabout: return "Enter the roundabout"
        case .arrive: return "You have arrived"
        case .depart: return "Depart"
        }
    }
}

// MARK: - Navigation Instruction

/// A single navigation instruction/step
struct NavigationInstruction: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ManeuverType
    let distance: CLLocationDistance // Distance to execute this maneuver
    let streetName: String?
    let instruction: String // Human-readable instruction
    let coordinate: CLLocationCoordinate2D

    init(
        id: UUID = UUID(),
        type: ManeuverType,
        distance: CLLocationDistance,
        streetName: String? = nil,
        instruction: String? = nil,
        coordinate: CLLocationCoordinate2D
    ) {
        self.id = id
        self.type = type
        self.distance = distance
        self.streetName = streetName
        self.coordinate = coordinate

        // Generate human-readable instruction if not provided
        if let instruction = instruction {
            self.instruction = instruction
        } else {
            self.instruction = NavigationInstruction.generateInstruction(
                type: type,
                distance: distance,
                streetName: streetName
            )
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, type, distance, streetName, instruction, latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ManeuverType.self, forKey: .type)
        distance = try container.decode(CLLocationDistance.self, forKey: .distance)
        streetName = try container.decodeIfPresent(String.self, forKey: .streetName)
        instruction = try container.decode(String.self, forKey: .instruction)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(distance, forKey: .distance)
        try container.encodeIfPresent(streetName, forKey: .streetName)
        try container.encode(instruction, forKey: .instruction)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }

    static func == (lhs: NavigationInstruction, rhs: NavigationInstruction) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Instruction Generation

    /// Generate a human-readable instruction
    static func generateInstruction(type: ManeuverType, distance: CLLocationDistance, streetName: String?) -> String {
        let distanceText = formatDistanceForSpeech(distance)
        let streetText = streetName.map { " onto \($0)" } ?? ""

        switch type {
        case .arrive:
            return "You have arrived at your destination"
        case .depart:
            if let street = streetName {
                return "Head toward \(street)"
            }
            return "Depart and follow the route"
        case .straight:
            return "Continue straight for \(distanceText)\(streetText)"
        default:
            return "\(type.voiceInstruction) in \(distanceText)\(streetText)"
        }
    }

    /// Format distance for speech output
    static func formatDistanceForSpeech(_ distance: CLLocationDistance) -> String {
        if distance < 50 {
            return "less than 50 meters"
        } else if distance < 100 {
            return "\(Int(round(distance / 10) * 10)) meters"
        } else if distance < 1000 {
            let rounded = Int(round(distance / 50) * 50)
            return "\(rounded) meters"
        } else {
            let km = distance / 1000
            if km < 10 {
                return String(format: "%.1f kilometers", km)
            } else {
                return "\(Int(km)) kilometers"
            }
        }
    }
}

// MARK: - Navigation Event Notifications

extension Notification.Name {
    static let navigationStarted = Notification.Name("TurnByTurnNavigationStarted")
    static let navigationStopped = Notification.Name("TurnByTurnNavigationStopped")
    static let navigationPaused = Notification.Name("TurnByTurnNavigationPaused")
    static let navigationResumed = Notification.Name("TurnByTurnNavigationResumed")
    static let waypointReached = Notification.Name("TurnByTurnWaypointReached")
    static let arrivalReached = Notification.Name("TurnByTurnArrivalReached")
    static let offRoute = Notification.Name("TurnByTurnOffRoute")
    static let routeRecalculated = Notification.Name("TurnByTurnRouteRecalculated")
    static let instructionChanged = Notification.Name("TurnByTurnInstructionChanged")
}

// MARK: - Turn-by-Turn Navigation Service

/// Comprehensive turn-by-turn navigation service with voice guidance
class TurnByTurnNavigationService: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isNavigating: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentRoute: Route?
    @Published var currentStepIndex: Int = 0
    @Published var distanceToNextTurn: CLLocationDistance = 0
    @Published var timeToArrival: TimeInterval = 0
    @Published var currentInstruction: String = ""
    @Published var nextInstruction: String?
    @Published var bearing: Double = 0
    @Published var voiceGuidanceEnabled: Bool = true
    @Published var currentLocation: CLLocation?
    @Published var navigationInstructions: [NavigationInstruction] = []
    @Published var isOffRoute: Bool = false
    @Published var speedKmh: Double = 0
    @Published var distanceRemaining: CLLocationDistance = 0
    @Published var percentComplete: Double = 0

    // MARK: - Singleton

    static let shared = TurnByTurnNavigationService()

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()

    // Configuration
    private var waypointReachedThreshold: CLLocationDistance = 25.0 // meters
    private var offRouteThreshold: CLLocationDistance = 50.0 // meters
    private var recalculationCooldown: TimeInterval = 10.0 // seconds
    private var lastRecalculationTime: Date?

    // Voice guidance thresholds (distances in meters)
    private let voiceAnnouncementDistances: [CLLocationDistance] = [500, 200, 50, 10]
    private var lastAnnouncedDistance: CLLocationDistance = .infinity
    private var hasAnnouncedArrival: Bool = false

    // Speed tracking
    private var speedSamples: [Double] = []
    private let maxSpeedSamples = 10
    private var averageSpeed: Double = 0

    // Voice settings
    var voiceRate: Float = AVSpeechUtteranceDefaultSpeechRate
    var voiceLanguage: String = "en-US"
    var voicePitch: Float = 1.0
    var voiceVolume: Float = 1.0

    // Transport type for routing
    var transportType: TransportType = .automobile

    // MARK: - Initialization

    override init() {
        super.init()
        setupLocationManager()
        setupAudioSession()
        setupSpeechSynthesizer()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5.0 // Update every 5 meters
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.requestWhenInUseAuthorization()
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }

    private func setupSpeechSynthesizer() {
        speechSynthesizer.delegate = self
    }

    // MARK: - Navigation Control Methods

    /// Start navigation to a specific destination coordinate
    func startNavigation(to destination: CLLocationCoordinate2D) {
        guard let currentLoc = currentLocation else {
            print("Current location not available for navigation")
            locationManager.requestLocation()
            return
        }

        // Calculate route using MapKit Directions
        calculateRoute(from: currentLoc.coordinate, to: destination) { [weak self] result in
            switch result {
            case .success(let mkRoute):
                self?.startNavigationWithMKRoute(mkRoute, to: destination)
            case .failure(let error):
                print("Failed to calculate route: \(error.localizedDescription)")
            }
        }
    }

    /// Start navigation with a pre-defined Route object
    func startNavigation(route: Route) {
        guard route.waypoints.count >= 2 else {
            print("Route must have at least 2 waypoints")
            return
        }

        currentRoute = route
        currentStepIndex = 0
        isNavigating = true
        isPaused = false
        isOffRoute = false
        hasAnnouncedArrival = false
        lastAnnouncedDistance = .infinity

        // Parse route waypoints into navigation instructions
        parseRouteInstructions(from: route)

        // Update current instruction
        updateCurrentInstruction()

        // Start location updates
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()

        // Announce start
        if voiceGuidanceEnabled {
            speak(text: "Navigation started. \(currentInstruction)")
        }

        // Post notification
        NotificationCenter.default.post(name: .navigationStarted, object: self, userInfo: ["route": route])

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        print("Navigation started for route: \(route.name)")
    }

    /// Stop navigation
    func stopNavigation() {
        isNavigating = false
        isPaused = false
        currentRoute = nil
        currentStepIndex = 0
        navigationInstructions.removeAll()
        distanceToNextTurn = 0
        timeToArrival = 0
        currentInstruction = ""
        nextInstruction = nil
        isOffRoute = false
        percentComplete = 0
        distanceRemaining = 0

        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()

        speechSynthesizer.stopSpeaking(at: .immediate)

        // Post notification
        NotificationCenter.default.post(name: .navigationStopped, object: self)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        print("Navigation stopped")
    }

    /// Pause navigation (keeps route but stops guidance)
    func pauseNavigation() {
        guard isNavigating && !isPaused else { return }

        isPaused = true
        speechSynthesizer.stopSpeaking(at: .immediate)

        NotificationCenter.default.post(name: .navigationPaused, object: self)

        print("Navigation paused")
    }

    /// Resume paused navigation
    func resumeNavigation() {
        guard isNavigating && isPaused else { return }

        isPaused = false

        // Re-announce current instruction
        if voiceGuidanceEnabled {
            speak(text: "Navigation resumed. \(currentInstruction)")
        }

        NotificationCenter.default.post(name: .navigationResumed, object: self)

        print("Navigation resumed")
    }

    /// Recalculate the route from current position
    func recalculateRoute() {
        guard isNavigating,
              let route = currentRoute,
              let currentLoc = currentLocation,
              !route.waypoints.isEmpty else { return }

        // Check cooldown
        if let lastTime = lastRecalculationTime,
           Date().timeIntervalSince(lastTime) < recalculationCooldown {
            print("Route recalculation on cooldown")
            return
        }

        lastRecalculationTime = Date()

        // Get remaining destination
        let destinationIndex = min(currentStepIndex + 1, route.waypoints.count - 1)
        let destination = route.waypoints[destinationIndex].coordinate

        calculateRoute(from: currentLoc.coordinate, to: destination) { [weak self] result in
            switch result {
            case .success(let mkRoute):
                DispatchQueue.main.async {
                    self?.updateRouteWithMKRoute(mkRoute)
                    self?.isOffRoute = false

                    if self?.voiceGuidanceEnabled == true {
                        self?.speak(text: "Route recalculated")
                    }

                    NotificationCenter.default.post(name: .routeRecalculated, object: self)
                }
            case .failure(let error):
                print("Failed to recalculate route: \(error.localizedDescription)")
            }
        }
    }

    /// Skip to the next waypoint in the route
    func skipToNextWaypoint() {
        guard isNavigating,
              let route = currentRoute,
              currentStepIndex < route.waypoints.count - 1 else { return }

        currentStepIndex += 1
        updateCurrentInstruction()
        lastAnnouncedDistance = .infinity

        if voiceGuidanceEnabled {
            speak(text: "Skipped to next waypoint. \(currentInstruction)")
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        print("Skipped to waypoint index: \(currentStepIndex)")
    }

    // MARK: - Route Calculation

    private func calculateRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        completion: @escaping (Result<MKRoute, Error>) -> Void
    ) {
        let request = MKDirections.Request()

        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)

        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = transportType.mkTransportType
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        directions.calculate { response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let route = response?.routes.first else {
                completion(.failure(NavigationError.noRouteFound))
                return
            }

            completion(.success(route))
        }
    }

    private func startNavigationWithMKRoute(_ mkRoute: MKRoute, to destination: CLLocationCoordinate2D) {
        // Create a Route object from MKRoute
        var waypoints: [RouteWaypoint] = []

        // Add start waypoint
        if let currentLoc = currentLocation {
            let startWaypoint = RouteWaypoint(
                coordinate: currentLoc.coordinate,
                name: "Start",
                order: 0
            )
            waypoints.append(startWaypoint)
        }

        // Add destination waypoint
        let endWaypoint = RouteWaypoint(
            coordinate: destination,
            name: "Destination",
            order: 1
        )
        waypoints.append(endWaypoint)

        let route = Route(
            name: "Navigation Route",
            waypoints: waypoints,
            totalDistance: mkRoute.distance,
            estimatedTime: mkRoute.expectedTravelTime
        )

        // Parse MKRoute steps
        navigationInstructions = parseMKRouteSteps(mkRoute)

        currentRoute = route
        currentStepIndex = 0
        isNavigating = true
        isPaused = false
        isOffRoute = false
        hasAnnouncedArrival = false
        lastAnnouncedDistance = .infinity

        updateCurrentInstruction()

        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()

        if voiceGuidanceEnabled {
            speak(text: "Navigation started. \(currentInstruction)")
        }

        NotificationCenter.default.post(name: .navigationStarted, object: self, userInfo: ["route": route])

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func updateRouteWithMKRoute(_ mkRoute: MKRoute) {
        navigationInstructions = parseMKRouteSteps(mkRoute)
        currentStepIndex = 0
        updateCurrentInstruction()
    }

    /// Parse MKRoute steps into NavigationInstructions
    private func parseMKRouteSteps(_ mkRoute: MKRoute) -> [NavigationInstruction] {
        var instructions: [NavigationInstruction] = []

        for (_, step) in mkRoute.steps.enumerated() {
            guard !step.instructions.isEmpty else { continue }

            let maneuverType = determineManeuverType(from: step.instructions)

            let instruction = NavigationInstruction(
                type: maneuverType,
                distance: step.distance,
                streetName: extractStreetName(from: step.instructions),
                instruction: step.instructions,
                coordinate: step.polyline.coordinate
            )

            instructions.append(instruction)
        }

        // Add arrival instruction if not present
        if let lastInstruction = instructions.last, lastInstruction.type != .arrive {
            let arrivalInstruction = NavigationInstruction(
                type: .arrive,
                distance: 0,
                streetName: nil,
                coordinate: mkRoute.polyline.points()[mkRoute.polyline.pointCount - 1].coordinate
            )
            instructions.append(arrivalInstruction)
        }

        return instructions
    }

    /// Parse Route waypoints into NavigationInstructions
    private func parseRouteInstructions(from route: Route) {
        var instructions: [NavigationInstruction] = []

        // Generate instructions from waypoints
        for (index, waypoint) in route.waypoints.enumerated() {
            let isLast = index == route.waypoints.count - 1
            let type: ManeuverType = isLast ? .arrive : (index == 0 ? .depart : .straight)
            let distance = waypoint.distanceToNext ?? 0

            let instruction = NavigationInstruction(
                type: type,
                distance: distance,
                streetName: waypoint.name,
                instruction: waypoint.instruction ?? (isLast ? "You have arrived at \(waypoint.name)" : "Continue to \(waypoint.name)"),
                coordinate: waypoint.coordinate
            )

            instructions.append(instruction)
        }

        // If segments have more detailed instructions, use those
        if !route.segments.isEmpty {
            var segmentInstructions: [NavigationInstruction] = []

            for segment in route.segments {
                for instructionText in segment.instructions {
                    let type = determineManeuverType(from: instructionText)
                    let coord = segment.path.first ?? CLLocationCoordinate2D()

                    let instruction = NavigationInstruction(
                        type: type,
                        distance: segment.distance / Double(max(segment.instructions.count, 1)),
                        streetName: extractStreetName(from: instructionText),
                        instruction: instructionText,
                        coordinate: coord
                    )

                    segmentInstructions.append(instruction)
                }
            }

            if !segmentInstructions.isEmpty {
                instructions = segmentInstructions
            }
        }

        navigationInstructions = instructions
    }

    /// Determine maneuver type from instruction text
    private func determineManeuverType(from instruction: String) -> ManeuverType {
        let lowercased = instruction.lowercased()

        if lowercased.contains("arrive") || lowercased.contains("destination") {
            return .arrive
        } else if lowercased.contains("u-turn") || lowercased.contains("uturn") {
            return .uTurn
        } else if lowercased.contains("sharp left") {
            return .turnSharpLeft
        } else if lowercased.contains("sharp right") {
            return .turnSharpRight
        } else if lowercased.contains("slight left") || lowercased.contains("bear left") {
            return .turnSlightLeft
        } else if lowercased.contains("slight right") || lowercased.contains("bear right") {
            return .turnSlightRight
        } else if lowercased.contains("turn left") || lowercased.contains("left onto") {
            return .turnLeft
        } else if lowercased.contains("turn right") || lowercased.contains("right onto") {
            return .turnRight
        } else if lowercased.contains("keep left") {
            return .keepLeft
        } else if lowercased.contains("keep right") {
            return .keepRight
        } else if lowercased.contains("merge") {
            return .merge
        } else if lowercased.contains("ramp") || lowercased.contains("exit") {
            return .takeRamp
        } else if lowercased.contains("roundabout") || lowercased.contains("circle") {
            return .roundabout
        } else if lowercased.contains("head") || lowercased.contains("depart") {
            return .depart
        } else {
            return .straight
        }
    }

    /// Extract street name from instruction text
    private func extractStreetName(from instruction: String) -> String? {
        let patterns = [
            "onto (.+?)$",
            "toward (.+?)$",
            "on (.+?)$",
            "via (.+?)$"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: instruction, range: NSRange(instruction.startIndex..., in: instruction)),
               let range = Range(match.range(at: 1), in: instruction) {
                return String(instruction[range])
            }
        }

        return nil
    }

    // MARK: - Navigation Updates

    private func updateNavigationProgress(with location: CLLocation) {
        guard isNavigating, !isPaused, !navigationInstructions.isEmpty else { return }

        // Update speed
        updateSpeed(location.speed)

        // Calculate distance to next instruction point
        if currentStepIndex < navigationInstructions.count {
            let nextInstruction = navigationInstructions[currentStepIndex]
            let nextLocation = CLLocation(latitude: nextInstruction.coordinate.latitude,
                                         longitude: nextInstruction.coordinate.longitude)
            distanceToNextTurn = location.distance(from: nextLocation)

            // Calculate bearing
            bearing = calculateBearing(from: location.coordinate, to: nextInstruction.coordinate)

            // Check if reached current waypoint
            if distanceToNextTurn < waypointReachedThreshold {
                advanceToNextInstruction()
            } else {
                // Check for voice announcements
                checkVoiceAnnouncements()
            }
        }

        // Update overall progress
        updateOverallProgress()

        // Check for off-route
        checkOffRoute(location)
    }

    private func advanceToNextInstruction() {
        guard currentStepIndex < navigationInstructions.count - 1 else {
            // Arrived at final destination
            if !hasAnnouncedArrival {
                announceArrival()
                hasAnnouncedArrival = true
            }
            return
        }

        currentStepIndex += 1
        lastAnnouncedDistance = .infinity

        updateCurrentInstruction()

        // Haptic feedback for waypoint reached
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Post notification
        NotificationCenter.default.post(
            name: .waypointReached,
            object: self,
            userInfo: ["stepIndex": currentStepIndex]
        )

        // Announce next turn
        if voiceGuidanceEnabled {
            announceNextTurn()
        }

        print("Advanced to instruction \(currentStepIndex)")
    }

    private func updateCurrentInstruction() {
        guard !navigationInstructions.isEmpty else {
            currentInstruction = "Calculating route..."
            nextInstruction = nil
            return
        }

        if currentStepIndex < navigationInstructions.count {
            let instruction = navigationInstructions[currentStepIndex]
            currentInstruction = instruction.instruction

            // Get next instruction preview
            if currentStepIndex + 1 < navigationInstructions.count {
                let next = navigationInstructions[currentStepIndex + 1]
                nextInstruction = next.instruction
            } else {
                nextInstruction = nil
            }
        }

        NotificationCenter.default.post(name: .instructionChanged, object: self)
    }

    private func updateOverallProgress() {
        guard let route = currentRoute else { return }

        // Calculate remaining distance
        var remaining = distanceToNextTurn
        for i in (currentStepIndex + 1)..<navigationInstructions.count {
            remaining += navigationInstructions[i].distance
        }
        distanceRemaining = remaining

        // Calculate time to arrival based on average speed
        if averageSpeed > 0 {
            timeToArrival = remaining / averageSpeed
        } else {
            // Use route's estimated time scaled by progress
            let totalDistance = route.totalDistance > 0 ? route.totalDistance : 1
            let traveled = totalDistance - remaining
            percentComplete = (traveled / totalDistance) * 100
            timeToArrival = route.estimatedTime * (remaining / totalDistance)
        }

        // Update percent complete
        if route.totalDistance > 0 {
            let traveled = route.totalDistance - remaining
            percentComplete = min(100, max(0, (traveled / route.totalDistance) * 100))
        }
    }

    private func updateSpeed(_ currentSpeed: CLLocationSpeed) {
        guard currentSpeed >= 0 else { return }

        speedSamples.append(currentSpeed)
        if speedSamples.count > maxSpeedSamples {
            speedSamples.removeFirst()
        }

        averageSpeed = speedSamples.reduce(0, +) / Double(speedSamples.count)
        speedKmh = averageSpeed * 3.6
    }

    private func checkOffRoute(_ location: CLLocation) {
        guard !navigationInstructions.isEmpty, currentStepIndex < navigationInstructions.count else { return }

        // Check if too far from the current instruction's expected path
        let currentInstruct = navigationInstructions[currentStepIndex]
        let expectedLocation = CLLocation(latitude: currentInstruct.coordinate.latitude,
                                         longitude: currentInstruct.coordinate.longitude)

        let distanceFromPath = location.distance(from: expectedLocation)

        // If significantly off expected path and not near the waypoint
        if distanceFromPath > offRouteThreshold && distanceToNextTurn > offRouteThreshold {
            if !isOffRoute {
                isOffRoute = true

                if voiceGuidanceEnabled {
                    speak(text: "You appear to be off route. Recalculating.")
                }

                NotificationCenter.default.post(name: .offRoute, object: self)

                // Auto-recalculate
                recalculateRoute()
            }
        } else {
            isOffRoute = false
        }
    }

    // MARK: - Voice Guidance

    /// Speak text using text-to-speech
    func speak(text: String) {
        guard voiceGuidanceEnabled else { return }

        // Stop any current speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .word)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = voiceRate
        utterance.pitchMultiplier = voicePitch
        utterance.volume = voiceVolume
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguage)

        // Prefetch for better quality
        utterance.prefersAssistiveTechnologySettings = false

        speechSynthesizer.speak(utterance)
    }

    /// Announce the next turn based on distance
    func announceNextTurn() {
        guard isNavigating, !isPaused, currentStepIndex < navigationInstructions.count else { return }

        let instruction = navigationInstructions[currentStepIndex]
        var announcement = ""

        if distanceToNextTurn > 500 {
            announcement = instruction.instruction
        } else if distanceToNextTurn > 200 {
            announcement = "\(instruction.type.voiceInstruction) in \(NavigationInstruction.formatDistanceForSpeech(distanceToNextTurn))"
        } else if distanceToNextTurn > 50 {
            announcement = "\(instruction.type.voiceInstruction) in \(Int(distanceToNextTurn)) meters"
        } else {
            announcement = "\(instruction.type.voiceInstruction) now"
        }

        speak(text: announcement)
    }

    /// Announce arrival at destination
    func announceArrival() {
        speak(text: "You have arrived at your destination")

        NotificationCenter.default.post(name: .arrivalReached, object: self)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        print("Arrived at destination")
    }

    private func checkVoiceAnnouncements() {
        guard voiceGuidanceEnabled, !isPaused else { return }

        for threshold in voiceAnnouncementDistances {
            if distanceToNextTurn <= threshold && lastAnnouncedDistance > threshold {
                lastAnnouncedDistance = threshold
                announceNextTurn()
                break
            }
        }
    }

    // MARK: - Utility Methods

    /// Calculate bearing from one coordinate to another
    func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        let degreesBearing = radiansBearing * 180 / .pi

        return (degreesBearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Get formatted time to arrival string
    var formattedTimeToArrival: String {
        let hours = Int(timeToArrival) / 3600
        let minutes = (Int(timeToArrival) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%d min", minutes)
        }
    }

    /// Get formatted ETA
    var formattedETA: String {
        let arrivalDate = Date().addingTimeInterval(timeToArrival)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: arrivalDate)
    }

    /// Get formatted distance remaining
    var formattedDistanceRemaining: String {
        distanceRemaining.formattedDistance
    }

    /// Get formatted speed
    var formattedSpeed: String {
        String(format: "%.1f km/h", speedKmh)
    }

    /// Get current maneuver icon
    var currentManeuverIcon: String {
        guard currentStepIndex < navigationInstructions.count else {
            return "arrow.up"
        }
        return navigationInstructions[currentStepIndex].type.icon
    }

    /// Configure voice settings
    func configureVoice(rate: Float = AVSpeechUtteranceDefaultSpeechRate,
                        language: String = "en-US",
                        pitch: Float = 1.0,
                        volume: Float = 1.0) {
        voiceRate = rate
        voiceLanguage = language
        voicePitch = pitch
        voiceVolume = volume
    }

    /// Configure navigation thresholds
    func configureThresholds(waypointReached: CLLocationDistance = 25.0,
                             offRoute: CLLocationDistance = 50.0,
                             recalculationCooldown: TimeInterval = 10.0) {
        waypointReachedThreshold = waypointReached
        offRouteThreshold = offRoute
        self.recalculationCooldown = recalculationCooldown
    }
}

// MARK: - CLLocationManagerDelegate

extension TurnByTurnNavigationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        currentLocation = location

        if isNavigating && !isPaused {
            updateNavigationProgress(with: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Heading updates can be used for compass orientation
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location authorization granted for turn-by-turn navigation")
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location authorization denied")
        case .notDetermined:
            print("Location authorization not determined")
        @unknown default:
            break
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TurnByTurnNavigationService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        // Speech started
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Speech finished
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Speech cancelled
    }
}

// MARK: - Navigation Errors

enum NavigationError: LocalizedError {
    case noRouteFound
    case locationNotAvailable
    case insufficientWaypoints
    case calculationFailed

    var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "No route found to destination"
        case .locationNotAvailable:
            return "Current location not available"
        case .insufficientWaypoints:
            return "Route must have at least 2 waypoints"
        case .calculationFailed:
            return "Failed to calculate route"
        }
    }
}

// MARK: - Combine Publishers

extension TurnByTurnNavigationService {
    /// Publisher for navigation state changes
    var navigationStatePublisher: AnyPublisher<Bool, Never> {
        $isNavigating
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// Publisher for instruction changes
    var instructionPublisher: AnyPublisher<String, Never> {
        $currentInstruction
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// Publisher for distance to next turn
    var distancePublisher: AnyPublisher<CLLocationDistance, Never> {
        $distanceToNextTurn
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// Publisher for off-route detection
    var offRoutePublisher: AnyPublisher<Bool, Never> {
        $isOffRoute
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// Publisher for progress updates
    var progressPublisher: AnyPublisher<Double, Never> {
        $percentComplete
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
