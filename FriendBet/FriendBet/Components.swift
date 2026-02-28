import SwiftUI

struct PlayerAvatar: View {
    let player: Player
    let size: CGFloat
    
    var colors: [Color] {
        let hash = abs(player.name.hashValue)
        let palettes: [[Color]] = [
            [.indigo, .purple],
            [.blue, .cyan],
            [.green, .teal],
            [.orange, .red],
            [.pink, .purple],
            [.yellow, .orange],
        ]
        return palettes[hash % palettes.count]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
            Text(player.emoji)
                .font(.system(size: size * 0.5))
        }
    }
}
