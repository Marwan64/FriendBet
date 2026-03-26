import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var page = 0
    @State private var displayName = UserDefaults.standard.string(forKey: "friendbet.displayName") ?? ""

    private let pages: [(title: String, copy: String, symbol: String, accent: Color)] = [
        ("Bet on the moments your group already talks about.", "Turn hot takes, challenges, and side bets into a polished social experience with stakes, receipts, and friendly rivalry.", "sparkles.rectangle.stack.fill", Color(hex: "FF8C68")),
        ("Follow every bet like a live event.", "Confidence, watchers, deadlines, and comments keep the energy high while the UI makes everything feel premium instead of chaotic.", "bolt.heart.fill", Color(hex: "5FE7C4")),
        ("Celebrate wins, settle losses, build the leaderboard.", "FriendBet turns casual wagers into a social game people want to come back to every day.", "trophy.fill", Color(hex: "F4C95D"))
    ]

    var body: some View {
        ZStack {
            AppGradientBackground()

                VStack(spacing: 28) {
                Spacer(minLength: 18)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 20) {
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .fill(item.accent.opacity(0.2))
                                .frame(height: 280)
                                .overlay {
                                    Image(systemName: item.symbol)
                                        .font(.system(size: 90, weight: .bold))
                                        .foregroundStyle(item.accent)
                                }

                            Text(item.title)
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)

                            Text(item.copy)
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 24)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 540)

                VStack(spacing: 14) {
                    TextField("Your display name", text: $displayName)
                        .textFieldStyle(.plain)
                        .padding(16)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)

                    if page == pages.count - 1 {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = authViewModel.prepareAppleSignInRequest(name: displayName)
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                authViewModel.handleAppleAuthorization(authorization)
                            case .failure(let error):
                                authViewModel.handleAppleError(error)
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 54)
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                        .disabled(authViewModel.isBusy)
                    } else {
                        Button("Continue") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                page += 1
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                    Button("Preview the app") {
                        authViewModel.signInDemo(name: displayName)
                    }
                    .foregroundStyle(.white.opacity(0.7))

                    if !authViewModel.firebaseReady {
                        Text("Firebase isn't configured yet. Add `GoogleService-Info.plist` to the FriendBet target and this onboarding flow will start real synced sessions.")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "F4C95D"))
                            .padding(.horizontal, 24)
                    }

                    if let authError = authViewModel.authError {
                        Text(authError)
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "FF8C68"))
                            .padding(.horizontal, 24)
                    }
                }

                Spacer()
            }
        }
    }
}
