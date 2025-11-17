//
//  CoTFilterPanel.swift
//  OmniTAKTest
//
//  ATAK-style filter UI panel with search, quick filters, and advanced options
//

import SwiftUI

// MARK: - CoT Filter Panel

struct CoTFilterPanel: View {
    @ObservedObject var criteria: CoTFilterCriteria
    @ObservedObject var filterManager: CoTFilterManager
    @Binding var isExpanded: Bool

    @State private var showAdvancedFilters = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            filterHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Search Bar
                    searchBar

                    // Quick Filters
                    quickFiltersSection

                    // Active Filters Count
                    if criteria.isFiltering {
                        activeFiltersIndicator
                    }

                    // Affiliation Filters
                    affiliationFiltersSection

                    // Category Filters
                    categoryFiltersSection

                    // Advanced Filters Toggle
                    advancedFiltersToggle

                    // Advanced Filters (Expandable)
                    if showAdvancedFilters {
                        advancedFiltersSection
                    }

                    // Sort Options
                    sortOptionsSection

                    // Statistics
                    statisticsSection

                    // Reset Button
                    resetButton
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 320)
        .background(Color.black.opacity(0.95))
        .cornerRadius(12)
    }

    // MARK: - Header

    private var filterHeader: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.cyan)

            Text("FILTER UNITS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)

            if criteria.isFiltering {
                Text("(\(criteria.activeFilterCount))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
            }

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

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))

            TextField("Search callsign or UID...", text: $criteria.searchText)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !criteria.searchText.isEmpty {
                Button(action: { criteria.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Quick Filters

    private var quickFiltersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK FILTERS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.7))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(QuickFilterPreset.allCases) { preset in
                    QuickFilterButton(preset: preset, criteria: criteria)
                }
            }
        }
    }

    // MARK: - Active Filters Indicator

    private var activeFiltersIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)

            Text("\(criteria.activeFilterCount) filter(s) active")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.orange)

            Spacer()
        }
        .padding(8)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(6)
    }

    // MARK: - Affiliation Filters

    private var affiliationFiltersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AFFILIATION")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.7))

            VStack(spacing: 6) {
                ForEach(CoTAffiliation.allCases) { affiliation in
                    AffiliationToggle(
                        affiliation: affiliation,
                        isSelected: criteria.selectedAffiliations.contains(affiliation),
                        onToggle: {
                            toggleAffiliation(affiliation)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Category Filters

    private var categoryFiltersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.7))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 6) {
                ForEach(CoTCategory.allCases) { category in
                    CategoryToggle(
                        category: category,
                        isSelected: criteria.selectedCategories.contains(category),
                        onToggle: {
                            toggleCategory(category)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Advanced Filters Toggle

    private var advancedFiltersToggle: some View {
        Button(action: {
            withAnimation {
                showAdvancedFilters.toggle()
            }
        }) {
            HStack {
                Image(systemName: showAdvancedFilters ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                Text("ADVANCED FILTERS")
                    .font(.system(size: 10, weight: .bold))
                Spacer()
            }
            .foregroundColor(.cyan)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Advanced Filters

    private var advancedFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Distance Filter
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $criteria.distanceEnabled) {
                    HStack {
                        Image(systemName: "location.circle")
                            .font(.system(size: 12))
                        Text("Distance Range")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .cyan))

                if criteria.distanceEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Max:")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(formatDistance(criteria.maxDistance))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cyan)
                        }

                        Slider(value: $criteria.maxDistance, in: 100...50000, step: 100)
                            .accentColor(.cyan)
                    }
                    .padding(.leading, 20)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)

            // Age Filter
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $criteria.ageEnabled) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("Age Range")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .cyan))

                if criteria.ageEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Max:")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(formatAge(criteria.maxAge))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cyan)
                        }

                        Slider(value: $criteria.maxAge, in: 60...7200, step: 60)
                            .accentColor(.cyan)
                    }
                    .padding(.leading, 20)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)

            // Stale Units Toggle
            Toggle(isOn: $criteria.showStaleUnits) {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 12))
                    Text("Show Stale Units (>15m)")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .cyan))
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }

    // MARK: - Sort Options

    private var sortOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SORT BY")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 8) {
                Picker("Sort", selection: $criteria.sortBy) {
                    ForEach(CoTSortOption.allCases) { option in
                        HStack {
                            Image(systemName: option.icon)
                            Text(option.displayName)
                        }
                        .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)

                Button(action: {
                    criteria.sortAscending.toggle()
                }) {
                    Image(systemName: criteria.sortAscending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        let stats = filterManager.getStatistics(for: filterManager.allEvents)

        return VStack(alignment: .leading, spacing: 8) {
            Text("STATISTICS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.7))

            VStack(spacing: 6) {
                StatRow(label: "Total Units", value: "\(stats.totalCount)")
                StatRow(label: "Avg Distance", value: stats.formattedAverageDistance)
                StatRow(label: "Avg Age", value: stats.formattedAverageAge)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button(action: {
            withAnimation {
                criteria.resetFilters()
            }
        }) {
            HStack {
                Spacer()
                Image(systemName: "arrow.counterclockwise")
                Text("Reset All Filters")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.6))
            .cornerRadius(8)
        }
        .padding(.top, 8)
    }

    // MARK: - Helper Methods

    private func toggleAffiliation(_ affiliation: CoTAffiliation) {
        if criteria.selectedAffiliations.contains(affiliation) {
            criteria.selectedAffiliations.remove(affiliation)
        } else {
            criteria.selectedAffiliations.insert(affiliation)
        }
    }

    private func toggleCategory(_ category: CoTCategory) {
        if criteria.selectedCategories.contains(category) {
            criteria.selectedCategories.remove(category)
        } else {
            criteria.selectedCategories.insert(category)
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", meters / 1000.0)
        }
    }

    private func formatAge(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else if seconds < 3600 {
            return String(format: "%.0fm", seconds / 60)
        } else {
            return String(format: "%.1fh", seconds / 3600)
        }
    }
}

// MARK: - Quick Filter Button

struct QuickFilterButton: View {
    let preset: QuickFilterPreset
    @ObservedObject var criteria: CoTFilterCriteria

    var body: some View {
        Button(action: {
            withAnimation {
                criteria.applyQuickFilter(preset)
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: preset.icon)
                    .font(.system(size: 16))
                Text(preset.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(preset.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Affiliation Toggle

struct AffiliationToggle: View {
    let affiliation: CoTAffiliation
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: affiliation.icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundColor(affiliation.color)

                Text(affiliation.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .green : .gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? affiliation.color.opacity(0.2) : Color.white.opacity(0.05))
            .cornerRadius(6)
        }
    }
}

// MARK: - Category Toggle

struct CategoryToggle: View {
    let category: CoTCategory
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .cyan : .gray)

                Text(category.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.cyan)
        }
    }
}
