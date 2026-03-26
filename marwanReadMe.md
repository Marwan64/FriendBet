# Sign in with Apple — Setup Instructions

Hey Marwan, these are the steps you need to complete before the Sign in with Apple changes on the `groups-debug` branch will work at runtime. None of these require code changes — they're all account/console setup.

---

## 1. Xcode — Add the Capability

1. Open `FriendBet.xcodeproj` in Xcode
2. Click the **FriendBet** target in the project navigator
3. Go to the **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search for and add **Sign in with Apple**

---

## 2. Apple Developer Console

1. Go to [developer.apple.com](https://developer.apple.com) and sign in
2. Navigate to **Certificates, Identifiers & Profiles → Identifiers**
3. Find your App ID (it matches your bundle ID, e.g. `com.yourname.FriendBet`)
4. Check the box for **Sign in with Apple**
5. Save

---

## 3. Firebase Console

1. Go to the [Firebase Console](https://console.firebase.google.com) and open the **friendbet-c0fce** project
2. Navigate to **Authentication → Sign-in providers**
3. Click **Apple** and enable it
4. Save

---

## Migration Note

Everyone in the group will be signed out and get a new user ID the first time they use the updated app. This means each person will need to **re-join their group once** using the existing invite code. Their old player slot in Firestore will become orphaned — this is a one-time thing and safe to ignore.

---

## Security Note (Separate Issue)

While you're in the Firebase Console, your Firestore database currently has **no security rules**, meaning it is publicly readable and writable by anyone. You should add rules under **Firestore Database → Rules**. Ask Kellam for the recommended rules when ready.
