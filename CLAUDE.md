# CLAUDE.md — BetBuddy iOS

## Project Overview
BetBuddy is a native iOS app (Swift/SwiftUI, iOS 17+) where friends create groups and wager fake money on anything. Everyone starts with a global $1,000 balance. Backend is Supabase (Auth, Postgres, Realtime, Edge Functions, Storage).

## Key Files — Read Before Writing Code
- `BETBUDDY_IOS_SPEC.md` — Complete technical specification. Contains every screen, data model, Supabase schema, RPC function, design token, and edge case. **This is the single source of truth. Read it fully before starting any phase.**

## Tech Stack
- **Language:** Swift 5.9+
- **UI:** SwiftUI (iOS 17+ minimum)
- **Architecture:** MVVM with `@Observable` (Observation framework)
- **Backend:** Supabase (supabase-swift SDK via SPM)
- **Auth:** Supabase email magic link
- **Database:** Supabase Postgres with Row Level Security
- **Realtime:** Supabase Realtime (Postgres Changes)
- **Push:** APNs via Supabase Edge Functions
- **Storage:** Supabase Storage (avatars, group images)
- **Dependencies:** Only `supabase-swift` — no other third-party packages

## Architecture Rules
- Every ViewModel uses `@Observable` macro, not `ObservableObject`/`@Published`
- Services are plain classes with async/await methods that call Supabase
- ViewModels call Services, Views observe ViewModels
- All mutations that touch balance go through Postgres RPC functions (`place_wager`, `settle_bet`, `delete_bet`) — never update balance directly from the client
- Models are `Codable` structs matching the Supabase table schemas exactly (snake_case mapped via `CodingKeys` or Supabase's built-in decoder)

## Navigation Structure
```
App Entry
├── Not authenticated → AuthFlow (NavigationStack)
│   ├── MagicLinkView (email input)
│   ├── MagicLinkSentView (check your email)
│   └── OnboardingView (name, username, avatar — shown once after first login)
│
└── Authenticated → MainTabView (TabView, 3 tabs)
    ├── Tab 1: Home (NavigationStack)
    │   ├── HomeView (group selector + bet cards feed)
    │   ├── BetDetailView (sheet or push)
    │   ├── LeaderboardView (push from header)
    │   └── GroupSettingsView (push)
    │
    ├── Tab 2: Create Bet (presented as full-screen sheet)
    │   └── CreateBetView (group → emoji → title → outcomes → deadline → create)
    │
    └── Tab 3: Profile (NavigationStack)
        ├── ProfileView (stats, groups, sign out)
        └── EditProfileView (push)
```

## Project Structure
```
BetBuddy/
├── BetBuddyApp.swift
├── Models/          — Codable structs (Profile, Group, GroupMember, Bet, Wager, AppNotification)
├── Services/        — Supabase interaction layer (AuthService, ProfileService, GroupService, BetService, NotificationService, RealtimeService, SupabaseManager)
├── ViewModels/      — @Observable classes (AuthViewModel, HomeViewModel, GroupViewModel, BetViewModel, CreateBetViewModel, LeaderboardViewModel, ProfileViewModel)
├── Views/
│   ├── Auth/        — MagicLinkView, MagicLinkSentView, OnboardingView
│   ├── Home/        — HomeView, BetCardView, GroupSelectorSheet, EmptyGroupView
│   ├── Bet/         — BetDetailView, PlaceWagerView, SettleBetView, CreateBetView
│   ├── Group/       — CreateGroupView, JoinGroupView, GroupSettingsView
│   ├── Leaderboard/ — LeaderboardView
│   ├── Profile/     — ProfileView, EditProfileView
│   └── Shared/      — AvatarView, StatusPillView, OutcomeChipView, BalanceView, GlassCard, LoadingView
├── Theme/           — ColorTokens, Typography, Spacing
├── Extensions/      — Color+Hex, View+GlassCard, Date+Formatting
└── Assets.xcassets/ — All color sets with Any/Dark appearances
```

## Design System — "Glass Casino"

### Colors (defined in Assets.xcassets with dark/light variants)
| Token | Dark | Light |
|-------|------|-------|
| bgPrimary | #06060A | #F5F5F7 |
| bgCard | rgba(255,255,255,0.04) | #FFFFFF |
| textPrimary | #FAFAFA | #111114 |
| textSecondary | rgba(255,255,255,0.45) | rgba(0,0,0,0.45) |
| accentPrimary | #6366F1 | #4F46E5 |
| accentSuccess | #22C55E | #16A34A |
| accentDanger | #EF4444 | #DC2626 |
| accentWarning | #F59E0B | #D97706 |

Full token list is in `BETBUDDY_IOS_SPEC.md` Section 6.1.

### Typography Rules
- **Every dollar amount** uses `.monospaced` design: `Font.system(size: _, weight: .bold, design: .monospaced)`
- **Every label** uses default system design with weight `.semibold`, size 11, uppercase, wide letter-spacing
- **Headings** use default system design, weight `.bold`
- No custom fonts — system fonts with `.monospaced` for numbers gives the right look natively

### Outcome Colors (assigned in order, cycling)
```
Green #34C759 → Red #FF3B30 → Blue #007AFF → Orange #FF9F0A → Purple #AF52DE → Cyan #5AC8FA → Pink #FF2D55 → Indigo #5856D6
```

### Component Patterns
- Cards use a `.glassCard()` ViewModifier (background + border + corner radius + shadow)
- Avatar uses deterministic gradient from username hash, or AsyncImage if avatar_url exists
- Status pills: Live (green + pulsing dot), Closed (warning), Settled (indigo)
- Buttons: filled gradient for primary CTA, bordered for secondary
- Theme: use native `@Environment(\.colorScheme)` — no custom toggle, respect system setting

## Supabase Configuration

### Client Setup
```swift
// SupabaseManager.swift
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "YOUR_SUPABASE_URL")!,
    supabaseKey: "YOUR_ANON_KEY"
)
```

Store URL and key in a `Config.plist` excluded from git via `.gitignore`. Never hardcode in source.

### Critical: Use RPC for All Balance Mutations
These Postgres functions handle atomicity and prevent race conditions:
- `place_wager(p_bet_id, p_user_id, p_amount, p_side)` — deducts balance, inserts wager, updates pool
- `settle_bet(p_bet_id, p_user_id, p_winner)` — calculates payouts, updates balances, marks settled
- `delete_bet(p_bet_id, p_user_id)` — refunds all wagers, deletes bet
- `remove_member(p_group_id, p_leader_id, p_target_id)` — removes member, wagers forfeited

Call via: `try await supabase.rpc("function_name", params: [...]).execute()`

### Realtime
Subscribe to bet changes per group for live feed updates:
```swift
supabase.realtime.channel("bets:\(groupId)")
    .onPostgresChange(InsertAction.self, table: "bets", filter: .eq("group_id", value: groupId)) { ... }
    .subscribe()
```

### Storage Buckets
- `avatars` — user profile images, path: `avatars/{user_id}/{filename}`
- `group-images` — group images, path: `group-images/{group_id}/{filename}`

Both are public buckets. Upload via `supabase.storage.from("bucket").upload(...)`.

## Business Logic (Do Not Change)
- Global $1,000 starting balance (one balance across all groups)
- Wager amounts are flexible — each person picks their own amount
- Bet creator CAN wager on their own bet
- Only bet creator can settle (manually picks winner)
- Payout formula: `payout = wagerAmount + floor((wagerAmount / totalWinnerPool) * totalLoserPool)`
- Deleting a bet refunds all participants
- Removing a group member forfeits their active wagers (no refund)
- Group leadership is permanent (original creator, not transferable)
- Deadlines are optional; if set and passed, no new wagers allowed
- Balance cannot go below 0 (enforced by DB CHECK constraint)

## Push Notifications
4 notification types, all dispatched via the `send-push-notification` Edge Function:
1. **bet_created** → all group members except creator
2. **wager_placed** → bet creator
3. **bet_settled** → all bet participants (personalized win/loss message)
4. **member_joined** → all existing group members

Pattern: client performs mutation → on success → calls Edge Function with metadata → Edge Function sends APNs + inserts into `notifications` table.

## Build Order
Follow the 11 phases in `BETBUDDY_IOS_SPEC.md` Section 13 exactly. Each phase produces something testable. Commit after each phase.

1. Project setup + SPM + models + color assets
2. Supabase schema (SQL migrations)
3. Auth flow (magic link + onboarding)
4. Group system (create/join/settings)
5. Home feed (group selector + bet cards + realtime)
6. Bet creation
7. Bet detail + wagering + settling
8. Leaderboard + profile
9. Push notifications
10. Animations + polish + error handling
11. Testing + TestFlight

## Commands
```bash
# Open project
open BetBuddy.xcodeproj

# Build
xcodebuild -scheme BetBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run Supabase locally (if using Supabase CLI)
supabase start
supabase db push
supabase functions serve
```

## Rules
- **Never update `profiles.balance` directly from the client.** Always use RPC functions.
- **Never use `ObservableObject` or `@Published`.** Use `@Observable` macro only.
- **Never use third-party UI libraries.** SwiftUI handles everything — animations, navigation, sheets, pickers.
- **Every file gets one responsibility.** No 500-line mega-views. Extract subviews and components.
- **All models must be `Codable` and match the Supabase schema.** Use `CodingKeys` for snake_case → camelCase mapping.
- **All async calls use Swift concurrency** (async/await, not completion handlers or Combine).
- **All errors are caught and shown to the user** via alerts or inline error text. No silent failures.
- **Test both dark and light mode** after every visual change.
- **Deep link handling for magic link must work.** Configure URL scheme in Info.plist and handle in `BetBuddyApp.swift` via `.onOpenURL`.
