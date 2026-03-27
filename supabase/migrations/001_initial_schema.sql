-- ============================================================
-- BetBuddy — Initial Schema Migration
-- ============================================================

-- 1. TABLES
-- ------------------------------------------------------------

-- profiles: created automatically on signup via trigger
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL CHECK (char_length(username) BETWEEN 2 AND 16 AND username ~ '^[a-zA-Z0-9_]+$'),
  first_name TEXT NOT NULL DEFAULT '' CHECK (char_length(first_name) <= 50),
  last_name TEXT NOT NULL DEFAULT '' CHECK (char_length(last_name) <= 50),
  avatar_url TEXT,
  balance INTEGER NOT NULL DEFAULT 1000 CHECK (balance >= 0),
  total_won INTEGER NOT NULL DEFAULT 0,
  total_lost INTEGER NOT NULL DEFAULT 0,
  push_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_profiles_balance ON profiles(balance DESC);

-- groups
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 50),
  image_url TEXT,
  invite_code TEXT UNIQUE NOT NULL CHECK (char_length(invite_code) = 6),
  leader_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_groups_invite_code ON groups(invite_code);

-- group_members
CREATE TABLE group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(group_id, user_id)
);

CREATE INDEX idx_group_members_group ON group_members(group_id);
CREATE INDEX idx_group_members_user ON group_members(user_id);

-- bets
CREATE TABLE bets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
  emoji TEXT NOT NULL DEFAULT '🎲',
  outcomes TEXT[] NOT NULL CHECK (array_length(outcomes, 1) BETWEEN 2 AND 8),
  deadline TIMESTAMPTZ,
  pool INTEGER NOT NULL DEFAULT 0 CHECK (pool >= 0),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'settled')),
  winner TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at TIMESTAMPTZ
);

CREATE INDEX idx_bets_group ON bets(group_id, created_at DESC);
CREATE INDEX idx_bets_creator ON bets(creator_id);
CREATE INDEX idx_bets_status ON bets(group_id, status);

-- wagers
CREATE TABLE wagers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_id UUID NOT NULL REFERENCES bets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL CHECK (amount > 0),
  side TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_wagers_bet ON wagers(bet_id);
CREATE INDEX idx_wagers_user ON wagers(user_id);

-- notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('bet_created', 'wager_placed', 'bet_settled', 'member_joined')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);


-- 2. ROW LEVEL SECURITY
-- ------------------------------------------------------------

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles readable by all authenticated"
  ON profiles FOR SELECT
  USING (auth.role() = 'authenticated');
CREATE POLICY "Users update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);
CREATE POLICY "Users insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members can read groups"
  ON groups FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM group_members WHERE group_id = groups.id AND user_id = auth.uid())
  );
CREATE POLICY "Authenticated users can create groups"
  ON groups FOR INSERT
  WITH CHECK (auth.uid() = leader_id);

ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members can see group members"
  ON group_members FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM group_members gm WHERE gm.group_id = group_members.group_id AND gm.user_id = auth.uid())
  );
CREATE POLICY "Users can join groups"
  ON group_members FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own membership"
  ON group_members FOR DELETE
  USING (auth.uid() = user_id);

ALTER TABLE bets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Group members can read bets"
  ON bets FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM group_members WHERE group_id = bets.group_id AND user_id = auth.uid())
  );
CREATE POLICY "Group members can create bets"
  ON bets FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM group_members WHERE group_id = bets.group_id AND user_id = auth.uid())
    AND auth.uid() = creator_id
  );

ALTER TABLE wagers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Group members can read wagers"
  ON wagers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM bets b
      JOIN group_members gm ON gm.group_id = b.group_id
      WHERE b.id = wagers.bet_id AND gm.user_id = auth.uid()
    )
  );

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id);


-- 3. RPC FUNCTIONS
-- ------------------------------------------------------------

-- generate_invite_code: creates a unique 6-char alphanumeric code
CREATE OR REPLACE FUNCTION generate_invite_code() RETURNS TEXT AS $$
DECLARE
  v_code TEXT;
  v_chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
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

-- place_wager: atomically deducts balance, inserts wager, updates pool
CREATE OR REPLACE FUNCTION place_wager(
  p_bet_id UUID, p_user_id UUID, p_amount INT, p_side TEXT
) RETURNS JSONB AS $$
DECLARE
  v_bet RECORD;
  v_balance INT;
BEGIN
  SELECT * INTO v_bet FROM bets WHERE id = p_bet_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bet not found'; END IF;
  IF v_bet.status != 'active' THEN RAISE EXCEPTION 'Bet is not active'; END IF;
  IF v_bet.deadline IS NOT NULL AND v_bet.deadline <= now() THEN
    RAISE EXCEPTION 'Betting is closed';
  END IF;
  IF NOT (p_side = ANY(v_bet.outcomes)) THEN
    RAISE EXCEPTION 'Invalid outcome';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM group_members WHERE group_id = v_bet.group_id AND user_id = p_user_id
  ) THEN RAISE EXCEPTION 'Not a member of this group'; END IF;

  SELECT balance INTO v_balance FROM profiles WHERE id = p_user_id FOR UPDATE;
  IF v_balance < p_amount THEN RAISE EXCEPTION 'Insufficient funds'; END IF;

  UPDATE profiles SET balance = balance - p_amount, updated_at = now() WHERE id = p_user_id;
  INSERT INTO wagers (bet_id, user_id, amount, side) VALUES (p_bet_id, p_user_id, p_amount, p_side);
  UPDATE bets SET pool = pool + p_amount WHERE id = p_bet_id;

  RETURN jsonb_build_object('success', true, 'new_balance', v_balance - p_amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- settle_bet: calculates payouts, updates balances, marks settled
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

  SELECT COALESCE(SUM(amount), 0) INTO v_winner_pool
    FROM wagers WHERE bet_id = p_bet_id AND side = p_winner;
  SELECT COALESCE(SUM(amount), 0) INTO v_loser_pool
    FROM wagers WHERE bet_id = p_bet_id AND side != p_winner;

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

  FOR v_wager IN SELECT * FROM wagers WHERE bet_id = p_bet_id AND side != p_winner LOOP
    UPDATE profiles SET
      total_lost = total_lost + v_wager.amount,
      updated_at = now()
    WHERE id = v_wager.user_id;

    v_results := v_results || jsonb_build_object(
      'user_id', v_wager.user_id, 'payout', 0, 'profit', -v_wager.amount, 'won', false
    );
  END LOOP;

  UPDATE bets SET status = 'settled', winner = p_winner, settled_at = now() WHERE id = p_bet_id;

  RETURN jsonb_build_object('success', true, 'winner', p_winner, 'results', v_results);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- delete_bet: refunds all wagers, deletes bet
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

  FOR v_wager IN SELECT * FROM wagers WHERE bet_id = p_bet_id LOOP
    UPDATE profiles SET balance = balance + v_wager.amount, updated_at = now()
    WHERE id = v_wager.user_id;
  END LOOP;

  DELETE FROM wagers WHERE bet_id = p_bet_id;
  DELETE FROM bets WHERE id = p_bet_id;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- remove_member: removes member, wagers stay forfeited
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

  DELETE FROM group_members WHERE group_id = p_group_id AND user_id = p_target_id;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. TRIGGERS
-- ------------------------------------------------------------

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, username, first_name, last_name)
  VALUES (
    NEW.id,
    'user_' || substr(NEW.id::TEXT, 1, 8),
    '',
    ''
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Auto-add creator as group member
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


-- 5. STORAGE BUCKETS
-- ------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('group-images', 'group-images', true);

-- Storage policies: authenticated users can upload to their own folder
CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

CREATE POLICY "Users can update own avatar"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

CREATE POLICY "Anyone can read avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

CREATE POLICY "Group members can upload group images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'group-images'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Anyone can read group images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'group-images');
