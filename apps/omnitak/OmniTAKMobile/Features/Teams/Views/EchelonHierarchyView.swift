//
//  EchelonHierarchyView.swift
//  OmniTAKMobile
//
//  SwiftUI view for displaying and managing military unit hierarchy
//

import SwiftUI

// MARK: - Main Hierarchy View

struct EchelonHierarchyView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var echelonService = EchelonService()

    @State private var expandedUnits: Set<UUID> = []
    @State private var selectedUnitId: UUID?
    @State private var showingAddUnit = false
    @State private var showingEditUnit = false
    @State private var showingImportExport = false
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""
    @State private var filterEchelon: EchelonLevel?
    @State private var filterStatus: UnitStatus?

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search and filter bar
                    searchFilterBar

                    if echelonService.units.isEmpty {
                        emptyStateView
                    } else {
                        hierarchyListView
                    }

                    // Summary footer
                    summaryFooter
                }
            }
            .navigationTitle("Unit Hierarchy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddUnit = true }) {
                            Label("Add Unit", systemImage: "plus.circle")
                        }

                        Button(action: { expandAll() }) {
                            Label("Expand All", systemImage: "arrow.up.left.and.arrow.down.right")
                        }

                        Button(action: { collapseAll() }) {
                            Label("Collapse All", systemImage: "arrow.down.right.and.arrow.up.left")
                        }

                        Divider()

                        Button(action: { showingImportExport = true }) {
                            Label("Import/Export", systemImage: "square.and.arrow.up.on.square")
                        }

                        if echelonService.units.isEmpty {
                            Button(action: { echelonService.createSampleHierarchy() }) {
                                Label("Load Sample Data", systemImage: "doc.badge.plus")
                            }
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Color(hex: "#FFFC00"))
                    }
                }
            }
            .sheet(isPresented: $showingAddUnit) {
                AddEditUnitView(
                    echelonService: echelonService,
                    parentId: selectedUnitId,
                    editingUnit: nil
                )
            }
            .sheet(isPresented: $showingEditUnit) {
                if let unitId = selectedUnitId, let unit = echelonService.getUnit(unitId) {
                    AddEditUnitView(
                        echelonService: echelonService,
                        parentId: unit.parentId,
                        editingUnit: unit
                    )
                }
            }
            .sheet(isPresented: $showingImportExport) {
                ImportExportView(echelonService: echelonService)
            }
            .alert("Clear All Units?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    echelonService.clearAll()
                }
            } message: {
                Text("This will permanently delete all units in the hierarchy. This action cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Search and Filter Bar

    private var searchFilterBar: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search units...", text: $searchText)
                    .foregroundColor(.white)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All Echelons", isSelected: filterEchelon == nil) {
                        filterEchelon = nil
                    }

                    ForEach(EchelonLevel.allCases.reversed(), id: \.self) { echelon in
                        filterChip(
                            title: echelon.displayName,
                            isSelected: filterEchelon == echelon
                        ) {
                            filterEchelon = echelon
                        }
                    }

                    Divider()
                        .frame(height: 24)
                        .background(Color.gray)

                    filterChip(title: "All Status", isSelected: filterStatus == nil) {
                        filterStatus = nil
                    }

                    ForEach(UnitStatus.allCases, id: \.self) { status in
                        filterChip(
                            title: status.displayName,
                            isSelected: filterStatus == status
                        ) {
                            filterStatus = status
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#252525"))
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? Color(hex: "#1E1E1E") : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color(hex: "#FFFC00") : Color(hex: "#3A3A3A"))
                .cornerRadius(16)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#FFFC00"))

            Text("No Units Defined")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Add units to build your organizational hierarchy")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button(action: { showingAddUnit = true }) {
                Label("Add First Unit", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#1E1E1E"))
                    .padding()
                    .background(Color(hex: "#FFFC00"))
                    .cornerRadius(12)
            }

            Button(action: { echelonService.createSampleHierarchy() }) {
                Text("Load Sample Hierarchy")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#FFFC00"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Hierarchy List

    private var hierarchyListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredUnits, id: \.0.id) { unit, depth in
                    UnitRowView(
                        unit: unit,
                        depth: depth,
                        isExpanded: expandedUnits.contains(unit.id),
                        isSelected: selectedUnitId == unit.id,
                        totalStrength: echelonService.calculateTotalStrength(for: unit.id),
                        totalAuthorized: echelonService.calculateTotalAuthorizedStrength(for: unit.id),
                        onToggleExpand: {
                            toggleExpansion(unit.id)
                        },
                        onSelect: {
                            selectedUnitId = unit.id
                        },
                        onEdit: {
                            selectedUnitId = unit.id
                            showingEditUnit = true
                        },
                        onAddChild: {
                            selectedUnitId = unit.id
                            showingAddUnit = true
                        },
                        onDelete: {
                            echelonService.removeUnit(unit.id, cascade: false)
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var filteredUnits: [(MilitaryUnit, Int)] {
        var result = echelonService.flattenHierarchy(expandedIds: expandedUnits)

        // Apply echelon filter
        if let echelon = filterEchelon {
            result = result.filter { $0.0.echelon == echelon }
        }

        // Apply status filter
        if let status = filterStatus {
            result = result.filter { $0.0.status == status }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.0.shortName.localizedCaseInsensitiveContains(searchText) ||
                ($0.0.commander?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    // MARK: - Summary Footer

    private var summaryFooter: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.gray)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Units")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(echelonService.units.count)")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#FFFC00"))
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Total Strength")
                        .font(.caption)
                        .foregroundColor(.gray)
                    let totalStrength = echelonService.rootUnitIds.reduce(0) {
                        $0 + echelonService.calculateTotalStrength(for: $1)
                    }
                    Text("\(totalStrength)")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Effective")
                        .font(.caption)
                        .foregroundColor(.gray)
                    let effectiveStrength = echelonService.rootUnitIds.reduce(0) {
                        $0 + echelonService.calculateTotalEffectiveStrength(for: $1)
                    }
                    Text("\(effectiveStrength)")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(hex: "#252525"))
    }

    // MARK: - Helper Methods

    private func toggleExpansion(_ unitId: UUID) {
        if expandedUnits.contains(unitId) {
            expandedUnits.remove(unitId)
        } else {
            expandedUnits.insert(unitId)
        }
    }

    private func expandAll() {
        for unit in echelonService.units.values where unit.hasChildren {
            expandedUnits.insert(unit.id)
        }
    }

    private func collapseAll() {
        expandedUnits.removeAll()
    }
}

// MARK: - Unit Row View

struct UnitRowView: View {
    let unit: MilitaryUnit
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let totalStrength: Int
    let totalAuthorized: Int

    let onToggleExpand: () -> Void
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onAddChild: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Indentation
                HStack(spacing: 0) {
                    ForEach(0..<depth, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1)
                            .padding(.horizontal, 12)
                    }
                }

                // Expand/Collapse button
                if unit.hasChildren {
                    Button(action: onToggleExpand) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#FFFC00"))
                            .frame(width: 20)
                    }
                } else {
                    Spacer()
                        .frame(width: 20)
                }

                // NATO Symbol
                Text(unit.echelon.natoSymbol)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .frame(width: 44, alignment: .center)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(4)

                // Unit Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(unit.shortName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Image(systemName: unit.unitType.iconName)
                            .font(.system(size: 10))
                            .foregroundColor(unit.unitType.color)
                    }

                    Text(unit.name)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Status indicator
                Image(systemName: unit.status.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(unit.status.color)

                // Strength display
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(totalStrength)/\(totalAuthorized)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(strengthColor)

                    let percentage = totalAuthorized > 0 ?
                        Double(totalStrength) / Double(totalAuthorized) * 100 : 0
                    Text("\(Int(percentage))%")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .frame(width: 70, alignment: .trailing)

                // Context menu trigger
                Menu {
                    Button(action: onEdit) {
                        Label("Edit Unit", systemImage: "pencil")
                    }

                    Button(action: onAddChild) {
                        Label("Add Subordinate", systemImage: "plus.circle")
                    }

                    Divider()

                    Button(role: .destructive, action: onDelete) {
                        Label("Remove Unit", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color(hex: "#2A2A2A") : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }

            Divider()
                .background(Color(hex: "#3A3A3A"))
        }
    }

    private var strengthColor: Color {
        let percentage = totalAuthorized > 0 ?
            Double(totalStrength) / Double(totalAuthorized) * 100 : 0
        if percentage >= 90 {
            return .green
        } else if percentage >= 70 {
            return .yellow
        } else if percentage >= 50 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Add/Edit Unit View

struct AddEditUnitView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var echelonService: EchelonService

    let parentId: UUID?
    let editingUnit: MilitaryUnit?

    @State private var name: String = ""
    @State private var shortName: String = ""
    @State private var echelon: EchelonLevel = .company
    @State private var unitType: MilitaryUnitType = .infantry
    @State private var branch: BranchOfService = .army
    @State private var status: UnitStatus = .operational
    @State private var authorizedStrength: String = ""
    @State private var currentStrength: String = ""
    @State private var commander: String = ""
    @State private var location: String = ""
    @State private var remarks: String = ""

    var isEditing: Bool {
        editingUnit != nil
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                Form {
                    Section(header: sectionHeader("Unit Identity")) {
                        TextField("Unit Name", text: $name)
                            .textFieldStyle(CustomTextFieldStyle())

                        TextField("Short Name (e.g., A Co)", text: $shortName)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))

                    Section(header: sectionHeader("Classification")) {
                        Picker("Echelon", selection: $echelon) {
                            ForEach(EchelonLevel.allCases, id: \.self) { level in
                                HStack {
                                    Text(level.natoSymbol)
                                        .font(.system(.body, design: .monospaced))
                                    Text(level.displayName)
                                }
                                .tag(level)
                            }
                        }
                        .onChange(of: echelon) { newValue in
                            if authorizedStrength.isEmpty {
                                authorizedStrength = "\(newValue.standardStrength)"
                                currentStrength = "\(newValue.standardStrength)"
                            }
                        }

                        Picker("Unit Type", selection: $unitType) {
                            ForEach(MilitaryUnitType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.iconName)
                                    .tag(type)
                            }
                        }

                        Picker("Branch", selection: $branch) {
                            ForEach(BranchOfService.allCases, id: \.self) { branchOption in
                                Label(branchOption.displayName, systemImage: branchOption.iconName)
                                    .tag(branchOption)
                            }
                        }

                        Picker("Status", selection: $status) {
                            ForEach(UnitStatus.allCases, id: \.self) { statusOption in
                                HStack {
                                    Image(systemName: statusOption.iconName)
                                        .foregroundColor(statusOption.color)
                                    Text(statusOption.displayName)
                                }
                                .tag(statusOption)
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))

                    Section(header: sectionHeader("Strength")) {
                        HStack {
                            Text("Authorized")
                                .foregroundColor(.gray)
                            Spacer()
                            TextField("0", text: $authorizedStrength)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }

                        HStack {
                            Text("Current")
                                .foregroundColor(.gray)
                            Spacer()
                            TextField("0", text: $currentStrength)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))

                    Section(header: sectionHeader("Details")) {
                        TextField("Commander", text: $commander)
                            .textFieldStyle(CustomTextFieldStyle())

                        TextField("Location", text: $location)
                            .textFieldStyle(CustomTextFieldStyle())

                        TextField("Remarks", text: $remarks)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))
                }

            }
            .navigationTitle(isEditing ? "Edit Unit" : "Add Unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        saveUnit()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let unit = editingUnit {
                    loadUnit(unit)
                } else {
                    authorizedStrength = "\(echelon.standardStrength)"
                    currentStrength = "\(echelon.standardStrength)"
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundColor(Color(hex: "#FFFC00"))
            .textCase(.uppercase)
    }

    private func loadUnit(_ unit: MilitaryUnit) {
        name = unit.name
        shortName = unit.shortName
        echelon = unit.echelon
        unitType = unit.unitType
        branch = unit.branch
        status = unit.status
        authorizedStrength = "\(unit.authorizedStrength)"
        currentStrength = "\(unit.currentStrength)"
        commander = unit.commander ?? ""
        location = unit.location ?? ""
        remarks = unit.remarks ?? ""
    }

    private func saveUnit() {
        let authStr = Int(authorizedStrength) ?? echelon.standardStrength
        let currStr = Int(currentStrength) ?? authStr

        if var unit = editingUnit {
            // Update existing unit
            unit.name = name
            unit.shortName = shortName.isEmpty ? String(name.prefix(10)) : shortName
            unit.echelon = echelon
            unit.unitType = unitType
            unit.branch = branch
            unit.status = status
            unit.authorizedStrength = authStr
            unit.currentStrength = currStr
            unit.commander = commander.isEmpty ? nil : commander
            unit.location = location.isEmpty ? nil : location
            unit.remarks = remarks.isEmpty ? nil : remarks
            echelonService.updateUnit(unit)
        } else {
            // Create new unit
            echelonService.createUnit(
                name: name,
                shortName: shortName,
                echelon: echelon,
                unitType: unitType,
                branch: branch,
                parentId: parentId,
                commander: commander.isEmpty ? nil : commander,
                location: location.isEmpty ? nil : location
            )
        }
    }
}

// MARK: - Import/Export View

struct ImportExportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var echelonService: EchelonService

    @State private var jsonText: String = ""
    @State private var showingCopiedAlert = false
    @State private var showingImportError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Import/Export Hierarchy")
                        .font(.headline)
                        .foregroundColor(.white)

                    TextEditor(text: $jsonText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(8)
                        .frame(minHeight: 300)

                    HStack(spacing: 16) {
                        Button(action: exportHierarchy) {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ATAKButtonStyle())

                        Button(action: importHierarchy) {
                            Label("Import", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ATAKButtonStyle())
                        .disabled(jsonText.isEmpty)
                    }

                    Button(action: copyToClipboard) {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ATAKSecondaryButtonStyle())
                    .disabled(jsonText.isEmpty)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
            .alert("Copied", isPresented: $showingCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Hierarchy JSON copied to clipboard")
            }
            .alert("Import Error", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func exportHierarchy() {
        if let json = echelonService.exportToJSON() {
            jsonText = json
        }
    }

    private func importHierarchy() {
        if echelonService.importFromJSON(jsonText) {
            dismiss()
        } else {
            errorMessage = echelonService.lastError ?? "Unknown error"
            showingImportError = true
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = jsonText
        showingCopiedAlert = true
    }
}

// MARK: - Custom Styles

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.white)
    }
}

struct ATAKButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(hex: "#1E1E1E"))
            .padding(.vertical, 12)
            .background(Color(hex: "#FFFC00"))
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct ATAKSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(hex: "#FFFC00"))
            .padding(.vertical, 12)
            .background(Color(hex: "#2A2A2A"))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#FFFC00"), lineWidth: 1)
            )
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    EchelonHierarchyView()
}
