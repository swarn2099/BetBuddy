# BetBuddy iOS — Complete Technical Specification

> **Purpose:** This document is the single source of truth for building BetBuddy as a native iOS app in Swift/SwiftUI. Hand this entire file to Claude Code. It contains every screen, data model, API interaction, design token, and edge case needed to plan and build the app in one pass.

---

## 1. Project Overview

BetBuddy is a social fake-money betting app. Friends create groups, wager fake money on anything (who wins the game, will it rain, who shows up late), and settle bets manually. Everyone starts with a **global $1,000 balance** shared across all groups.

### Core Loop
1. Sign up via email magic link → set up profile (name, username, avatar)
2. Create or join a group using a 6-character invite code
3. Create bets within a group with 2–8 outcomes
4. Friends wager any amount they choose on an outcome
5. Bet creator manually settles by picking the winner
6. Winners split the losers' pool proportionally; push notifications fire

### Key Decisions (Already Confirmed)
- **Framework:** Swift/SwiftUI (pure native iOS, minimum iOS 17)
- **Backend:** Supabase (Auth, Postgres, Realtime, Edge Functions, Push)
- **Auth:** Supabase email magic link only
- **Balance:** One global $1,000 balance across all groups
- **Wagers:** Each person chooses their own amount (flexible, not fixed)
- **Creator participation:** Bet creator CAN wager on their own bet
- **Settling:** Only the bet creator picks the winner manually
- **Deadlines:** Optional per bet (open-ended if not set)
- **Group leadership:** Permanent — always the original creator, not transferable
- **Removed members:** Active wagers stay in the pool (forfeited, not refunded)
- **Theme:** Native dark/light mode support via SwiftUI `@Environment(\.colorScheme)`

---

## 2. Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI (iOS 17+) |
| Architecture | MVVM with `@Observable` (Observation framework) |
| Backend | Supabase (supabase-swift SDK) |
| Auth | Supabase Auth — email magic link |
| Database | Supabase Postgres (Row Level Security) |
| Realtime | Supabase Realtime (Postgres Changes) for live bet updates |
| Push Notifications | Supabase Edge Functions → APNs (via supabase-swift push) |
| Image Storage | Supabase Storage (avatars + group images) |
| Networking | supabase-swift SDK (handles REST + Realtime + Auth) |
| Local Storage | SwiftData or UserDefaults for session/preferences |
| Package Manager | Swift Package Manager |

### Dependencies (SPM)
```
supabase-swift (latest) — https://github.com/supabase/supabase-swift
```

That's it. The Supabase Swift SDK bundles Auth, Postgrest, Realtime, Storage, and Functions. No other third-party dependencies needed — SwiftUI handles animations, navigation, and all UI natively.

---

## 3. Supabase Schema

### 3.1 Tables

#### `profiles`
Created automatically on signup via a database trigger.

```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL CHECK (char_length(username) BETWEEN 2 AND 16 AND username ~ '^[a-zA-Z0-9_]+$'),
  first_name TEXT NOT NULL CHECK (char_length(first_name) BETWEEN 1 AND 50),
  last_name TEXT NOT NULL CHECK (char_length(last_name) BETWEEN 1 AND 50),
  avatar_url TEXT,
  balance INTEGER NOT NULL DEFAULT 1000 CHECK (balance >= 0),
  total_won INTEGER NOT NULL DEFAULT 0,
  total_lost INTEGER NOT NULL DEFAULT 0,
  push_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for leaderboard queries
CREATE INDEX idx_profiles_balance ON profiles(balance DESC);
```

#### `groups`
```sql
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 50),
  image_url TEXT,
  invite_code TEXT UNIQUE NOT NULL CHECK (char_length(invite_code) = 6),
  leader_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_groups_invite_code ON groups(invite_code);
```

#### `group_members`
```sql
CREATE TABLE group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(group_id, user_id)
);

CREATE INDEX idx_group_members_group ON group_members(group_id);
CREATE INDEX idx_group_members_user ON group_members(user_id);
```

#### `bets`
```sql
CREATE TABLE bets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
  emoji TEXT NOT NULL DEFAULT '🎲',
  outcomes TEXT[] NOT NULL CHECK (array_length(outcomes, 1) BETWEEN 2 AND 8),
  deadline TIMESTAMPTZ, -- NULL = open-ended
  pool INTEGER NOT NULL DEFAULT 0 CHECK (pool >= 0),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'settled')),
  winner TEXT, -- the winning outcome string, NULL until settled
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at TIMESTAMPTZ
);

CREATE INDEX idx_bets_group ON bets(group_id, created_at DESC);
CREATE INDEX idx_bets_creator ON bets(creator_id);
CREATE INDEX idx_bets_status ON bets(group_id, status);
```

#### `wagers`
```sql
CREATE TABLE wagers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_id UUID NOT NULL REFERENCES bets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL CHECK (amount > 0),
  side TEXT NOT NULL, -- which outcome they picked
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_wagers_bet ON wagers(bet_id);
CREATE INDEX idx_wagers_user ON wagers(user_id);
```

#### `notifications`
Server-side log of sent notifications (for in-app notification feed later).

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('bet_created', 'wager_placed', 'bet_settled', 'member_joined')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  metadata JSONB DEFAULT '{}', -- bet_id, group_id, etc.
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
```

### 3.2 Database Functions (Postgres RPC)

These run server-side to ensure atomicity. Call via `supabase.rpc()`.

#### `place_wager(p_bet_id UUID, p_user_id UUID, p_amount INT, p_side TEXT)`
```sql
CREATE OR REPLACE FUNCTION place_wager(
  p_bet_id UUID, p_user_id UUID, p_amount INT, p_side TEXT
) RETURNS JSONB AS $$
DECLARE
  v_bet RECORD;
  v_balance INT;
BEGIN
  -- Lock the bet row
  SELECT * INTO v_bet FROM bets WHERE id = p_bet_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bet not found'; END IF;
  IF v_bet.status != 'active' THEN RAISE EXCEPTION 'Bet is not active'; END IF;
  IF v_bet.deadline IS NOT NULL AND v_bet.deadline <= now() THEN
    RAISE EXCEPTION 'Betting is closed';
  END IF;
  IF NOT (p_side = ANY(v_bet.outcomes)) THEN
    RAISE EXCEPTION 'Invalid outcome';
  END IF;

  -- Check user is member of the group
  IF NOT EXISTS (
    SELECT 1 FROM group_members WHERE group_id = v_bet.group_id AND user_id = p_user_id
  ) THEN RAISE EXCEPTION 'Not a member of this group'; END IF;

  -- Check and deduct balance
  SELECT balance INTO v_balance FROM profiles WHERE id = p_user_id FOR UPDATE;
  IF v_balance < p_amount THEN RAISE EXCEPTION 'Insufficient funds'; END IF;

  UPDATE profiles SET balance = balance - p_amount, updated_at = now() WHERE id = p_user_id;

  -- Insert wager and update pool
  INSERT INTO wagers (bet_id, user_id, amount, side) VALUES (p_bet_id, p_user_id, p_amount, p_side);
  UPDATE bets SET pool = pool + p_amount WHERE id = p_bet_id;

  RETURN jsonb_build_object('success', true, 'new_balance', v_balance - p_amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### `settle_bet(p_bet_id UUID, p_user_id UUID, p_winner TEXT)`
```sql
CREATE OR REPLACE FUNCTION settle_bet(
  p_bet_id UUID, p_user_id UUID, p_winner TEXT
) RETURNS JSONB AS $$
DECLARE
  v_bet RECORD;
  v_wager RECORD;
  v_winner_pool INT := 0;
  v_loser_pool INT := 0;
  v_payout INT;
  v_results JSONB := '[]'::JSONB;
BEGIN
  SELECT * INTO v_bet FROM bets WHERE id = p_bet_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bet not found'; END IF;
  IF v_bet.creator_id != p_user_id THEN RAISE EXCEPTION 'Only the creator can settle'; END IF;
  IF v_bet.status = 'settled' THEN RAISE EXCEPTION 'Already settled'; END IF;
  IF NOT (p_winner = ANY(v_bet.outcomes)) THEN RAISE EXCEPTION 'Invalid outcome'; END IF;

  -- Calculate pools
  SELECT COALESCE(SUM(amount), 0) INTO v_winner_pool
    FROM wagers WHERE bet_id = p_bet_id AND side = p_winner;
  SELECT COALESCE(SUM(amount), 0) INTO v_loser_pool
    FROM wagers WHERE bet_id = p_bet_id AND side != p_winner;

  -- Pay out winners
  IF v_winner_pool > 0 THEN
    FOR v_wager IN SELECT * FROM wagers WHERE bet_id = p_bet_id AND side = p_winner LOOP
      v_payout := v_wager.amount + FLOOR((v_wager.amount::NUMERIC / v_winner_pool) * v_loser_pool);
      UPDATE profiles SET
        balance = balance + v_payout,
        total_won = total_won + (v_payout - v_wager.amount),
        updated_at = now()
      WHERE id = v_wager.user_id;

      v_results := v_results || jsonb_build_object(
        'user_id', v_wager.user_id, 'payout', v_payout, 'profit', v_payout - v_wager.amount, 'won', true
      );
    END LOOP;
  END IF;

  -- Record losses
  FOR v_wager IN SELECT * FROM wagers WHERE bet_id = p_bet_id AND side != p_winner LOOP
    UPDATE profiles SET
      total_lost = total_lost + v_wager.amount,
      updated_at = now()
    WHERE id = v_wager.user_id;

    v_results := v_results || jsonb_build_object(
      'user_id', v_wager.user_id, 'payout', 0, 'profit', -v_wager.amount, 'won', false
    );
  END LOOP;

  -- Mark settled
  UPDATE bets SET status = 'settled', winner = p_winner, settled_at = now() WHERE id = p_bet_id;

  RETURN jsonb_build_object('success', true, 'winner', p_winner, 'results', v_results);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### `delete_bet(p_bet_id UUID, p_user_id UUID)`
```sql
CREATE OR REPLACE FUNCTION delete_bet(
  p_bet_id UUID, p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_bet RECORD;
  v_wager RECORD;
BEGIN
  SELECT * INTO v_bet FROM bets WHERE id = p_bet_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bet not found'; END IF;
  IF v_bet.creator_id != p_user_id THEN RAISE EXCEPTION 'Only the creator can delete'; END IF;

  -- Refund all wagers
  FOR v_wager IN SELECT * FROM wagers WHERE bet_id = p_bet_id LOOP
    UPDATE profiles SET balance = balance + v_wager.amount, updated_at = now()
    WHERE id = v_wager.user_id;
  END LOOP;

  DELETE FROM wagers WHERE bet_id = p_bet_id;
  DELETE FROM bets WHERE id = p_bet_id;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### `remove_member(p_group_id UUID, p_leader_id UUID, p_target_id UUID)`
```sql
CREATE OR REPLACE FUNCTION remove_member(
  p_group_id UUID, p_leader_id UUID, p_target_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_group RECORD;
BEGIN
  SELECT * INTO v_group FROM groups WHERE id = p_group_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Group not found'; END IF;
  IF v_group.leader_id != p_leader_id THEN RAISE EXCEPTION 'Only the leader can remove members'; END IF;
  IF p_leader_id = p_target_id THEN RAISE EXCEPTION 'Cannot remove yourself'; END IF;

  -- Remove membership (wagers stay in pool — forfeited)
  DELETE FROM group_members WHERE group_id = p_group_id AND user_id = p_target_id;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### `generate_invite_code()`
```sql
CREATE OR REPLACE FUNCTION generate_invite_code() RETURNS TEXT AS $$
DECLARE
  v_code TEXT;
  v_chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- no I/O/0/1 to avoid confusion
  v_exists BOOLEAN;
BEGIN
  LOOP
    v_code := '';
    FOR i IN 1..6 LOOP
      v_code := v_code || substr(v_chars, floor(random() * length(v_chars) + 1)::INT, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM groups WHERE invite_code = v_code) INTO v_exists;
    IF NOT v_exists THEN RETURN v_code; END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
```

### 3.3 Row Level Security (RLS)

Enable RLS on all tables. Key policies:

```sql
-- Profiles: users can read all, update only their own
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles readable by all authenticated" ON profiles FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Users update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Groups: members can read their groups
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members can read groups" ON groups FOR SELECT USING (
  EXISTS (SELECT 1 FROM group_members WHERE group_id = groups.id AND user_id = auth.uid())
);
CREATE POLICY "Authenticated users can create groups" ON groups FOR INSERT WITH CHECK (auth.uid() = leader_id);

-- Group members: members can see other members
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members can see group members" ON group_members FOR SELECT USING (
  EXISTS (SELECT 1 FROM group_members gm WHERE gm.group_id = group_members.group_id AND gm.user_id = auth.uid())
);
CREATE POLICY "Users can join groups" ON group_members FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Bets: group members can read, group members can create
ALTER TABLE bets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Group members can read bets" ON bets FOR SELECT USING (
  EXISTS (SELECT 1 FROM group_members WHERE group_id = bets.group_id AND user_id = auth.uid())
);
CREATE POLICY "Group members can create bets" ON bets FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM group_members WHERE group_id = bets.group_id AND user_id = auth.uid())
  AND auth.uid() = creator_id
);

-- Wagers: group members can read, users create their own
ALTER TABLE wagers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Group members can read wagers" ON wagers FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM bets b
    JOIN group_members gm ON gm.group_id = b.group_id
    WHERE b.id = wagers.bet_id AND gm.user_id = auth.uid()
  )
);

-- Notifications: users see only their own
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users update own notifications" ON notifications FOR UPDATE USING (auth.uid() = user_id);
```

### 3.4 Supabase Storage Buckets

```sql
-- Create two public buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('group-images', 'group-images', true);
```

Storage policies: authenticated users can upload to their own folder (`avatars/{user_id}/*`), anyone can read public URLs.

### 3.5 Database Triggers

#### Auto-create profile on signup
```sql
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, username, first_name, last_name)
  VALUES (
    NEW.id,
    'user_' || substr(NEW.id::TEXT, 1, 8),  -- temp username
    '',  -- filled in onboarding
    ''
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

#### Auto-add creator as group member
```sql
CREATE OR REPLACE FUNCTION handle_new_group()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO group_members (group_id, user_id) VALUES (NEW.id, NEW.leader_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_group_created
  AFTER INSERT ON groups
  FOR EACH ROW EXECUTE FUNCTION handle_new_group();
```

---

## 4. Supabase Edge Functions (Push Notifications)

### 4.1 `send-push-notification`

A single Edge Function that handles all notification types. Called by database triggers or from the client after mutations.

```typescript
// supabase/functions/send-push-notification/index.ts
// Receives: { type, user_ids, title, body, metadata }
// Sends APNs push via Supabase's built-in push or a direct APNs call
// Also inserts into the notifications table

// Types:
// - "bet_created"   → sent to all group members except creator
// - "wager_placed"  → sent to bet creator
// - "bet_settled"   → sent to all participants (with win/loss amount in body)
// - "member_joined" → sent to all existing group members
```

### 4.2 Push Notification Content

| Event | Title | Body |
|-------|-------|------|
| Bet created | `{group_name}` | `{creator} created a new bet: "{title}"` |
| Wager placed | `{group_name}` | `{username} bet ${amount} on "{side}" in "{title}"` |
| Bet settled (won) | `You won! 🎉` | `"{winner}" won in "{title}" — you earned +${profit}` |
| Bet settled (lost) | `Better luck next time` | `"{winner}" won in "{title}" — you lost ${amount}` |
| Member joined | `{group_name}` | `{username} joined the group` |

### 4.3 Trigger Edge Function After Settle

After `settle_bet` RPC returns results, the iOS client calls the Edge Function with the results array to dispatch push notifications to all participants. This keeps the RPC pure SQL and offloads async push delivery to the Edge Function.

---

## 5. App Architecture (Swift/SwiftUI)

### 5.1 Project Structure

```
BetBuddy/
├── BetBuddyApp.swift              # @main entry, setup Supabase client
├── Info.plist
├── Assets.xcassets/
│
├── Models/
│   ├── Profile.swift               # Codable struct
│   ├── Group.swift                  # Codable struct
│   ├── GroupMember.swift            # Codable struct
│   ├── Bet.swift                    # Codable struct
│   ├── Wager.swift                  # Codable struct
│   └── AppNotification.swift        # Codable struct (avoid naming conflict with system Notification)
│
├── Services/
│   ├── SupabaseManager.swift        # Singleton, initializes Supabase client
│   ├── AuthService.swift            # Magic link, session management, onboarding
│   ├── ProfileService.swift         # CRUD profile, avatar upload
│   ├── GroupService.swift           # Create/join/leave/remove members
│   ├── BetService.swift             # Create/wager/settle/delete bets
│   ├── NotificationService.swift    # Push registration, Edge Function calls
│   └── RealtimeService.swift        # Supabase Realtime subscriptions
│
├── ViewModels/
│   ├── AuthViewModel.swift          # @Observable, handles auth state
│   ├── HomeViewModel.swift          # @Observable, group selection, bet list
│   ├── GroupViewModel.swift         # @Observable, group CRUD
│   ├── BetViewModel.swift           # @Observable, bet detail, wager, settle
│   ├── CreateBetViewModel.swift     # @Observable, bet creation flow
│   ├── LeaderboardViewModel.swift   # @Observable, ranked users
│   └── ProfileViewModel.swift       # @Observable, profile editing
│
├── Views/
│   ├── Auth/
│   │   ├── MagicLinkView.swift      # Email input → send magic link
│   │   ├── MagicLinkSentView.swift  # "Check your email" confirmation
│   │   └── OnboardingView.swift     # First name, last name, username, avatar
│   │
│   ├── Home/
│   │   ├── HomeView.swift           # Main tab — group header + bet cards
│   │   ├── GroupSelectorSheet.swift  # Bottom sheet to switch groups
│   │   ├── BetCardView.swift        # Individual bet card in feed
│   │   └── EmptyGroupView.swift     # No bets yet state
│   │
│   ├── Bet/
│   │   ├── BetDetailView.swift      # Full bet detail (sheet or push)
│   │   ├── PlaceWagerView.swift     # Outcome picker + amount input
│   │   ├── SettleBetView.swift      # Creator picks winner
│   │   └── CreateBetView.swift      # Multi-step bet creation
│   │
│   ├── Group/
│   │   ├── CreateGroupView.swift    # Name + image + get code
│   │   ├── JoinGroupView.swift      # Enter invite code
│   │   ├── GroupSettingsView.swift   # Members list, remove, invite code display
│   │   └── GroupImagePicker.swift    # PhotosPicker wrapper
│   │
│   ├── Leaderboard/
│   │   └── LeaderboardView.swift    # Global + per-group rankings
│   │
│   ├── Profile/
│   │   ├── ProfileView.swift        # Stats + edit + sign out
│   │   └── EditProfileView.swift    # Change username, name, avatar
│   │
│   └── Shared/
│       ├── AvatarView.swift         # Gradient circle with initial (or image)
│       ├── StatusPillView.swift     # Live/Closed/Settled badge
│       ├── OutcomeChipView.swift    # Color-coded outcome label
│       ├── BalanceView.swift        # Formatted balance with color
│       ├── GlassCard.swift          # Reusable card modifier
│       └── LoadingView.swift        # Spinner/skeleton
│
├── Theme/
│   ├── ColorTokens.swift            # Color extensions for dark/light
│   ├── Typography.swift             # Font definitions
│   └── Spacing.swift                # Layout constants
│
└── Extensions/
    ├── Color+Hex.swift
    ├── View+GlassCard.swift
    └── Date+Formatting.swift
```

### 5.2 Navigation Architecture

```
BetBuddyApp
├── if !authenticated → AuthFlow (NavigationStack)
│   ├── MagicLinkView
│   ├── MagicLinkSentView
│   └── OnboardingView (if profile incomplete)
│
└── if authenticated → MainTabView (TabView)
    ├── Tab 1: HomeView (NavigationStack)
    │   ├── BetDetailView (push or sheet)
    │   ├── GroupSelectorSheet
    │   ├── LeaderboardView (push from header icon)
    │   └── GroupSettingsView (push from header)
    │
    ├── Tab 2: CreateBetView (sheet presentation from tab)
    │
    └── Tab 3: ProfileView (NavigationStack)
        └── EditProfileView (push)
```

### 5.3 State Management

Use Swift's `@Observable` macro (Observation framework, iOS 17+).

```swift
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isOnboarded = false
    var currentUser: Profile?
    var isLoading = true

    // Listens to Supabase auth state changes
    func startAuthListener() { ... }
    func sendMagicLink(email: String) async throws { ... }
    func completeOnboarding(firstName: String, lastName: String, username: String, avatar: UIImage?) async throws { ... }
    func signOut() async { ... }
}
```

Global state is held in an `@Observable AppState` or individual ViewModels injected via `@Environment`.

---

## 6. Design System — "Glass Casino" (Native)

Port the existing BetBuddy web design system to native SwiftUI. Respect system dark/light mode — no custom toggle needed (iOS handles it).

### 6.1 Color Tokens

```swift
// Theme/ColorTokens.swift
import SwiftUI

extension Color {
    // MARK: - Backgrounds
    static let bgPrimary = Color("bgPrimary") // Dark: #06060A, Light: #F5F5F7
    static let bgCard = Color("bgCard")       // Dark: rgba(255,255,255,0.04), Light: #FFFFFF
    static let bgSurface = Color("bgSurface") // Dark: rgba(255,255,255,0.05), Light: rgba(0,0,0,0.04)
    static let bgInput = Color("bgInput")     // Dark: rgba(255,255,255,0.03), Light: #FFFFFF
    static let bgEmoji = Color("bgEmoji")     // Dark: rgba(255,255,255,0.06), Light: rgba(0,0,0,0.04)

    // MARK: - Text
    static let textPrimary = Color("textPrimary")     // Dark: #FAFAFA, Light: #111114
    static let textSecondary = Color("textSecondary") // Dark: rgba(255,255,255,0.45), Light: rgba(0,0,0,0.45)
    static let textMuted = Color("textMuted")         // Dark: rgba(255,255,255,0.18), Light: rgba(0,0,0,0.25)
    static let textLabel = Color("textLabel")         // Dark: rgba(255,255,255,0.3), Light: rgba(0,0,0,0.35)

    // MARK: - Accents
    static let accentPrimary = Color("accentPrimary")   // Dark: #6366F1, Light: #4F46E5
    static let accentSuccess = Color("accentSuccess")   // Dark: #22C55E, Light: #16A34A
    static let accentDanger = Color("accentDanger")     // Dark: #EF4444, Light: #DC2626
    static let accentWarning = Color("accentWarning")   // Dark: #F59E0B, Light: #D97706
    static let accentViolet = Color("accentViolet")     // Dark: #8B5CF6, Light: #7C3AED
    static let accentSettled = Color("accentSettled")    // Dark: #818CF8, Light: #4F46E5

    // MARK: - Borders
    static let borderPrimary = Color("borderPrimary")   // Dark: rgba(255,255,255,0.07), Light: rgba(0,0,0,0.07)
    static let borderHover = Color("borderHover")       // Dark: rgba(255,255,255,0.12), Light: rgba(0,0,0,0.12)
}

// Define all colors in Assets.xcassets with "Any" and "Dark" appearances
```

### 6.2 Outcome Colors

```swift
enum OutcomeColor: CaseIterable {
    case green, red, blue, orange, purple, cyan, pink, indigo

    var color: Color {
        switch self {
        case .green:  return Color(hex: 0x34C759) // adapt for light mode
        case .red:    return Color(hex: 0xFF3B30)
        case .blue:   return Color(hex: 0x007AFF)
        case .orange: return Color(hex: 0xFF9F0A)
        case .purple: return Color(hex: 0xAF52DE)
        case .cyan:   return Color(hex: 0x5AC8FA)
        case .pink:   return Color(hex: 0xFF2D55)
        case .indigo: return Color(hex: 0x5856D6)
        }
    }

    static func forIndex(_ i: Int) -> OutcomeColor {
        allCases[i % allCases.count]
    }
}
```

### 6.3 Typography

```swift
// Theme/Typography.swift
import SwiftUI

extension Font {
    // Display / headings
    static let heading1 = Font.system(size: 30, weight: .bold, design: .default)
    static let heading2 = Font.system(size: 22, weight: .bold, design: .default)
    static let cardTitle = Font.system(size: 15, weight: .semibold)
    static let cardMeta = Font.system(size: 12, weight: .regular)
    static let body15 = Font.system(size: 15, weight: .regular)
    static let button15 = Font.system(size: 15, weight: .semibold)
    static let label11 = Font.system(size: 11, weight: .semibold)
    static let navLabel = Font.system(size: 10, weight: .medium)

    // Monospace for all dollar amounts
    static let balanceLarge = Font.system(size: 24, weight: .bold, design: .monospaced)
    static let statValue = Font.system(size: 20, weight: .bold, design: .monospaced)
    static let poolAmount = Font.system(size: 14, weight: .bold, design: .monospaced)
    static let chipAmount = Font.system(size: 13, weight: .bold, design: .monospaced)
}
```

**Rule:** Every dollar amount in the app uses `.monospaced` design. All labels use `.default` design.

### 6.4 Spacing Constants

```swift
enum Spacing {
    static let screenH: CGFloat = 20       // Horizontal padding
    static let topPadding: CGFloat = 16    // Below nav bar (safe area handles the rest)
    static let cardGap: CGFloat = 10       // Between bet cards
    static let sectionGap: CGFloat = 24    // Between sections
    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 14
    static let pillRadius: CGFloat = 100
    static let inputRadius: CGFloat = 14
}
```

### 6.5 Avatar Gradients

Same system as web — deterministic gradient based on username hash.

```swift
struct AvatarView: View {
    let name: String
    let size: CGFloat
    let imageURL: String?

    private static let gradients: [(Color, Color)] = [
        (Color(hex: 0x6366F1), Color(hex: 0x8B5CF6)),
        (Color(hex: 0xF59E0B), Color(hex: 0xEF4444)),
        (Color(hex: 0x22C55E), Color(hex: 0x10B981)),
        (Color(hex: 0xEC4899), Color(hex: 0x8B5CF6)),
        (Color(hex: 0x06B6D4), Color(hex: 0x3B82F6)),
        (Color(hex: 0xF97316), Color(hex: 0xEC4899)),
    ]

    private var gradient: LinearGradient {
        let idx = Int(name.first?.asciiValue ?? 0) % Self.gradients.count
        let pair = Self.gradients[idx]
        return LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        if let url = imageURL, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackAvatar
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}
```

### 6.6 Glass Card Modifier

```swift
struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .stroke(Color.borderPrimary, lineWidth: 1)
            )
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 2, y: 1)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
```

---

## 7. Screens — Detailed Specs

### 7.1 Auth Flow

#### MagicLinkView
- Single email input field with `.emailAddress` keyboard
- "Continue" button → calls `supabase.auth.signInWithOTP(email:)`
- Loading state while sending
- On success → navigate to MagicLinkSentView
- Subtle animated dice emoji at top

#### MagicLinkSentView
- "Check your email" message with the email displayed
- "Open Mail" button → `UIApplication.shared.open(mailURL)`
- "Resend" button (disabled for 60s countdown)
- "Use a different email" link → pops back

#### OnboardingView (shown after first magic link verification)
- First name (required)
- Last name (required)
- Username (required, 2-16 chars, alphanumeric + underscore, live availability check)
- Profile photo (optional, PhotosPicker → upload to Supabase Storage)
- "Get Started" button → updates profile, navigates to main app
- "$1,000 starting balance" badge at bottom

**Deep Link Handling:** Configure `BetBuddyApp.swift` to handle the Supabase magic link callback URL scheme. Register a custom URL scheme or Universal Link. On receiving the callback, exchange the token via `supabase.auth.session(from:)`.

### 7.2 Home (Feed) Tab

#### Header
- **Left:** Group selector button — shows current group image (small circle, 32px) + group name. Tap opens GroupSelectorSheet.
- **Center:** App title "BetBuddy" (only when no group selected) or group name
- **Right:** Leaderboard icon button (trophy) → pushes LeaderboardView

#### Group Selector Sheet (`.sheet`)
- List of user's groups with image + name + member count
- "Create Group" button at top
- "Join Group" button below
- Current group has a checkmark

#### If no groups yet
- Full-screen empty state: "Join or create a group to start betting"
- Two big buttons: "Create Group" / "Join Group"

#### If group selected but no bets
- EmptyGroupView: dice emoji + "No bets yet" + "Tap + to create one"

#### Bet Cards Feed
- Scrollable list of bet cards, sorted newest first
- Each BetCardView shows:
  - Row 1: Emoji (44×44, rounded rect bg) + Title (truncated) + StatusPill (Live/Closed/Settled)
  - Row 2: Outcome chips (color-coded, flex layout)
  - Row 3: Pool amount (monospace, accent color) + stacked avatar dots of participants
- Tap → pushes or sheets BetDetailView
- Pull to refresh

#### Stats Row (optional, between header and cards)
- 3 stat cards: Active bets (green), Total Pool (primary), Members (warning)

### 7.3 Create Bet Tab (Middle +)

Presented as a **full-screen sheet** (not a push navigation). Multi-step flow or single scrollable form:

1. **Group selector** — if user is in multiple groups, pick which group this bet is for (default to currently selected group from Home tab)
2. **Emoji picker** — grid of 15 emoji options (same as web: 🎲🌮🌧️⏰📚☕🏀🎬🎵🍕🚗💪🎯🤔😂)
3. **Title** — "What's the bet?" text field, max 200 chars
4. **Outcomes** — start with 2 text fields, + button to add up to 8, - button to remove (min 2). Color dots next to each field matching OutcomeColor order.
5. **Deadline** — optional DatePicker. Toggle to enable/disable. If enabled, must be in the future.
6. **Create Bet** button — disabled until title + 2 valid outcomes. Calls `supabase.from("bets").insert(...)`. On success, dismiss sheet, trigger "bet_created" push notification via Edge Function.

### 7.4 Profile Tab

#### ProfileView
- Large avatar (56px) with edit icon overlay → opens EditProfileView
- Username + full name
- **Balance card:** Current balance (large monospace), colored green if ≥ $1000, red if below
- **Stats grid (2 columns):**
  - Total Won (green, monospace)
  - Total Lost (red, monospace)
- **Groups section:** List of groups user belongs to
- **Sign Out button** — danger-styled, confirmation alert before signing out

#### EditProfileView (pushed)
- First name / last name fields
- Username field (live availability check, debounced 500ms)
- Avatar picker (PhotosPicker)
- "Save" button in toolbar

### 7.5 Bet Detail View

Presented as a sheet or pushed navigation. Shows full bet info:

#### Header
- Emoji (large) + Title + "by {creator}" + StatusPill

#### Stats Row
- Pool amount (monospace) + Deadline (or "Open") + Participant count

#### Outcome Breakdown
- Each outcome as a row:
  - Color dot + outcome name + progress bar (% of pool) + amount + percentage
  - If settled: winning outcome has green checkmark + "Winner!" label
  - Stacked avatar dots of people who bet on this outcome

#### All Wagers Section
- List: Avatar + username + amount (monospace) + OutcomeChip
- Scrollable if many

#### Actions (contextual)
- **If active + not past deadline + user is group member:**
  - "Place Your Bet" section
  - Outcome selector buttons (color-coded, tap to select)
  - Amount input (number pad) + quick chips ($10, $25, $50, $100)
  - "Bet ${amount} on {side}" CTA button
  - Shows current balance

- **If active + past deadline:**
  - Lock icon + "Betting is closed — waiting for {creator} to settle"

- **If active + user is creator:**
  - "Settle This Bet" section
  - Button per outcome: `"{outcome}" Wins` — tap triggers `settle_bet` RPC
  - Confirmation alert before settling

- **If active + user is creator:**
  - "Delete Bet" button (danger) — two-tap confirm, calls `delete_bet` RPC, refunds all

- **If settled:**
  - Winner highlighted, all payouts shown per user

### 7.6 Leaderboard View

Pushed from Home header.

- **Scope toggle:** "Global" / current group name (segmented control)
- **Global:** All users ranked by balance
- **Group:** Members of selected group ranked by balance
- Rank badges: 🥇🥈🥉 for top 3, monospace number for rest
- Each row: Rank + Avatar (40px) + username + balance (colored: green ≥ $1000, red < $1000)
- Current user's row highlighted with accent border

### 7.7 Group Settings View

Pushed from Home (gear icon or long-press group in selector).

- Group image (large) + Group name
- **Invite Code** section — large display of the 6-char code + "Copy" button + "Share" button (ShareLink)
- **Members list** — Avatar + username + role badge ("Leader" for creator)
  - If current user is leader: swipe-to-delete on non-leader members → confirmation alert → `remove_member` RPC
- **Leave Group** button (if not leader) — confirmation → deletes from group_members
- **Delete Group** button (if leader, only if no active bets) — danger, confirmation

### 7.8 Create Group / Join Group

#### CreateGroupView (sheet)
- Group name text field (1–50 chars)
- Group image (optional, PhotosPicker)
- "Create Group" → inserts into `groups` table with `generate_invite_code()`, auto-joins creator
- On success: show the invite code prominently with "Share" + "Copy" buttons
- "Done" dismisses

#### JoinGroupView (sheet)
- 6-character code input (styled as 6 individual boxes, auto-advance)
- "Join" button → looks up group by `invite_code`, inserts into `group_members`
- Error states: invalid code, already a member
- On success: dismiss, switch to that group in Home tab, trigger "member_joined" push

---

## 8. Push Notifications

### 8.1 APNs Setup

1. Enable "Push Notifications" capability in Xcode
2. Register for remote notifications in `BetBuddyApp.swift`
3. On receiving device token, store in `profiles.push_token` via Supabase
4. Handle foreground notifications with `UNUserNotificationCenterDelegate`

```swift
// In BetBuddyApp.swift or AppDelegate adapter
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // Parse metadata from notification payload
        // Deep-link to relevant bet/group
    }
}
```

### 8.2 Notification Triggers

| Event | Who sends | Who receives | When |
|-------|-----------|-------------|------|
| Bet created | Client → Edge Function | All group members except creator | After successful bet insert |
| Wager placed | Client → Edge Function | Bet creator | After successful wager RPC |
| Bet settled | Client → Edge Function | All participants in the bet | After successful settle RPC |
| Member joined | Client → Edge Function | All existing group members | After successful join |

### 8.3 Edge Function Call Pattern

```swift
// After settling a bet:
let results = try await supabase.rpc("settle_bet", params: [...]).execute()
// Then:
try await supabase.functions.invoke("send-push-notification", options: .init(body: [
    "type": "bet_settled",
    "bet_id": betId,
    "group_id": groupId,
    "winner": winner,
    "results": results // contains user_ids, payouts, profits
]))
```

---

## 9. Realtime Subscriptions

Use Supabase Realtime to keep the feed live without polling.

```swift
// In RealtimeService.swift
func subscribeToBets(groupId: UUID) {
    let channel = supabase.realtime.channel("bets:\(groupId)")

    channel.onPostgresChange(InsertAction.self, schema: "public", table: "bets",
        filter: .eq("group_id", value: groupId.uuidString)) { insert in
        // Add new bet to feed
    }

    channel.onPostgresChange(UpdateAction.self, schema: "public", table: "bets",
        filter: .eq("group_id", value: groupId.uuidString)) { update in
        // Update bet (settled, pool changed)
    }

    channel.onPostgresChange(DeleteAction.self, schema: "public", table: "bets",
        filter: .eq("group_id", value: groupId.uuidString)) { delete in
        // Remove deleted bet
    }

    channel.subscribe()
}

func subscribeToWagers(betId: UUID) {
    // Subscribe to wagers for a specific bet (in detail view)
}
```

---

## 10. Betting Business Logic (Replicated from Web)

### Rules
- Users can bet on any active bet in their group that hasn't passed its deadline
- Users can bet any amount up to their current balance (amount > 0)
- Multiple bets on the same event are allowed (even different outcomes)
- No minimum bet amount (just > 0)
- Bet creator CAN wager on their own bet

### Settling
- Only the bet creator can settle
- Winners split the losers' pool proportional to their wager size
- Formula: `payout = wagerAmount + floor((wagerAmount / totalWinnerPool) * totalLoserPool)`
- If no one bet on the losing side, everyone just gets their money back

### Deleting
- Only the bet creator can delete
- Deleting refunds ALL participants their full wager amounts
- Requires two-tap confirmation

### Deadlines
- Optional — bets can be open-ended (deadline = NULL)
- Once deadline passes: no new wagers, status visually shows "Closed", waiting for creator to settle
- Countdown display: minutes if <1h, hours if <1d, days if <7d, date otherwise

### Users
- Username: 2-16 chars, alphanumeric + underscore only
- Starting balance: $1,000
- Balance can never go below $0 (enforced at DB level)

---

## 11. Animations & Transitions

Use SwiftUI's built-in animation system — no third-party animation libraries.

| Element | Animation |
|---------|-----------|
| Bet cards appearing | `.transition(.move(edge: .bottom).combined(with: .opacity))` with staggered delay |
| Sheet presentation | Default SwiftUI sheet spring |
| Balance changes | `.contentTransition(.numericText())` on Text view |
| Button press | `.scaleEffect` with `.spring` on tap |
| Status pill dot (Live) | Pulsing opacity animation (2s infinite) |
| Outcome progress bars | `.animation(.spring, value: percentage)` |
| Card tap | Slight scale down on press via `ButtonStyle` |
| Tab switching | Default TabView transition |
| Pull to refresh | Native `.refreshable` modifier |

---

## 12. Error Handling

- Network errors → toast/alert with retry option
- Insufficient funds → inline error under amount input
- Invalid invite code → shake animation on input + error text
- Session expired → auto-redirect to MagicLinkView
- RPC failures → parse Postgres exception message, show user-friendly version

---

## 13. Build Order for Claude Code

Execute in this exact sequence. Each phase should be a commit.

### Phase 1: Project Setup
- Create Xcode project (iOS 17+, SwiftUI)
- Add supabase-swift via SPM
- Set up `SupabaseManager.swift` with project URL + anon key
- Create all model structs (Codable)
- Set up Assets.xcassets with all color tokens for dark/light

### Phase 2: Supabase Schema
- Write and apply all SQL migrations (tables, indexes, RLS, functions, triggers, storage buckets)
- Test RPC functions with sample data

### Phase 3: Auth Flow
- `AuthService.swift` — magic link send, session listener, token refresh
- `AuthViewModel.swift` — auth state management
- `MagicLinkView`, `MagicLinkSentView`, `OnboardingView`
- Deep link handling for magic link callback
- Profile creation on first login

### Phase 4: Group System
- `GroupService.swift` — create, join, leave, remove member, fetch groups
- `CreateGroupView`, `JoinGroupView`, `GroupSettingsView`
- Image upload to Supabase Storage
- Invite code generation and validation

### Phase 5: Home Feed
- `HomeViewModel.swift` — group selection, bet fetching
- `HomeView`, `BetCardView`, `GroupSelectorSheet`
- Realtime subscription for live bet updates
- Pull to refresh

### Phase 6: Bet Creation
- `CreateBetViewModel.swift` — validation, submission
- `CreateBetView` — full creation flow
- Emoji picker, outcome management, deadline picker

### Phase 7: Bet Detail & Wagering
- `BetViewModel.swift` — detail loading, wager placement, settling
- `BetDetailView`, `PlaceWagerView`, `SettleBetView`
- `place_wager` RPC integration
- `settle_bet` RPC integration
- `delete_bet` RPC integration

### Phase 8: Leaderboard & Profile
- `LeaderboardView` — global + per-group ranking
- `ProfileView`, `EditProfileView`
- Balance display, win/loss stats
- Sign out flow

### Phase 9: Push Notifications
- APNs capability + entitlements
- Device token registration → `profiles.push_token`
- Edge Function: `send-push-notification`
- Trigger notifications after: bet created, wager placed, bet settled, member joined
- Foreground notification handling
- Deep link from notification tap → relevant screen

### Phase 10: Polish
- All animations (card stagger, balance counter, button press, pull-to-refresh)
- Empty states for all screens
- Error handling and user-friendly error messages
- Loading states and skeleton views
- Haptic feedback on bet placement and settlement

### Phase 11: Testing & Ship
- Test all RPC functions for edge cases (concurrent wagers, double settle, etc.)
- Test push notifications end-to-end
- Test dark/light mode on all screens
- Test with multiple users in same group
- Archive and submit to TestFlight

---

## 14. Environment Configuration

### Supabase Keys (stored in a Config.plist or environment)
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

**Never hardcode keys in source.** Use a `Config.plist` excluded from git, or Xcode build settings with `.xcconfig` files.

### APNs
- Generate APNs key in Apple Developer portal
- Upload to Supabase Dashboard → Auth → Push Notifications
- Configure bundle ID match

---

## 15. Edge Cases & Safety

| Scenario | Behavior |
|----------|----------|
| User bets more than balance | RPC rejects, "Insufficient funds" error |
| Creator settles twice | RPC rejects, "Already settled" |
| Wager after deadline | RPC rejects, "Betting is closed" |
| User removed from group | Membership deleted, active wagers forfeited (stay in pool) |
| User in 0 groups | Home shows empty state with Create/Join buttons |
| All participants bet same side | Everyone gets their money back (no losers to pay from) |
| No one wagered | Creator can still settle (no payouts), or delete |
| Creator leaves app mid-creation | Sheet dismissal loses unsaved data (acceptable for v1) |
| Concurrent wagers | Postgres row-level locks in RPC prevent race conditions |
| Magic link expires | User re-enters email, gets new link |
| Username taken during onboarding | Live check on keystroke (debounced), error on submit |
| Group image upload fails | Group created without image, user can add later in settings |
| Push token not available | Notifications silently fail, app still functions |
| Device offline | Show cached data, queue actions for retry (stretch goal) |

---

## 16. Future Considerations (NOT in v1, but design for extensibility)

- In-app notification feed (the `notifications` table is ready for this)
- Group chat / bet comments
- Bet categories / tags
- Weekly/monthly leaderboard resets
- Achievement badges
- Bet templates ("Quick bet: coin flip")
- Android version (would need separate native or cross-platform rewrite)
- Widget for home screen showing active bets

---

