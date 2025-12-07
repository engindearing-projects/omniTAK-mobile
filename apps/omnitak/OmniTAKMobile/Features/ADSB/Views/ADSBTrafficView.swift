//
//  ADSBTrafficView.swift
//  OmniTAKMobile
//
//  Configuration and status view for multi-provider ADS-B flight tracking
//

import SwiftUI
import CoreLocation

struct ADSBTrafficView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @ObservedObject var trafficService = ADSBTrafficService.shared
    @State private var zipCodeInput = ""
    @State private var isLookingUpZip = false
    @State private var zipLookupError: String?
    @State private var showProviderConfig = false
    @State private var selectedProviderForConfig: ADSBProvider?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Master Toggle Card
                        masterToggleCard

                        if trafficService.settings.isEnabled {
                            // Provider Selection Card
                            providerSelectionCard

                            // Location Settings Card
                            locationCard

                            // Display Settings Card
                            displaySettingsCard

                            // Status Card
                            statusCard

                            // Aircraft List
                            if !trafficService.aircraft.isEmpty {
                                aircraftListCard
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("ADS-B Traffic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
            .sheet(item: $selectedProviderForConfig) { provider in
                ProviderConfigSheet(provider: provider, trafficService: trafficService)
            }
        }
    }

    // MARK: - Master Toggle Card

    private var masterToggleCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "airplane")
                    .font(.system(size: 32))
                    .foregroundColor(trafficService.settings.isEnabled ? Color(hex: "#FFFC00") : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ADS-B Traffic")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Show aircraft on map")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { trafficService.settings.isEnabled },
                    set: { newValue in
                        var settings = trafficService.settings
                        settings.isEnabled = newValue
                        trafficService.settings = settings
                    }
                ))
                .labelsHidden()
                .tint(Color(hex: "#FFFC00"))
            }

            if trafficService.settings.isEnabled {
                HStack {
                    Image(systemName: trafficService.currentProvider.icon)
                        .foregroundColor(trafficService.currentProvider.color)
                    Text("Data from \(trafficService.currentProvider.displayName)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }

    // MARK: - Provider Selection Card

    private var providerSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("DATA SOURCE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()

                // Current provider indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(trafficService.settings.activeProvider.color)
                        .frame(width: 8, height: 8)
                    Text(trafficService.settings.activeProvider.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(trafficService.settings.activeProvider.color)
                }
            }

            // Provider list
            ForEach(ADSBProvider.allCases) { provider in
                ProviderRow(
                    provider: provider,
                    isActive: trafficService.settings.activeProvider == provider,
                    config: trafficService.settings.providers.first(where: { $0.provider == provider }),
                    onSelect: {
                        var settings = trafficService.settings
                        settings.activeProvider = provider
                        trafficService.settings = settings
                    },
                    onConfigure: {
                        selectedProviderForConfig = provider
                    }
                )
            }
        }
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }

    // MARK: - Location Card

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LOCATION")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            // Use Current Location Toggle
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(trafficService.settings.useCurrentLocation ? .blue : .gray)
                Text("Use Current Location")
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { trafficService.settings.useCurrentLocation },
                    set: { newValue in
                        var settings = trafficService.settings
                        settings.useCurrentLocation = newValue
                        trafficService.settings = settings
                    }
                ))
                .labelsHidden()
                .tint(Color(hex: "#FFFC00"))
            }

            // Custom Zip Code (when not using current location)
            if !trafficService.settings.useCurrentLocation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or enter ZIP code:")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)

                    HStack {
                        TextField("ZIP Code", text: $zipCodeInput)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)

                        Button(action: lookupZipCode) {
                            if isLookingUpZip {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Set Location")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#FFFC00"))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .disabled(zipCodeInput.isEmpty || isLookingUpZip)

                        Spacer()
                    }

                    if let error = zipLookupError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    if let lat = trafficService.settings.customLatitude,
                       let lon = trafficService.settings.customLongitude {
                        Text("Set to: \(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                }
            }

            Divider().background(Color.gray.opacity(0.3))

            // Radius Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Search Radius")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(trafficService.settings.radiusNM)) NM")
                        .foregroundColor(Color(hex: "#FFFC00"))
                        .font(.system(size: 14, weight: .semibold))
                }

                Slider(
                    value: Binding(
                        get: { trafficService.settings.radiusNM },
                        set: { newValue in
                            var settings = trafficService.settings
                            settings.radiusNM = newValue
                            trafficService.settings = settings
                        }
                    ),
                    in: 10...200,
                    step: 10
                )
                .tint(Color(hex: "#FFFC00"))

                HStack {
                    Text("10 NM")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("200 NM")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }

    // MARK: - Display Settings Card

    private var displaySettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DISPLAY OPTIONS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            // Show Ground Traffic
            HStack {
                Image(systemName: "airplane.arrival")
                    .foregroundColor(.gray)
                Text("Show Ground Traffic")
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { trafficService.settings.showOnGround },
                    set: { newValue in
                        var settings = trafficService.settings
                        settings.showOnGround = newValue
                        trafficService.settings = settings
                    }
                ))
                .labelsHidden()
                .tint(Color(hex: "#FFFC00"))
            }

            Divider().background(Color.gray.opacity(0.3))

            // Refresh Interval
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Refresh Interval")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(trafficService.settings.refreshIntervalSeconds)s")
                        .foregroundColor(Color(hex: "#FFFC00"))
                        .font(.system(size: 14, weight: .semibold))
                }

                let minInterval = trafficService.settings.minimumRefreshInterval
                Picker("", selection: Binding(
                    get: { trafficService.settings.refreshIntervalSeconds },
                    set: { newValue in
                        var settings = trafficService.settings
                        settings.refreshIntervalSeconds = max(newValue, minInterval)
                        trafficService.settings = settings
                    }
                )) {
                    if minInterval <= 2 { Text("2s").tag(2) }
                    if minInterval <= 5 { Text("5s").tag(5) }
                    Text("10s").tag(10)
                    Text("15s").tag(15)
                    Text("30s").tag(30)
                    Text("60s").tag(60)
                }
                .pickerStyle(.segmented)

                Text("Min \(minInterval)s for \(trafficService.settings.activeProvider.displayName)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STATUS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)

                Spacer()

                Button(action: {
                    trafficService.fetchAircraft()
                }) {
                    HStack(spacing: 4) {
                        if trafficService.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Refresh")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
                .disabled(trafficService.isLoading)
            }

            HStack(spacing: 20) {
                VStack {
                    Text("\(trafficService.aircraft.count)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "#FFFC00"))
                    Text("Aircraft")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }

                Spacer()

                if let lastUpdate = trafficService.lastUpdate {
                    VStack(alignment: .trailing) {
                        Text("Last Update")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(lastUpdate, style: .time)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }
            }

            if let error = trafficService.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }

    // MARK: - Aircraft List Card

    private var aircraftListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEARBY AIRCRAFT")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            // Category summary chips
            if !trafficService.aircraft.isEmpty {
                categoryChipsView
            }

            ForEach(trafficService.aircraft.prefix(10)) { aircraft in
                AircraftRow(aircraft: aircraft)
            }

            if trafficService.aircraft.count > 10 {
                Text("+ \(trafficService.aircraft.count - 10) more aircraft")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }

    private var categoryChipsView: some View {
        let categoryCounts = Dictionary(grouping: trafficService.aircraft) { aircraft in
            AircraftTypeDetector.detectCategory(
                callsign: aircraft.callsign,
                velocity: aircraft.velocity,
                altitude: aircraft.altitude,
                verticalRate: aircraft.verticalRate,
                onGround: aircraft.onGround,
                originCountry: aircraft.originCountry
            )
        }.mapValues { $0.count }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categoryCounts.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(category.baseColor)
                            .frame(width: 8, height: 8)
                        Text("\(count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text(category.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.18))
                    .cornerRadius(16)
                }
            }
        }
        .frame(height: 32)
    }

    // MARK: - Actions

    private func lookupZipCode() {
        guard !zipCodeInput.isEmpty else { return }
        isLookingUpZip = true
        zipLookupError = nil

        trafficService.lookupZipCode(zipCodeInput) { coordinate in
            isLookingUpZip = false
            if let coord = coordinate {
                var settings = trafficService.settings
                settings.customLatitude = coord.latitude
                settings.customLongitude = coord.longitude
                trafficService.settings = settings
                trafficService.fetchAircraft()
            } else {
                zipLookupError = "Could not find location for ZIP code"
            }
        }
    }
}

// MARK: - Provider Row

struct ProviderRow: View {
    let provider: ADSBProvider
    let isActive: Bool
    let config: ADSBProviderConfig?
    let onSelect: () -> Void
    let onConfigure: () -> Void

    private var isConfigured: Bool {
        config?.isConfigured ?? provider.hasFreeTier
    }

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Button(action: {
                if isConfigured {
                    onSelect()
                }
            }) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isActive ? provider.color : (isConfigured ? .gray : .gray.opacity(0.4)))
            }
            .disabled(!isConfigured)

            // Provider icon
            Image(systemName: provider.icon)
                .font(.system(size: 18))
                .foregroundColor(isConfigured ? provider.color : .gray.opacity(0.5))
                .frame(width: 24)

            // Provider info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(provider.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isConfigured ? .white : .gray)

                    if provider.hasFreeTier {
                        Text("FREE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    } else if provider.requiresAPIKey && !(config?.hasCredentials ?? false) {
                        Text("API KEY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(provider.description)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Configure button
            Button(action: onConfigure) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if isConfigured {
                onSelect()
            } else {
                onConfigure()
            }
        }
    }
}

// MARK: - Provider Config Sheet

struct ProviderConfigSheet: View {
    let provider: ADSBProvider
    @ObservedObject var trafficService: ADSBTrafficService
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var customURL = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Provider header
                        HStack(spacing: 16) {
                            Image(systemName: provider.icon)
                                .font(.system(size: 40))
                                .foregroundColor(provider.color)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(provider.displayName)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text(provider.description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }

                        Divider().background(Color.gray.opacity(0.3))

                        // Provider-specific configuration
                        switch provider {
                        case .openSky:
                            openSkyConfig
                        case .adsbExchange:
                            adsbExchangeConfig
                        case .adsbLol:
                            adsbLolConfig
                        case .flightRadar24:
                            flightRadar24Config
                        case .flightAware:
                            flightAwareConfig
                        case .custom:
                            customSourceConfig
                        }

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Configure \(provider.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveConfig()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
            .onAppear {
                loadCurrentConfig()
            }
        }
    }

    // MARK: - Provider Configs

    private var openSkyConfig: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoBox(
                title: "Free Tier Available",
                message: "OpenSky works without credentials but is rate-limited (~100 requests/day). Add credentials for enhanced access (~4,000 requests/day).",
                color: .green
            )

            Text("API CREDENTIALS (OPTIONAL)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            TextField("Username", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            SecureField("Password", text: $apiSecret)
                .textFieldStyle(.roundedBorder)

            signupButton(url: provider.signupURL)
        }
    }

    private var adsbExchangeConfig: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoBox(
                title: "RapidAPI Key Required",
                message: "ADS-B Exchange provides unfiltered, real-time data including military aircraft. Requires a RapidAPI subscription.",
                color: .orange
            )

            Text("RAPIDAPI KEY")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            SecureField("RapidAPI Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            signupButton(url: provider.signupURL)
        }
    }

    private var adsbLolConfig: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoBox(
                title: "Free Community Service",
                message: "ADSB.lol is a free community-driven ADS-B aggregator. No API key required!",
                color: .green
            )

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Ready to use - no configuration needed")
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var flightRadar24Config: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoBox(
                title: "API Key Required",
                message: "FlightRadar24 requires a paid API subscription for data access.",
                color: .orange
            )

            Text("API KEY")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            SecureField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            signupButton(url: provider.signupURL)
        }
    }

    private var flightAwareConfig: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoBox(
                title: "AeroAPI Key Required",
                message: "FlightAware's AeroAPI provides professional aviation data. Requires a subscription.",
                color: .orange
            )

            Text("API KEY")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            SecureField("AeroAPI Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            signupButton(url: provider.signupURL)
        }
    }

    private var customSourceConfig: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoBox(
                title: "Custom Data Source",
                message: "Connect to a local ADS-B receiver (dump1090, tar1090, readsb) or any compatible API endpoint.",
                color: .purple
            )

            Text("API ENDPOINT")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            TextField("https://your-receiver/data/aircraft.json", text: $customURL)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)

            Text("Supported placeholders: {lat}, {lon}, {radius}, {radius_km}")
                .font(.system(size: 11))
                .foregroundColor(.gray)

            Text("API KEY (OPTIONAL)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            SecureField("Bearer Token", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("Example URLs:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)

                Text("• http://192.168.1.100/data/aircraft.json")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)

                Text("• http://localhost:8080/aircraft")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(white: 0.15))
            .cornerRadius(8)
        }
    }

    // MARK: - Helper Views

    private func infoBox(title: String, message: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: color == .green ? "checkmark.circle.fill" : "info.circle.fill")
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func signupButton(url: String?) -> some View {
        if let urlString = url, let url = URL(string: urlString) {
            Button(action: {
                openURL(url)
            }) {
                HStack {
                    Image(systemName: "safari")
                    Text("Get API Credentials")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#FFFC00"))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#FFFC00").opacity(0.15))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Actions

    private func loadCurrentConfig() {
        if let config = trafficService.settings.providers.first(where: { $0.provider == provider }) {
            apiKey = config.apiKey
            apiSecret = config.apiSecret
            customURL = config.customURL
        }
    }

    private func saveConfig() {
        var settings = trafficService.settings
        var config = settings.providers.first(where: { $0.provider == provider }) ?? ADSBProviderConfig(provider: provider)

        config.apiKey = apiKey
        config.apiSecret = apiSecret
        config.customURL = customURL
        config.isEnabled = config.isConfigured

        settings.updateProvider(config)

        // Also set this provider as the active provider when saving
        if config.isConfigured {
            settings.activeProvider = provider
            print("Set active provider to: \(provider.displayName)")
            print("API Key saved (first 20 chars): \(String(apiKey.prefix(20)))...")
        }

        trafficService.settings = settings
    }
}

// MARK: - Aircraft Row

struct AircraftRow: View {
    let aircraft: Aircraft

    private var category: AircraftCategory {
        AircraftTypeDetector.detectCategory(
            callsign: aircraft.callsign,
            velocity: aircraft.velocity,
            altitude: aircraft.altitude,
            verticalRate: aircraft.verticalRate,
            onGround: aircraft.onGround,
            originCountry: aircraft.originCountry
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            // Aircraft icon with type-aware styling
            AircraftListIcon(aircraft: aircraft, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(aircraft.callsign.isEmpty ? aircraft.id.uppercased() : aircraft.callsign)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Text(category.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(category.baseColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(category.baseColor.opacity(0.2))
                        .cornerRadius(4)

                    Text(aircraft.originCountry)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text(aircraft.formattedAltitude)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text(aircraft.climbDescendIndicator)
                        .foregroundColor(aircraft.verticalRate > 1 ? .green : (aircraft.verticalRate < -1 ? .orange : .gray))
                }

                Text(aircraft.formattedSpeed)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct ADSBTrafficView_Previews: PreviewProvider {
    static var previews: some View {
        ADSBTrafficView()
            .preferredColorScheme(.dark)
    }
}
#endif
