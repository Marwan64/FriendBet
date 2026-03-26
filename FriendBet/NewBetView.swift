import SwiftUI

struct NewBetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BetStore

    @State private var title = ""
    @State private var subtitle = ""
    @State private var details = ""
    @State private var stake = "$50"
    @State private var category: BetCategory = .sports
    @State private var opponentID: String?

    private var canPublish: Bool {
        store.activeGroup != nil && opponentID != nil
    }

    var body: some View {
        ZStack {
            AppGradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Create a bet that feels worth sharing.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Clear stakes, strong copy, and the right opponent make the app feel alive.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))

                    if let activeGroup = store.activeGroup {
                        SecondaryChip(text: "Posting to \(activeGroup.name)", systemImage: "person.3.fill")
                    } else {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Create or join a group first")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Text("Bets now live inside private groups, so you need a group before you can publish one.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            labeledField("Title") {
                                TextField("What are you betting on?", text: $title)
                            }

                            labeledField("Subtitle") {
                                TextField("Add quick context people can scan fast", text: $subtitle)
                            }

                            labeledField("Stake") {
                                TextField("$50 dinner tab, coffee run, merch...", text: $stake)
                            }

                            labeledField("Category") {
                                Picker("Category", selection: $category) {
                                    ForEach(BetCategory.allCases) { item in
                                        Text(item.rawValue).tag(item)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            labeledField("Opponent") {
                                Picker("Opponent", selection: $opponentID) {
                                    Text("Select a player").tag(String?.none)
                                    ForEach(store.availableOpponents) { player in
                                        Text(player.name).tag(Optional(player.id))
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            labeledField("Details") {
                                TextField("How will this bet be settled?", text: $details, axis: .vertical)
                                    .lineLimit(4...8)
                            }
                        }
                    }

                    Button("Publish Bet") {
                        guard let opponentID else { return }
                        store.createBet(
                            title: title.isEmpty ? "Untitled bet" : title,
                            subtitle: subtitle.isEmpty ? "A new challenge just landed in the league." : subtitle,
                            category: category,
                            stake: stake,
                            challenger: store.currentUserID,
                            opponent: opponentID,
                            details: details.isEmpty ? "Friends will settle the outcome based on the agreed challenge rules." : details
                        )
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canPublish)
                    .opacity(canPublish ? 1 : 0.5)
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    dismiss()
                }
                .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.58))
            content()
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
        }
    }
}
