import SwiftUI

struct NewBetView: View {
    @EnvironmentObject var store: BetStore
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var category: BetCategory = .other
    @State private var selectedPlayers: [UUID] = []
    @State private var wagers: [UUID: String] = [:]
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var creatorId: UUID? = nil
    @State private var step = 0
    
    private var canProceedStep0: Bool { !title.isEmpty && !description.isEmpty }
    private var canProceedStep1: Bool { selectedPlayers.count >= 2 }
    private var canCreate: Bool {
        selectedPlayers.allSatisfy { id in
            let val = Double(wagers[id] ?? "") ?? 0
            return val > 0
        } && creatorId != nil
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress
                ProgressBar(step: step, total: 3)
                    .padding(.horizontal)
                    .padding(.top)
                
                TabView(selection: $step) {
                    Step0View(title: $title, description: $description, category: $category)
                        .tag(0)
                    Step1View(selectedPlayers: $selectedPlayers)
                        .tag(1)
                    Step2View(selectedPlayers: selectedPlayers, wagers: $wagers,
                               creatorId: $creatorId, hasDueDate: $hasDueDate, dueDate: $dueDate)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
                
                // Navigation buttons
                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    if step < 2 {
                        Button("Next") { step += 1 }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                            .disabled(step == 0 ? !canProceedStep0 : !canProceedStep1)
                    } else {
                        Button("Create Bet 🤝") { createBet() }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                            .disabled(!canCreate)
                    }
                }
                .padding()
            }
            .navigationTitle("New Bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createBet() {
        guard let cid = creatorId else { return }
        let sides = selectedPlayers.compactMap { pid -> BetSide? in
            guard let player = store.players.first(where: { $0.id == pid }) else { return nil }
            let wager = Double(wagers[pid] ?? "0") ?? 0
            return BetSide(player: player, wager: wager, accepted: pid == cid)
        }
        var bet = Bet(
            title: title,
            description: description,
            category: category,
            status: .pending,
            sides: sides,
            createdBy: cid
        )
        bet.dueDate = hasDueDate ? dueDate : nil
        if sides.allSatisfy({ $0.accepted }) { bet.status = .active }
        store.addBet(bet)
        dismiss()
    }
}

struct ProgressBar: View {
    let step: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.indigo : Color(.systemGray4))
                    .frame(height: 4)
                    .animation(.easeInOut, value: step)
            }
        }
    }
}

// MARK: Step 0 – Details
struct Step0View: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var category: BetCategory
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("What's the bet?")
                    .font(.title2.weight(.bold))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    TextField("e.g. Ping Pong Rematch", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    TextField("Describe the rules...", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Category").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                        ForEach(BetCategory.allCases, id: \.self) { cat in
                            CategoryButton(cat: cat, isSelected: category == cat) {
                                category = cat
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct CategoryButton: View {
    let cat: BetCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.title2)
                Text(cat.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? cat.color.opacity(0.2) : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? cat.color : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? cat.color : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: Step 1 – Players
struct Step1View: View {
    @EnvironmentObject var store: BetStore
    @Binding var selectedPlayers: [UUID]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Who's betting?")
                    .font(.title2.weight(.bold))
                Text("Select at least 2 players")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if store.players.isEmpty {
                    Text("No players yet! Add players in the Players tab first.")
                        .foregroundColor(.secondary)
                        .padding(.top)
                } else {
                    ForEach(store.players) { player in
                        let selected = selectedPlayers.contains(player.id)
                        Button {
                            if selected { selectedPlayers.removeAll { $0 == player.id } }
                            else { selectedPlayers.append(player.id) }
                        } label: {
                            HStack(spacing: 14) {
                                PlayerAvatar(player: player, size: 44)
                                Text(player.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundColor(selected ? .indigo : .secondary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selected ? Color.indigo.opacity(0.1) : Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selected ? Color.indigo : Color.clear, lineWidth: 2)
                                    )
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: Step 2 – Wagers
struct Step2View: View {
    @EnvironmentObject var store: BetStore
    let selectedPlayers: [UUID]
    @Binding var wagers: [UUID: String]
    @Binding var creatorId: UUID?
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    
    var players: [Player] {
        selectedPlayers.compactMap { id in store.players.first(where: { $0.id == id }) }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Set the stakes")
                    .font(.title2.weight(.bold))
                
                ForEach(players) { player in
                    HStack(spacing: 12) {
                        PlayerAvatar(player: player, size: 40)
                        Text(player.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        HStack(spacing: 4) {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: Binding(
                                get: { wagers[player.id] ?? "" },
                                set: { wagers[player.id] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Who is creating this bet?")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(players) { player in
                        Button {
                            creatorId = player.id
                        } label: {
                            HStack {
                                PlayerAvatar(player: player, size: 32)
                                Text(player.name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: creatorId == player.id ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(.indigo)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Set a due date", isOn: $hasDueDate)
                        .font(.subheadline.weight(.semibold))
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                }
                .padding(14)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
    }
}
