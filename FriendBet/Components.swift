import SwiftUI

struct AppGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "07111F"), Color(hex: "10233F"), Color(hex: "081018")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "FF8C68").opacity(0.22))
                .frame(width: 280)
                .blur(radius: 30)
                .offset(x: 120, y: -240)

            Circle()
                .fill(Color(hex: "5FE7C4").opacity(0.18))
                .frame(width: 240)
                .blur(radius: 28)
                .offset(x: -150, y: 180)
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "F4C95D"), Color(hex: "FF8C68")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct SecondaryChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: Capsule())
    }
}

struct AvatarView: View {
    let player: Player
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(player.accent.gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(player.initials)
                    .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.8))
            }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let caption: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Circle()
                            .fill(color)
                            .frame(width: 18, height: 18)
                    }

                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.88))

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
    }
}

struct BetHeroCard: View {
    let bet: Bet
    let challenger: Player
    let opponent: Player

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label(bet.category.rawValue, systemImage: bet.category.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(bet.category.tint)

                    Spacer()

                    Text(bet.status.rawValue.uppercased())
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white, in: Capsule())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(bet.title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text(bet.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                HStack(spacing: 12) {
                    HStack(spacing: -10) {
                        AvatarView(player: challenger, size: 38)
                        AvatarView(player: opponent, size: 38)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(challenger.name) vs \(opponent.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Stake: \(bet.stake)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()
                }

                HStack {
                    SecondaryChip(text: "\(bet.watchers) watching", systemImage: "eye.fill")
                    SecondaryChip(text: "\(bet.confidence)% confidence", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
        }
    }
}

struct BetRowCard: View {
    let bet: Bet
    let challenger: Player
    let opponent: Player

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bet.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(bet.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(bet.category.rawValue)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(bet.category.tint)
                }

                HStack {
                    HStack(spacing: 10) {
                        AvatarView(player: challenger, size: 32)
                        AvatarView(player: opponent, size: 32)
                        Text("\(challenger.handle) vs \(opponent.handle)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Text(bet.stake)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                HStack {
                    Label(bet.dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    Spacer()
                    Label("\(bet.comments)", systemImage: "bubble.left.and.bubble.right.fill")
                    Label("\(bet.watchers)", systemImage: "eye.fill")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 255, int >> 8 & 255, int & 255)
        default:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 255, int & 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
