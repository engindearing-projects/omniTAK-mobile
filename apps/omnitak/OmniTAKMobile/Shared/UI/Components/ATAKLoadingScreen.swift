import SwiftUI

// MARK: - OmniTAK Loading Screen
// Professional loading screen matching OmniTAK interface

struct ATAKLoadingScreen: View {
    @Binding var isLoading: Bool
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage = "Please wait..."
    @State private var animationAmount: CGFloat = 1

    let loadingStages = [
        (0.2, "Initializing TAK Client..."),
        (0.4, "Loading Map Tiles..."),
        (0.6, "Connecting to Server..."),
        (0.8, "Synchronizing CoT..."),
        (1.0, "Ready")
    ]

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // OmniTAK Loading Title
                Text("OmniTAK Loading")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(hex: "#FFFC00"))

                // Loading Spinner
                ZStack {
                    Circle()
                        .stroke(Color(hex: "#FFFC00").opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color(hex: "#FFFC00"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: animationAmount))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: animationAmount)
                }
                .onAppear {
                    animationAmount = 360
                }

                // Progress Bar
                VStack(spacing: 12) {
                    ProgressView(value: loadingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#FFFC00")))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                        .frame(width: 280)

                    Text(loadingMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // App Info Footer
                VStack(spacing: 8) {
                    Text("OmniTAK Mobile")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    Text("Version 1.3.8 - Built with Valdi")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            simulateLoading()
        }
    }

    private func simulateLoading() {
        var currentStage = 0

        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { timer in
            guard currentStage < loadingStages.count else {
                timer.invalidate()
                // Delay before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoading = false
                }
                return
            }

            withAnimation(.easeInOut(duration: 0.4)) {
                loadingProgress = loadingStages[currentStage].0
                loadingMessage = loadingStages[currentStage].1
            }

            currentStage += 1
        }
    }
}

// MARK: - GPS Status Indicator

struct GPSStatusIndicator: View {
    let accuracy: Double? // in meters
    let isAvailable: Bool
    let showError: Bool

    var statusColor: Color {
        guard isAvailable else { return .red }
        guard let acc = accuracy else { return .gray }

        if acc < 10 {
            return .green
        } else if acc < 30 {
            return .yellow
        } else {
            return .orange
        }
    }

    var statusText: String {
        guard isAvailable else { return "NO GPS" }
        guard let acc = accuracy else { return "Searching..." }

        if acc < 10 {
            return "GPS Excellent"
        } else if acc < 30 {
            return "GPS Good"
        } else {
            return "GPS Fair"
        }
    }

    var body: some View {
        // Compact GPS Icon - just the icon with color indicator
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 36, height: 36)

            Circle()
                .fill(statusColor.opacity(0.3))
                .frame(width: 36, height: 36)

            Image(systemName: isAvailable ? "location.fill" : "location.slash.fill")
                .font(.system(size: 14))
                .foregroundColor(statusColor)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - GPS Error Alert

struct GPSErrorAlert: View {
    @Binding var isPresented: Bool
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Alert Dialog
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                }

                // Title and Message
                VStack(spacing: 12) {
                    Text("NO GPS")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("Please tap here to set your location manually")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: onSettings) {
                        Text("Open Settings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#FFFC00"))
                            .cornerRadius(12)
                    }

                    Button(action: { isPresented = false }) {
                        Text("Set Location Manually")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(white: 0.2))
                            .cornerRadius(12)
                    }

                    Button(action: { isPresented = false }) {
                        Text("Dismiss")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
            }
            .frame(width: 320)
            .padding(32)
            .background(Color(white: 0.15))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Geofence Alert Notification

struct GeofenceAlertNotification: View {
    let geofenceName: String
    let action: String // "Entered" or "Exited"
    let callsign: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "map.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Geo Fence \(action)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)

                    Text("Drawing Circle 1, (You) \(callsign)")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .background(Color.black.opacity(0.9))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - Callsign Display with Coordinates

struct CallsignDisplay: View {
    let callsign: String
    let coordinates: String // e.g., "11T MN 65089 83168"
    let altitude: String // e.g., "1,898 ft MSL"
    let speed: String // e.g., "0 MPH"
    let accuracy: String // e.g., "+/- 5m"

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Callsign: \(callsign)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#00FFFF"))

            Text(coordinates)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#00FFFF"))

            Text(altitude)
                .font(.system(size: 11))
                .foregroundColor(.white)

            Text("\(speed)     \(accuracy)")
                .font(.system(size: 11))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct ATAKLoadingScreen_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ATAKLoadingScreen(isLoading: .constant(true))

            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    GPSStatusIndicator(accuracy: 5.2, isAvailable: true, showError: false)
                    GPSStatusIndicator(accuracy: 25.0, isAvailable: true, showError: false)
                    GPSStatusIndicator(accuracy: nil, isAvailable: false, showError: true)
                }
            }

            ZStack {
                Color.gray.ignoresSafeArea()
                VStack {
                    GeofenceAlertNotification(
                        geofenceName: "Circle 1",
                        action: "Entered",
                        callsign: "MURK",
                        isPresented: .constant(true)
                    )
                    Spacer()
                }
                .padding(.top, 60)
            }

            ZStack {
                Color.gray.ignoresSafeArea()
                VStack {
                    Spacer()
                    CallsignDisplay(
                        callsign: "MURK",
                        coordinates: "11T MN 65089 83168",
                        altitude: "1,898 ft MSL",
                        speed: "0 MPH",
                        accuracy: "+/- 5m"
                    )
                }
                .padding()
            }
        }
    }
}
