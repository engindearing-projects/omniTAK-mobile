//
//  TeamManagementView.swift
//  OmniTAKMobile
//
//  Team management UI for viewing and managing teams
//

import SwiftUI

// MARK: - Team List View

struct TeamListView: View {
    @ObservedObject var teamService = TeamService.shared
    @State private var showCreateTeam = false
    @State private var showJoinTeam = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Current Team Card
                    if let currentTeam = teamService.currentTeam {
                        currentTeamCard(currentTeam)
                            .padding()
                    } else {
                        noTeamCard
                            .padding()
                    }

                    // Team Members List
                    if let team = teamService.currentTeam {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TEAM MEMBERS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#888888"))
                                .padding(.horizontal)

                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(team.members) { member in
                                        TeamMemberRow(member: member)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer()

                    // Action Buttons
                    VStack(spacing: 12) {
                        if teamService.currentTeam != nil {
                            Button(action: {
                                teamService.leaveTeam()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Leave Team")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(10)
                            }
                        } else {
                            Button(action: { showCreateTeam = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create Team")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#FFFC00"))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#FFFC00").opacity(0.2))
                                .cornerRadius(10)
                            }

                            Button(action: { showJoinTeam = true }) {
                                HStack {
                                    Image(systemName: "person.badge.plus.fill")
                                    Text("Join Team")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan.opacity(0.2))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Teams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .sheet(isPresented: $showCreateTeam) {
            TeamCreatorView()
        }
        .sheet(isPresented: $showJoinTeam) {
            TeamJoinView()
        }
    }

    private func currentTeamCard(_ team: Team) -> some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(team.color.swiftUIColor)
                    .frame(width: 20, height: 20)

                Text(team.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(team.members.count) members")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Role")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    Text(teamService.currentRole?.displayName ?? "Member")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Team Color")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    Text(team.color.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(team.color.swiftUIColor)
                }
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(team.color.swiftUIColor, lineWidth: 2)
        )
    }

    private var noTeamCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("Not in a Team")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text("Create or join a team to coordinate with other operators")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }
}

// MARK: - Team Member Row

struct TeamMemberRow: View {
    let member: TeamMember

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(member.isOnline ? Color.green : Color.gray)
                .frame(width: 10, height: 10)

            // Callsign
            Text(member.callsign)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            // Role badge
            Text(member.role.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(member.role == .lead ? Color(hex: "#FFFC00") : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(member.role == .lead ? Color(hex: "#FFFC00").opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(4)

            // Last seen
            Text(formatLastSeen(member.lastSeen))
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(hex: "#333333"))
        .cornerRadius(8)
    }

    private func formatLastSeen(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
}

// MARK: - Team Creator View

struct TeamCreatorView: View {
    @ObservedObject var teamService = TeamService.shared
    @State private var teamName = ""
    @State private var selectedColor: TeamColor = .cyan
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Team Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TEAM NAME")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)

                        TextField("Enter team name", text: $teamName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color(hex: "#333333"))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }

                    // Color Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TEAM COLOR")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(TeamColor.allCases, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(color.swiftUIColor)
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 3)
                                            )

                                        Text(color.displayName)
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }

                    Spacer()

                    // Create Button
                    Button(action: createTeam) {
                        Text("Create Team")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(teamName.isEmpty ? Color.gray : Color(hex: "#FFFC00"))
                            .cornerRadius(10)
                    }
                    .disabled(teamName.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Create Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }

    private func createTeam() {
        let _ = teamService.createTeam(name: teamName, color: selectedColor)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Team Join View

struct TeamJoinView: View {
    @ObservedObject var teamService = TeamService.shared
    @State private var teamCode = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#FFFC00"))

                    Text("Join a Team")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("Enter the team code or scan QR code to join")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    TextField("Team Code", text: $teamCode)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color(hex: "#333333"))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .autocapitalization(.allCharacters)

                    Spacer()

                    Button(action: joinTeam) {
                        Text("Join Team")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(teamCode.isEmpty ? Color.gray : Color(hex: "#FFFC00"))
                            .cornerRadius(10)
                    }
                    .disabled(teamCode.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Join Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }

    private func joinTeam() {
        // In real implementation, would lookup team by code
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Team Button

struct TeamButton: View {
    @ObservedObject var teamService = TeamService.shared
    @State private var showTeamList = false

    var body: some View {
        Button(action: { showTeamList = true }) {
            ZStack {
                Circle()
                    .fill(teamService.currentTeam?.color.swiftUIColor.opacity(0.3) ?? Color.black.opacity(0.6))
                    .frame(width: 56, height: 56)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(teamService.currentTeam?.color.swiftUIColor ?? .white)

                if teamService.currentTeam != nil {
                    Circle()
                        .stroke(teamService.currentTeam!.color.swiftUIColor, lineWidth: 2)
                        .frame(width: 56, height: 56)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showTeamList) {
            TeamListView()
        }
    }
}
