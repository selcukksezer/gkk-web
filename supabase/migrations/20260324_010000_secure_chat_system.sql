-- ============================================================
-- Secure chat system with moderation, filters, bans and audit
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Core tables ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel TEXT NOT NULL CHECK (channel IN ('global', 'guild', 'dm', 'trade', 'system')),
  sender_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  recipient_user_id UUID NULL REFERENCES public.users(id) ON DELETE CASCADE,
  guild_id UUID NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  sender_name TEXT NOT NULL,
  content TEXT NOT NULL,
  is_system BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  read_at TIMESTAMPTZ NULL,
  deleted_at TIMESTAMPTZ NULL,
  deleted_by_user_id UUID NULL REFERENCES public.users(id) ON DELETE SET NULL,
  deleted_reason TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chat_messages_content_len CHECK (char_length(content) BETWEEN 1 AND 200),
  CONSTRAINT chat_messages_dm_recipient CHECK (
    (channel = 'dm' AND recipient_user_id IS NOT NULL)
    OR (channel <> 'dm')
  ),
  CONSTRAINT chat_messages_guild_required CHECK (
    (channel = 'guild' AND guild_id IS NOT NULL)
    OR (channel <> 'guild')
  )
);

ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS channel TEXT,
  ADD COLUMN IF NOT EXISTS sender_user_id UUID,
  ADD COLUMN IF NOT EXISTS recipient_user_id UUID NULL,
  ADD COLUMN IF NOT EXISTS guild_id UUID NULL,
  ADD COLUMN IF NOT EXISTS sender_name TEXT,
  ADD COLUMN IF NOT EXISTS content TEXT,
  ADD COLUMN IF NOT EXISTS is_system BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS deleted_by_user_id UUID NULL,
  ADD COLUMN IF NOT EXISTS deleted_reason TEXT NULL,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

DO $$
BEGIN
  -- Legacy schema compatibility: copy old column names into the new ones when present.
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'chat_messages'
      AND column_name = 'sender_id'
  ) THEN
    EXECUTE 'UPDATE public.chat_messages SET sender_user_id = sender_id WHERE sender_user_id IS NULL';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'chat_messages'
      AND column_name = 'recipient_id'
  ) THEN
    EXECUTE 'UPDATE public.chat_messages SET recipient_user_id = recipient_id WHERE recipient_user_id IS NULL';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'chat_messages'
      AND column_name = 'timestamp'
  ) THEN
    EXECUTE 'UPDATE public.chat_messages SET created_at = "timestamp" WHERE created_at IS NULL';
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_chat_messages_channel_created_at
  ON public.chat_messages(channel, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_chat_messages_guild_created_at
  ON public.chat_messages(guild_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_chat_messages_dm_lookup
  ON public.chat_messages(sender_user_id, recipient_user_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_chat_messages_dm_unread
  ON public.chat_messages(recipient_user_id, sender_user_id, created_at DESC)
  WHERE channel = 'dm' AND deleted_at IS NULL AND read_at IS NULL;


CREATE TABLE IF NOT EXISTS public.chat_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  reporter_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (message_id, reporter_user_id)
);

ALTER TABLE public.chat_reports
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_chat_reports_message_id ON public.chat_reports(message_id);


CREATE TABLE IF NOT EXISTS public.chat_blocks (
  blocker_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  blocked_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_user_id, blocked_user_id),
  CONSTRAINT chat_blocks_self_block CHECK (blocker_user_id <> blocked_user_id)
);

ALTER TABLE public.chat_blocks
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();


CREATE TABLE IF NOT EXISTS public.chat_bans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  scope TEXT NOT NULL CHECK (scope IN ('global', 'channel', 'guild')),
  channel TEXT NULL CHECK (channel IS NULL OR channel IN ('global', 'guild', 'dm', 'trade', 'system')),
  guild_id UUID NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_by_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  revoked_at TIMESTAMPTZ NULL,
  revoked_by_user_id UUID NULL REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chat_bans_scope_shape CHECK (
    (scope = 'global' AND channel IS NULL AND guild_id IS NULL)
    OR (scope = 'channel' AND channel IS NOT NULL AND guild_id IS NULL)
    OR (scope = 'guild' AND guild_id IS NOT NULL AND channel = 'guild')
  )
);

ALTER TABLE public.chat_bans
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_chat_bans_active_user
  ON public.chat_bans(user_id, expires_at DESC)
  WHERE revoked_at IS NULL;


CREATE TABLE IF NOT EXISTS public.chat_filters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scope TEXT NOT NULL CHECK (scope IN ('global', 'channel', 'guild')),
  channel TEXT NULL CHECK (channel IS NULL OR channel IN ('global', 'guild', 'dm', 'trade', 'system')),
  guild_id UUID NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  term TEXT NOT NULL,
  replacement TEXT NOT NULL DEFAULT '***',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chat_filters_term_len CHECK (char_length(term) BETWEEN 1 AND 64),
  CONSTRAINT chat_filters_replacement_len CHECK (char_length(replacement) BETWEEN 1 AND 32),
  CONSTRAINT chat_filters_scope_shape CHECK (
    (scope = 'global' AND channel IS NULL AND guild_id IS NULL)
    OR (scope = 'channel' AND channel IS NOT NULL AND guild_id IS NULL)
    OR (scope = 'guild' AND guild_id IS NOT NULL AND channel = 'guild')
  )
);

ALTER TABLE public.chat_filters
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_filters_unique_term
  ON public.chat_filters (scope, COALESCE(channel, ''), COALESCE(guild_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(term));


CREATE TABLE IF NOT EXISTS public.chat_moderators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  scope TEXT NOT NULL CHECK (scope IN ('global', 'channel', 'guild')),
  channel TEXT NULL CHECK (channel IS NULL OR channel IN ('global', 'guild', 'dm', 'trade', 'system')),
  guild_id UUID NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  can_delete BOOLEAN NOT NULL DEFAULT true,
  can_ban BOOLEAN NOT NULL DEFAULT true,
  can_manage_filters BOOLEAN NOT NULL DEFAULT false,
  can_manage_moderators BOOLEAN NOT NULL DEFAULT false,
  assigned_by_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  revoked_at TIMESTAMPTZ NULL,
  revoked_by_user_id UUID NULL REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chat_moderators_scope_shape CHECK (
    (scope = 'global' AND channel IS NULL AND guild_id IS NULL)
    OR (scope = 'channel' AND channel IS NOT NULL AND guild_id IS NULL)
    OR (scope = 'guild' AND guild_id IS NOT NULL AND channel = 'guild')
  )
);

ALTER TABLE public.chat_moderators
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_moderators_active
  ON public.chat_moderators (user_id, scope, COALESCE(channel, ''), COALESCE(guild_id, '00000000-0000-0000-0000-000000000000'::uuid))
  WHERE revoked_at IS NULL;


CREATE TABLE IF NOT EXISTS public.chat_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID NULL REFERENCES public.users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  target_user_id UUID NULL REFERENCES public.users(id) ON DELETE SET NULL,
  target_message_id UUID NULL REFERENCES public.chat_messages(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.chat_audit_log
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();


-- ── Helper functions ───────────────────────────────────────

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS chat_messages_touch_updated_at ON public.chat_messages;
CREATE TRIGGER chat_messages_touch_updated_at
BEFORE UPDATE ON public.chat_messages
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS chat_filters_touch_updated_at ON public.chat_filters;
CREATE TRIGGER chat_filters_touch_updated_at
BEFORE UPDATE ON public.chat_filters
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


CREATE OR REPLACE FUNCTION public.escape_chat_regex(p_text TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN regexp_replace(p_text, '([\\.\[\]\{\}\(\)\*\+\?\^\$\|\-])', E'\\\\\1', 'g');
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION public.get_current_chat_user()
RETURNS public.users AS $$
DECLARE
  v_auth_id UUID;
  v_user public.users%ROWTYPE;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RAISE EXCEPTION 'Kimlik dogrulama gerekli';
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kullanici bulunamadi';
  END IF;

  RETURN v_user;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION public.normalize_chat_content(p_content TEXT)
RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
BEGIN
  v_content := regexp_replace(COALESCE(p_content, ''), '[[:cntrl:]]', '', 'g');
  v_content := regexp_replace(v_content, '\s+', ' ', 'g');
  v_content := btrim(v_content);
  RETURN v_content;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION public.apply_chat_filters(
  p_content TEXT,
  p_channel TEXT,
  p_guild_id UUID
)
RETURNS TEXT AS $$
DECLARE
  v_result TEXT := p_content;
  v_filter RECORD;
BEGIN
  FOR v_filter IN
    SELECT term, replacement
    FROM public.chat_filters
    WHERE is_active = true
      AND (
        scope = 'global'
        OR (scope = 'channel' AND channel = p_channel)
        OR (scope = 'guild' AND p_channel = 'guild' AND guild_id = p_guild_id)
      )
    ORDER BY char_length(term) DESC
  LOOP
    v_result := regexp_replace(
      v_result,
      public.escape_chat_regex(v_filter.term),
      v_filter.replacement,
      'gi'
    );
  END LOOP;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION public.has_chat_permission(
  p_actor_user_id UUID,
  p_permission TEXT,
  p_channel TEXT,
  p_guild_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_actor RECORD;
BEGIN
  SELECT id, guild_id, guild_role INTO v_actor FROM public.users WHERE id = p_actor_user_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF p_channel = 'guild'
     AND v_actor.guild_id = p_guild_id
     AND COALESCE(v_actor.guild_role, '') IN ('leader', 'commander')
  THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.chat_moderators cm
    WHERE cm.user_id = p_actor_user_id
      AND cm.revoked_at IS NULL
      AND (
        cm.scope = 'global'
        OR (cm.scope = 'channel' AND cm.channel = p_channel)
        OR (cm.scope = 'guild' AND p_channel = 'guild' AND cm.guild_id = p_guild_id)
      )
      AND (
        p_permission = 'delete' AND cm.can_delete
        OR p_permission = 'ban' AND cm.can_ban
        OR p_permission = 'manage_filters' AND cm.can_manage_filters
        OR p_permission = 'manage_moderators' AND cm.can_manage_moderators
      )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;


CREATE OR REPLACE FUNCTION public.get_active_chat_ban(
  p_user_id UUID,
  p_channel TEXT,
  p_guild_id UUID DEFAULT NULL
)
RETURNS public.chat_bans AS $$
DECLARE
  v_ban public.chat_bans%ROWTYPE;
BEGIN
  SELECT *
  INTO v_ban
  FROM public.chat_bans cb
  WHERE cb.user_id = p_user_id
    AND cb.revoked_at IS NULL
    AND cb.expires_at > now()
    AND (
      cb.scope = 'global'
      OR (cb.scope = 'channel' AND cb.channel = p_channel)
      OR (cb.scope = 'guild' AND p_channel = 'guild' AND cb.guild_id = p_guild_id)
    )
  ORDER BY cb.expires_at DESC
  LIMIT 1;

  RETURN v_ban;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;


CREATE OR REPLACE FUNCTION public.write_chat_audit(
  p_actor_user_id UUID,
  p_action TEXT,
  p_target_user_id UUID DEFAULT NULL,
  p_target_message_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.chat_audit_log (actor_user_id, action, target_user_id, target_message_id, metadata)
  VALUES (p_actor_user_id, p_action, p_target_user_id, p_target_message_id, COALESCE(p_metadata, '{}'::jsonb));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ── Public chat functions ──────────────────────────────────

DROP FUNCTION IF EXISTS public.get_chat_history(TEXT, INTEGER);
CREATE OR REPLACE FUNCTION public.get_chat_history(
  p_channel TEXT,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  channel TEXT,
  sender_id UUID,
  sender_name TEXT,
  content TEXT,
  "timestamp" TIMESTAMPTZ,
  is_system BOOLEAN,
  recipient_user_id UUID,
  guild_id UUID
) AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_channel NOT IN ('global', 'guild', 'dm', 'trade', 'system') THEN
    RAISE EXCEPTION 'Gecersiz kanal';
  END IF;

  IF p_channel = 'guild' AND v_user.guild_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    cm.id,
    cm.channel,
    cm.sender_user_id,
    cm.sender_name,
    cm.content,
    cm.created_at,
    cm.is_system,
    cm.recipient_user_id,
    cm.guild_id
  FROM public.chat_messages cm
  WHERE cm.deleted_at IS NULL
    AND cm.channel = p_channel
    AND (
      p_channel IN ('global', 'trade', 'system')
      OR (p_channel = 'guild' AND cm.guild_id = v_user.guild_id)
      OR (p_channel = 'dm' AND (cm.sender_user_id = v_user.id OR cm.recipient_user_id = v_user.id))
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE cb.blocker_user_id = v_user.id
        AND cb.blocked_user_id = cm.sender_user_id
    )
  ORDER BY cm.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_chat_history(TEXT, INTEGER) TO authenticated;


DROP FUNCTION IF EXISTS public.send_chat_message(TEXT, TEXT, UUID);
CREATE OR REPLACE FUNCTION public.send_chat_message(
  p_channel TEXT,
  p_content TEXT,
  p_recipient_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_recipient public.users%ROWTYPE;
  v_clean TEXT;
  v_filtered TEXT;
  v_last_message_at TIMESTAMPTZ;
  v_ban public.chat_bans%ROWTYPE;
  v_message_id UUID;
  v_sender_name TEXT;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_channel NOT IN ('global', 'guild', 'dm', 'trade') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz kanal');
  END IF;

  v_clean := public.normalize_chat_content(p_content);
  IF char_length(v_clean) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bos mesaj gonderilemez');
  END IF;

  IF char_length(v_clean) > 200 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj en fazla 200 karakter olabilir');
  END IF;

  IF p_channel = 'guild' AND v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca sohbeti icin bir loncaya ait olmalisiniz');
  END IF;

  IF p_channel = 'dm' AND p_recipient_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ozel mesaj icin hedef kullanici gerekli');
  END IF;

  IF p_channel = 'dm' THEN
    SELECT * INTO v_recipient FROM public.users WHERE id = p_recipient_user_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hedef oyuncu bulunamadi');
    END IF;

    IF v_recipient.id = v_user.id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Kendinize ozel mesaj gonderemezsiniz');
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.chat_blocks cb
      WHERE (cb.blocker_user_id = v_user.id AND cb.blocked_user_id = v_recipient.id)
         OR (cb.blocker_user_id = v_recipient.id AND cb.blocked_user_id = v_user.id)
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Bu oyuncu ile ozel mesaj kullanilamiyor');
    END IF;
  END IF;

  SELECT created_at INTO v_last_message_at
  FROM public.chat_messages
  WHERE sender_user_id = v_user.id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_last_message_at IS NOT NULL AND v_last_message_at > now() - interval '2 seconds' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cok hizli mesaj gonderiyorsunuz');
  END IF;

  v_ban := public.get_active_chat_ban(v_user.id, p_channel, v_user.guild_id);
  IF v_ban.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Sohbetten gecici olarak uzaklastirildiniz',
      'ban_expires_at', v_ban.expires_at,
      'ban_reason', v_ban.reason
    );
  END IF;

  v_filtered := public.apply_chat_filters(v_clean, p_channel, v_user.guild_id);
  v_sender_name := COALESCE(NULLIF(v_user.display_name, ''), v_user.username);

  INSERT INTO public.chat_messages (
    channel,
    sender_user_id,
    recipient_user_id,
    guild_id,
    sender_name,
    content,
    metadata
  ) VALUES (
    p_channel,
    v_user.id,
    p_recipient_user_id,
    CASE WHEN p_channel = 'guild' THEN v_user.guild_id ELSE NULL END,
    v_sender_name,
    v_filtered,
    jsonb_build_object('original_length', char_length(v_clean))
  )
  RETURNING id INTO v_message_id;

  PERFORM public.write_chat_audit(v_user.id, 'message_sent', NULL, v_message_id, jsonb_build_object('channel', p_channel));

  RETURN jsonb_build_object('success', true, 'message_id', v_message_id, 'content', v_filtered);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.send_chat_message(TEXT, TEXT, UUID) TO authenticated;


DROP FUNCTION IF EXISTS public.get_dm_messages(UUID, INTEGER);
CREATE OR REPLACE FUNCTION public.get_dm_messages(
  p_peer_user_id UUID,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  channel TEXT,
  sender_id UUID,
  sender_name TEXT,
  content TEXT,
  "timestamp" TIMESTAMPTZ,
  is_system BOOLEAN,
  recipient_user_id UUID,
  guild_id UUID
) AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_peer_user_id IS NULL OR p_peer_user_id = v_user.id THEN
    RAISE EXCEPTION 'Gecersiz hedef kullanici';
  END IF;

  RETURN QUERY
  SELECT
    cm.id,
    cm.channel,
    cm.sender_user_id,
    cm.sender_name,
    cm.content,
    cm.created_at,
    cm.is_system,
    cm.recipient_user_id,
    cm.guild_id
  FROM public.chat_messages cm
  WHERE cm.deleted_at IS NULL
    AND cm.channel = 'dm'
    AND (
      (cm.sender_user_id = v_user.id AND cm.recipient_user_id = p_peer_user_id)
      OR (cm.sender_user_id = p_peer_user_id AND cm.recipient_user_id = v_user.id)
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE cb.blocker_user_id = v_user.id
        AND cb.blocked_user_id = cm.sender_user_id
    )
  ORDER BY cm.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_dm_messages(UUID, INTEGER) TO authenticated;


DROP FUNCTION IF EXISTS public.get_dm_conversations();
CREATE OR REPLACE FUNCTION public.get_dm_conversations()
RETURNS TABLE (
  peer_user_id UUID,
  peer_username TEXT,
  peer_display_name TEXT,
  last_message_id UUID,
  last_message_content TEXT,
  last_message_at TIMESTAMPTZ,
  unread_count BIGINT,
  last_sender_id UUID
) AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  RETURN QUERY
  WITH dm_rows AS (
    SELECT
      CASE
        WHEN cm.sender_user_id = v_user.id THEN cm.recipient_user_id
        ELSE cm.sender_user_id
      END AS peer_id,
      cm.id,
      cm.content,
      cm.created_at,
      cm.sender_user_id,
      cm.recipient_user_id,
      cm.read_at,
      row_number() OVER (
        PARTITION BY CASE
          WHEN cm.sender_user_id = v_user.id THEN cm.recipient_user_id
          ELSE cm.sender_user_id
        END
        ORDER BY cm.created_at DESC
      ) AS row_num
    FROM public.chat_messages cm
    WHERE cm.deleted_at IS NULL
      AND cm.channel = 'dm'
      AND (cm.sender_user_id = v_user.id OR cm.recipient_user_id = v_user.id)
      AND NOT EXISTS (
        SELECT 1 FROM public.chat_blocks cb
        WHERE cb.blocker_user_id = v_user.id
          AND cb.blocked_user_id = CASE
            WHEN cm.sender_user_id = v_user.id THEN cm.recipient_user_id
            ELSE cm.sender_user_id
          END
      )
  ), unread_totals AS (
    SELECT
      cm.sender_user_id AS peer_id,
      count(*) AS unread_count
    FROM public.chat_messages cm
    WHERE cm.deleted_at IS NULL
      AND cm.channel = 'dm'
      AND cm.recipient_user_id = v_user.id
      AND cm.read_at IS NULL
    GROUP BY cm.sender_user_id
  )
  SELECT
    peer.id,
    peer.username,
    peer.display_name,
    dm.id,
    dm.content,
    dm.created_at,
    COALESCE(unread_totals.unread_count, 0),
    dm.sender_user_id
  FROM dm_rows dm
  JOIN public.users peer ON peer.id = dm.peer_id
  LEFT JOIN unread_totals ON unread_totals.peer_id = dm.peer_id
  WHERE dm.row_num = 1
  ORDER BY dm.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_dm_conversations() TO authenticated;


DROP FUNCTION IF EXISTS public.search_chat_users(TEXT, INTEGER);
CREATE OR REPLACE FUNCTION public.search_chat_users(
  p_query TEXT,
  p_limit INTEGER DEFAULT 8
)
RETURNS TABLE (
  id UUID,
  username TEXT,
  display_name TEXT
) AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_query TEXT;
BEGIN
  v_user := public.get_current_chat_user();
  v_query := lower(btrim(COALESCE(p_query, '')));

  IF char_length(v_query) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.username,
    u.display_name
  FROM public.users u
  WHERE u.id <> v_user.id
    AND (
      lower(u.username) LIKE v_query || '%'
      OR lower(COALESCE(u.display_name, '')) LIKE '%' || v_query || '%'
    )
  ORDER BY
    CASE WHEN lower(u.username) = v_query THEN 0 ELSE 1 END,
    CASE WHEN lower(u.username) LIKE v_query || '%' THEN 0 ELSE 1 END,
    u.username ASC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 8), 1), 20);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.search_chat_users(TEXT, INTEGER) TO authenticated;


DROP FUNCTION IF EXISTS public.mark_dm_conversation_read(UUID);
CREATE OR REPLACE FUNCTION public.mark_dm_conversation_read(p_peer_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_updated_count INTEGER := 0;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_peer_user_id IS NULL OR p_peer_user_id = v_user.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz hedef kullanici');
  END IF;

  UPDATE public.chat_messages
  SET read_at = now()
  WHERE channel = 'dm'
    AND deleted_at IS NULL
    AND sender_user_id = p_peer_user_id
    AND recipient_user_id = v_user.id
    AND read_at IS NULL;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  RETURN jsonb_build_object('success', true, 'updated_count', v_updated_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.mark_dm_conversation_read(UUID) TO authenticated;


DROP FUNCTION IF EXISTS public.block_chat_user(UUID);
CREATE OR REPLACE FUNCTION public.block_chat_user(p_blocked_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_blocked_user_id IS NULL OR p_blocked_user_id = v_user.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz kullanici');
  END IF;

  INSERT INTO public.chat_blocks (blocker_user_id, blocked_user_id)
  VALUES (v_user.id, p_blocked_user_id)
  ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;

  PERFORM public.write_chat_audit(v_user.id, 'user_blocked', p_blocked_user_id, NULL, '{}'::jsonb);

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.block_chat_user(UUID) TO authenticated;


DROP FUNCTION IF EXISTS public.report_chat_message(UUID, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.report_chat_message(
  p_message_id UUID,
  p_reason TEXT,
  p_details TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_message_id IS NULL OR public.normalize_chat_content(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz rapor');
  END IF;

  INSERT INTO public.chat_reports (message_id, reporter_user_id, reason, details)
  VALUES (p_message_id, v_user.id, left(public.normalize_chat_content(p_reason), 120), left(public.normalize_chat_content(COALESCE(p_details, '')), 400))
  ON CONFLICT (message_id, reporter_user_id)
  DO UPDATE SET reason = EXCLUDED.reason, details = EXCLUDED.details, created_at = now();

  PERFORM public.write_chat_audit(v_user.id, 'message_reported', NULL, p_message_id, jsonb_build_object('reason', p_reason));

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.report_chat_message(UUID, TEXT, TEXT) TO authenticated;


DROP FUNCTION IF EXISTS public.delete_chat_message(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.delete_chat_message(
  p_message_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_actor public.users%ROWTYPE;
  v_message RECORD;
BEGIN
  v_actor := public.get_current_chat_user();

  SELECT id, channel, guild_id, sender_user_id, deleted_at
  INTO v_message
  FROM public.chat_messages
  WHERE id = p_message_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj bulunamadi');
  END IF;

  IF v_message.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj zaten silinmis');
  END IF;

  IF NOT public.has_chat_permission(v_actor.id, 'delete', v_message.channel, v_message.guild_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu mesaji silme yetkiniz yok');
  END IF;

  UPDATE public.chat_messages
  SET deleted_at = now(),
      deleted_by_user_id = v_actor.id,
      deleted_reason = left(public.normalize_chat_content(COALESCE(p_reason, '')), 200)
  WHERE id = p_message_id;

  PERFORM public.write_chat_audit(v_actor.id, 'message_deleted', v_message.sender_user_id, p_message_id, jsonb_build_object('reason', p_reason));

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.delete_chat_message(UUID, TEXT) TO authenticated;


DROP FUNCTION IF EXISTS public.ban_chat_user(UUID, TEXT, INTEGER, TEXT);
CREATE OR REPLACE FUNCTION public.ban_chat_user(
  p_target_user_id UUID,
  p_channel TEXT,
  p_duration_minutes INTEGER,
  p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_actor public.users%ROWTYPE;
  v_target RECORD;
  v_scope TEXT;
  v_guild_id UUID;
  v_ban_id UUID;
BEGIN
  v_actor := public.get_current_chat_user();

  IF p_target_user_id IS NULL OR p_target_user_id = v_actor.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz hedef');
  END IF;

  IF p_channel NOT IN ('global', 'guild', 'dm', 'trade') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz kanal');
  END IF;

  IF p_duration_minutes IS NULL OR p_duration_minutes < 1 OR p_duration_minutes > 10080 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ban suresi 1 ile 10080 dakika arasinda olmali');
  END IF;

  SELECT id, guild_id INTO v_target FROM public.users WHERE id = p_target_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef oyuncu bulunamadi');
  END IF;

  v_scope := CASE WHEN p_channel = 'guild' THEN 'guild' ELSE 'channel' END;
  v_guild_id := CASE WHEN p_channel = 'guild' THEN v_actor.guild_id ELSE NULL END;

  IF p_channel = 'guild' AND (v_actor.guild_id IS NULL OR v_actor.guild_id <> v_target.guild_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca moderasyonu sadece ayni loncadaki oyuncular icin kullanilabilir');
  END IF;

  IF NOT public.has_chat_permission(v_actor.id, 'ban', p_channel, v_guild_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu kanalda ban yetkiniz yok');
  END IF;

  INSERT INTO public.chat_bans (user_id, scope, channel, guild_id, reason, expires_at, created_by_user_id)
  VALUES (
    p_target_user_id,
    v_scope,
    CASE WHEN v_scope = 'channel' THEN p_channel ELSE 'guild' END,
    CASE WHEN v_scope = 'guild' THEN v_guild_id ELSE NULL END,
    left(public.normalize_chat_content(p_reason), 200),
    now() + make_interval(mins => p_duration_minutes),
    v_actor.id
  )
  RETURNING id INTO v_ban_id;

  PERFORM public.write_chat_audit(
    v_actor.id,
    'user_banned',
    p_target_user_id,
    NULL,
    jsonb_build_object('channel', p_channel, 'duration_minutes', p_duration_minutes, 'ban_id', v_ban_id)
  );

  RETURN jsonb_build_object('success', true, 'ban_id', v_ban_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.ban_chat_user(UUID, TEXT, INTEGER, TEXT) TO authenticated;


DROP FUNCTION IF EXISTS public.create_chat_filter(TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.create_chat_filter(
  p_term TEXT,
  p_replacement TEXT,
  p_channel TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_actor public.users%ROWTYPE;
  v_scope TEXT;
  v_guild_id UUID;
  v_filter_id UUID;
  v_term TEXT;
  v_replacement TEXT;
BEGIN
  v_actor := public.get_current_chat_user();
  v_term := left(public.normalize_chat_content(p_term), 64);
  v_replacement := left(public.normalize_chat_content(p_replacement), 32);

  IF v_term = '' OR v_replacement = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Filtre terimi ve yerine gececek ifade gerekli');
  END IF;

  IF p_channel NOT IN ('global', 'guild', 'dm', 'trade') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz kanal');
  END IF;

  v_scope := CASE WHEN p_channel = 'guild' THEN 'guild' ELSE 'channel' END;
  v_guild_id := CASE WHEN p_channel = 'guild' THEN v_actor.guild_id ELSE NULL END;

  IF NOT public.has_chat_permission(v_actor.id, 'manage_filters', p_channel, v_guild_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Filtre yonetme yetkiniz yok');
  END IF;

  INSERT INTO public.chat_filters (scope, channel, guild_id, term, replacement, created_by_user_id)
  VALUES (
    v_scope,
    CASE WHEN v_scope = 'channel' THEN p_channel ELSE 'guild' END,
    CASE WHEN v_scope = 'guild' THEN v_guild_id ELSE NULL END,
    v_term,
    v_replacement,
    v_actor.id
  )
  RETURNING id INTO v_filter_id;

  PERFORM public.write_chat_audit(v_actor.id, 'filter_created', NULL, NULL, jsonb_build_object('filter_id', v_filter_id, 'channel', p_channel, 'term', v_term));

  RETURN jsonb_build_object('success', true, 'filter_id', v_filter_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.create_chat_filter(TEXT, TEXT, TEXT) TO authenticated;


DROP FUNCTION IF EXISTS public.delete_chat_filter(UUID);
CREATE OR REPLACE FUNCTION public.delete_chat_filter(p_filter_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actor public.users%ROWTYPE;
  v_filter RECORD;
BEGIN
  v_actor := public.get_current_chat_user();

  SELECT id, channel, guild_id INTO v_filter
  FROM public.chat_filters
  WHERE id = p_filter_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Filtre bulunamadi');
  END IF;

  IF NOT public.has_chat_permission(v_actor.id, 'manage_filters', v_filter.channel, v_filter.guild_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu filtreyi silme yetkiniz yok');
  END IF;

  DELETE FROM public.chat_filters WHERE id = p_filter_id;

  PERFORM public.write_chat_audit(v_actor.id, 'filter_deleted', NULL, NULL, jsonb_build_object('filter_id', p_filter_id));

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.delete_chat_filter(UUID) TO authenticated;


DROP FUNCTION IF EXISTS public.assign_chat_moderator(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.assign_chat_moderator(
  p_target_user_id UUID,
  p_channel TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_actor public.users%ROWTYPE;
  v_target RECORD;
  v_scope TEXT;
  v_guild_id UUID;
  v_assignment_id UUID;
BEGIN
  v_actor := public.get_current_chat_user();

  IF p_target_user_id IS NULL OR p_target_user_id = v_actor.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz hedef');
  END IF;

  IF p_channel NOT IN ('global', 'guild', 'dm', 'trade') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz kanal');
  END IF;

  SELECT id, guild_id INTO v_target FROM public.users WHERE id = p_target_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef oyuncu bulunamadi');
  END IF;

  v_scope := CASE WHEN p_channel = 'guild' THEN 'guild' ELSE 'channel' END;
  v_guild_id := CASE WHEN p_channel = 'guild' THEN v_actor.guild_id ELSE NULL END;

  IF NOT public.has_chat_permission(v_actor.id, 'manage_moderators', p_channel, v_guild_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Moderator atama yetkiniz yok');
  END IF;

  IF p_channel = 'guild' AND (v_target.guild_id IS NULL OR v_target.guild_id <> v_actor.guild_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca moderatorlugu sadece ayni loncadaki oyuncuya verilebilir');
  END IF;

  INSERT INTO public.chat_moderators (
    user_id,
    scope,
    channel,
    guild_id,
    can_delete,
    can_ban,
    can_manage_filters,
    can_manage_moderators,
    assigned_by_user_id
  )
  SELECT
    p_target_user_id,
    v_scope,
    CASE WHEN v_scope = 'channel' THEN p_channel ELSE 'guild' END,
    CASE WHEN v_scope = 'guild' THEN v_guild_id ELSE NULL END,
    true,
    true,
    false,
    false,
    v_actor.id
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.chat_moderators cm
    WHERE cm.user_id = p_target_user_id
      AND cm.scope = v_scope
      AND COALESCE(cm.channel, '') = COALESCE(CASE WHEN v_scope = 'channel' THEN p_channel ELSE 'guild' END, '')
      AND COALESCE(cm.guild_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE(CASE WHEN v_scope = 'guild' THEN v_guild_id ELSE NULL END, '00000000-0000-0000-0000-000000000000'::uuid)
      AND cm.revoked_at IS NULL
  )
  RETURNING id INTO v_assignment_id;

  IF v_assignment_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu kullanici zaten moderator');
  END IF;

  PERFORM public.write_chat_audit(v_actor.id, 'moderator_assigned', p_target_user_id, NULL, jsonb_build_object('channel', p_channel, 'assignment_id', v_assignment_id));

  RETURN jsonb_build_object('success', true, 'assignment_id', v_assignment_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.assign_chat_moderator(UUID, TEXT) TO authenticated;


DROP FUNCTION IF EXISTS public.get_chat_moderation_state(TEXT);
CREATE OR REPLACE FUNCTION public.get_chat_moderation_state(p_channel TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_filters JSONB;
  v_bans JSONB;
BEGIN
  v_user := public.get_current_chat_user();

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', cf.id,
    'term', cf.term,
    'replacement', cf.replacement,
    'channel', cf.channel,
    'scope', cf.scope,
    'guild_id', cf.guild_id,
    'created_at', cf.created_at
  ) ORDER BY cf.created_at DESC), '[]'::jsonb)
  INTO v_filters
  FROM public.chat_filters cf
  WHERE cf.is_active = true
    AND (
      (p_channel = 'guild' AND cf.scope = 'guild' AND cf.guild_id = v_user.guild_id)
      OR (cf.scope = 'channel' AND cf.channel = p_channel)
      OR (cf.scope = 'global')
    );

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', cb.id,
    'channel', cb.channel,
    'scope', cb.scope,
    'reason', cb.reason,
    'expires_at', cb.expires_at
  ) ORDER BY cb.expires_at DESC), '[]'::jsonb)
  INTO v_bans
  FROM public.chat_bans cb
  WHERE cb.user_id = v_user.id
    AND cb.revoked_at IS NULL
    AND cb.expires_at > now();

  RETURN jsonb_build_object(
    'success', true,
    'channel', p_channel,
    'filters', v_filters,
    'active_bans', v_bans,
    'permissions', jsonb_build_object(
      'can_delete', public.has_chat_permission(v_user.id, 'delete', p_channel, v_user.guild_id),
      'can_ban', public.has_chat_permission(v_user.id, 'ban', p_channel, v_user.guild_id),
      'can_manage_filters', public.has_chat_permission(v_user.id, 'manage_filters', p_channel, v_user.guild_id),
      'can_manage_moderators', public.has_chat_permission(v_user.id, 'manage_moderators', p_channel, v_user.guild_id)
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_chat_moderation_state(TEXT) TO authenticated;


-- ── RLS ────────────────────────────────────────────────────

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_bans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_filters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_moderators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_messages_select_visible" ON public.chat_messages;
CREATE POLICY "chat_messages_select_visible"
  ON public.chat_messages FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      channel IN ('global', 'trade', 'system')
      OR (
        channel = 'guild'
        AND guild_id = (SELECT guild_id FROM public.users WHERE auth_id = auth.uid())
      )
      OR (
        channel = 'dm'
        AND (
          sender_user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
          OR recipient_user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
        )
      )
    )
  );

DROP POLICY IF EXISTS "chat_reports_select_own" ON public.chat_reports;
CREATE POLICY "chat_reports_select_own"
  ON public.chat_reports FOR SELECT
  TO authenticated
  USING (reporter_user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

DROP POLICY IF EXISTS "chat_blocks_select_own" ON public.chat_blocks;
CREATE POLICY "chat_blocks_select_own"
  ON public.chat_blocks FOR SELECT
  TO authenticated
  USING (blocker_user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));

DROP POLICY IF EXISTS "chat_bans_select_own_or_mod" ON public.chat_bans;
CREATE POLICY "chat_bans_select_own_or_mod"
  ON public.chat_bans FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
    OR public.has_chat_permission(
      (SELECT id FROM public.users WHERE auth_id = auth.uid()),
      'ban',
      COALESCE(channel, 'guild'),
      guild_id
    )
  );

DROP POLICY IF EXISTS "chat_filters_select_visible" ON public.chat_filters;
CREATE POLICY "chat_filters_select_visible"
  ON public.chat_filters FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND (
      scope = 'global'
      OR (scope = 'channel')
      OR (
        scope = 'guild'
        AND guild_id = (SELECT guild_id FROM public.users WHERE auth_id = auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS "chat_moderators_select_self_or_guild" ON public.chat_moderators;
CREATE POLICY "chat_moderators_select_self_or_guild"
  ON public.chat_moderators FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
    OR (
      scope = 'guild'
      AND guild_id = (SELECT guild_id FROM public.users WHERE auth_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "chat_audit_log_select_none" ON public.chat_audit_log;
CREATE POLICY "chat_audit_log_select_none"
  ON public.chat_audit_log FOR SELECT
  TO authenticated
  USING (false);