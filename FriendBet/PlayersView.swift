import SwiftUI
import UIKit

struct PlayersView: View {
    @EnvironmentObject private var store: BetStore
    @State private var newGroupName = ""
    @State private var inviteCode = ""
    @State private var copiedInviteCode = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Groups", subtitle: "Keep every circle private. Create your own group, invite friends, and switch between them whenever you want.")

                activeGroupCard

                groupActionsCard

                if store.groups.count > 1 {
                    SectionHeader(title: "Your Groups", subtitle: "Switch contexts without mixing everyone into one feed.")
                        .padding(.top, 6)

                    ForEach(store.groups) { group in
                        Button {
                            store.selectGroup(id: group.id)
                        } label: {
                            GlassCard {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(group.accent.opacity(0.92))
                                        .frame(width: 14, height: 14)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(group.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)

                                        Text("\(group.memberCount) members • Invite \(group.inviteCode)")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.68))
                                    }

                                    Spacer()

                                    if group.id == store.activeGroupID {
                                        Text("ACTIVE")
                                            .font(.caption2.weight(.black))
                                            .foregroundStyle(.black.opacity(0.8))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: "F4C95D"), in: Capsule())
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionHeader(title: "Players", subtitle: store.activeGroup == nil ? "Join a group to start seeing your people." : "The people in this group, and only this group.")

                if store.players.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.activeGroup == nil ? "No group members yet" : "Just you for now")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text(store.activeGroup == nil ? "Create a group or join with an invite code to bring your friends in." : "Share the invite code above and your friends will appear here as soon as they join.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                } else {
                    ForEach(store.players) { player in
                        GlassCard {
                            HStack(spacing: 14) {
                                AvatarView(player: player, size: 58)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(player.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        if player.id == store.currentUserID {
                                            Text("YOU")
                                                .font(.caption2.weight(.black))
                                                .foregroundStyle(.black.opacity(0.8))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color(hex: "F4C95D"), in: Capsule())
                                        }
                                    }

                                    Text(player.handle)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.68))

                                    HStack(spacing: 10) {
                                        SecondaryChip(text: "\(player.wins) wins", systemImage: "checkmark.seal.fill")
                                        SecondaryChip(text: "\(player.streak) streak", systemImage: "flame.fill")
                                    }
                                }

                                Spacer()
                            }
                        }
                    }
                }

                if let syncError = store.syncError {
                    Text(syncError)
                        .font(.footnote)
                        .foregroundStyle(Color(hex: "FF8C68"))
                }
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .background(AppGradientBackground())
        .navigationTitle("Players")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var activeGroupCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                if let activeGroup = store.activeGroup {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(activeGroup.name)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)

                            Text("\(activeGroup.memberCount) members in this circle")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.68))
                        }

                        Spacer()

                        Text("LIVE")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.black.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(activeGroup.accent, in: Capsule())
                    }

                    HStack {
                        SecondaryChip(text: "Invite \(activeGroup.inviteCode)", systemImage: "number")
                        SecondaryChip(text: activeGroup.ownerID == store.currentUserID ? "You own this group" : "Member", systemImage: "person.crop.circle.fill")
                    }

                    Button(copiedInviteCode ? "Invite Code Copied" : "Copy Invite Code") {
                        UIPasteboard.general.string = activeGroup.inviteCode
                        copiedInviteCode = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("No private group yet")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Create a group for your own friends or join one with an invite code. Nothing syncs into one giant global room anymore.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
    }

    private var groupActionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Create Group")
                        .font(.headline)
                        .foregroundStyle(.white)

                    TextField("Friday Picks, Roommates, Fantasy Crew...", text: $newGroupName)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)

                    Button("Create Private Group") {
                        copiedInviteCode = false
                        store.createGroup(named: newGroupName)
                        newGroupName = ""
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.isLoading)
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Join with Invite Code")
                        .font(.headline)
                        .foregroundStyle(.white)

                    TextField("Enter code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)

                    Button("Join Group") {
                        copiedInviteCode = false
                        store.joinGroup(inviteCode: inviteCode)
                        inviteCode = ""
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.isLoading)
                }
            }
        }
    }
}
