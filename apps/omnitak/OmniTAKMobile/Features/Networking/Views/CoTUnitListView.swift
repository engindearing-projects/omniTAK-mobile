//
//  CoTUnitListView.swift
//  OmniTAKTest
//
//  ATAK-style unit list view with sections, tap selection, and detail sheet
//

import SwiftUI
import MapKit

// MARK: - CoT Unit List View

struct CoTUnitListView: View {
    @ObservedObject var filterManager: CoTFilterManager
    @ObservedObject var criteria: CoTFilterCriteria
    @Binding var isExpanded: Bool
    @Binding var selectedEvent: EnrichedCoTEvent?
    @Binding var mapRegion: MKCoordinateRegion

    @State private var showingDetail = false

    private var filteredEvents: [EnrichedCoTEvent] {
        filterManager.applyFilters(criteria: criteria)
    }

    private var groupedEvents: [(CoTAffiliation, [EnrichedCoTEvent])] {
        let grouped = Dictionary(grouping: filteredEvents, by: { $0.affiliation })
        return grouped.sorted { $0.key.displayName < $1.key.displayName }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            listHeader

            // Unit List
            if filteredEvents.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedEvents, id: \.0.rawValue) { affiliation, events in
                            sectionHeader(for: affiliation, count: events.count)

                            ForEach(events) { event in
                                UnitRow(event: event, onTap: {
                                    selectEvent(event)
                                })
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 360)
        .background(Color.black.opacity(0.95))
        .cornerRadius(12)
        .sheet(isPresented: $showingDetail) {
            if let event = selectedEvent {
                UnitDetailSheet(event: event, onClose: {
                    showingDetail = false
                })
            }
        }
    }

    // MARK: - Header

    private var listHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)

                Text("UNIT LIST")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)

                Text("(\(filteredEvents.count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)

                Spacer()

                Button(action: {
                    withAnimation(.spring()) {
                        isExpanded = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
        }
    }

    // MARK: - Section Header

    private func sectionHeader(for affiliation: CoTAffiliation, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: affiliation.icon)
                .font(.system(size: 12))
                .foregroundColor(affiliation.color)

            Text(affiliation.displayName.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(affiliation.color)

            Text("(\(count))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(affiliation.color.opacity(0.15))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Units Found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)

            Text("Adjust filters or check connection")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func selectEvent(_ event: EnrichedCoTEvent) {
        selectedEvent = event
        showingDetail = true

        // Center map on selected unit
        withAnimation {
            mapRegion.center = event.coordinate
            mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Unit Row

struct UnitRow: View {
    let event: EnrichedCoTEvent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                VStack(spacing: 4) {
                    Image(systemName: event.affiliation.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(event.affiliation.color)

                    Text(event.category.displayName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .frame(width: 50)

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    // Callsign
                    Text(event.callsign)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Team
                    if let team = event.team {
                        Text(team)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    // Distance & Bearing
                    HStack(spacing: 12) {
                        if event.distance != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                Text(event.formattedDistance)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.cyan)
                        }

                        if event.bearing != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "compass.drawing")
                                    .font(.system(size: 9))
                                Text("\(event.formattedBearing) \(event.cardinalDirection)")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                // Age & Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(event.formattedAge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(event.isStale ? .orange : .gray)

                    if event.isStale {
                        Text("STALE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Unit Detail Sheet

struct UnitDetailSheet: View {
    let event: EnrichedCoTEvent
    let onClose: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    headerCard

                    // Location Card
                    locationCard

                    // Movement Card
                    if event.speed != nil || event.course != nil {
                        movementCard
                    }

                    // Details Card
                    detailsCard

                    // Technical Info Card
                    technicalInfoCard
                }
                .padding()
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Unit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onClose()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: event.affiliation.icon)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(event.affiliation.color)

            // Callsign
            Text(event.callsign)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            // Team & Affiliation
            HStack(spacing: 12) {
                if let team = event.team {
                    Text(team)
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(6)
                }

                Text(event.affiliation.displayName)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(event.affiliation.color.opacity(0.3))
                    .cornerRadius(6)

                Text(event.category.displayName)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(6)
            }
            .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOCATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)

            UnitDetailRow(label: "Latitude", value: String(format: "%.6f°", event.coordinate.latitude))
            UnitDetailRow(label: "Longitude", value: String(format: "%.6f°", event.coordinate.longitude))
            UnitDetailRow(label: "Altitude", value: String(format: "%.0f m / %.0f ft", event.altitude, event.altitudeFeet))

            if event.distance != nil {
                UnitDetailRow(label: "Distance", value: event.formattedDistance)
            }

            if event.bearing != nil {
                UnitDetailRow(label: "Bearing", value: "\(event.formattedBearing) (\(event.cardinalDirection))")
            }

            UnitDetailRow(label: "CE", value: String(format: "%.1f m", event.ce))
            UnitDetailRow(label: "LE", value: String(format: "%.1f m", event.le))
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

    private var movementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MOVEMENT")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)

            if let speed = event.speed {
                UnitDetailRow(label: "Speed", value: String(format: "%.1f m/s (%.1f km/h)", speed, speed * 3.6))
            }

            if let course = event.course {
                UnitDetailRow(label: "Course", value: String(format: "%.0f°", course))
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DETAILS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)

            UnitDetailRow(label: "Age", value: event.formattedAge)
            UnitDetailRow(label: "Status", value: event.isStale ? "STALE" : "Current", valueColor: event.isStale ? .orange : .green)
            UnitDetailRow(label: "Timestamp", value: event.timestamp.formatted())

            if let remarks = event.remarks {
                UnitDetailRow(label: "Remarks", value: remarks)
            }

            if let battery = event.battery {
                UnitDetailRow(label: "Battery", value: "\(battery)%")
            }

            if let device = event.device {
                UnitDetailRow(label: "Device", value: device)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

    private var technicalInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TECHNICAL INFO")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)

            UnitDetailRow(label: "UID", value: event.uid, monospace: true)
            UnitDetailRow(label: "Type", value: event.type, monospace: true)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Detail Row

struct UnitDetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white
    var monospace: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(monospace ? .system(size: 13, design: .monospaced) : .system(size: 13, weight: .medium))
                .foregroundColor(valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
