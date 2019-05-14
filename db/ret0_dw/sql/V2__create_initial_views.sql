set search_path=ret0;

CREATE EXTENSION IF NOT EXISTS pgcrypto schema ret0_dw; 

CREATE OR REPLACE FUNCTION ret0_dw.sha1(bytea) returns text AS $$
  SELECT encode(ret0_dw.digest($1, 'sha1'), 'hex')
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ret0_dw.sha1(varchar) returns text AS $$
  SELECT encode(ret0_dw.digest($1::bytea, 'sha1'), 'hex')
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION ret0_dw.sha1(bigint) returns text AS $$
  SELECT encode(ret0_dw.digest(int8send($1), 'sha1'), 'hex')
$$ LANGUAGE SQL STRICT IMMUTABLE;

create or replace view ret0_dw.hubs as (
  (
    select ret0_dw.sha1(hubs.hub_sid) as hub_id, hubs.inserted_at, hubs.updated_at, hubs.max_occupant_count,
    hubs.spawned_object_types, ret0_dw.sha1(scenes.scene_sid) as scene_id, ret0_dw.sha1(hubs.created_by_account_id) as created_by_account_id,
    hubs.last_active_at from hubs left outer join scenes on hubs.scene_id = scenes.scene_id
  )
);

create or replace view ret0_dw.accounts as (
  (
    select ret0_dw.sha1(accounts.account_id) as account_id, inserted_at, updated_at from accounts
  )
);

create or replace view ret0_dw.avatars as (
  (
    select ret0_dw.sha1(a.avatar_sid) as avatar_id, a.inserted_at, a.updated_at, ret0_dw.sha1(b.avatar_sid) as parent_avatar_id, a.allow_remixing, a.allow_promotion, a.state::text as state
    from avatars a left outer join avatars b on a.parent_avatar_id = b.avatar_id
  )
);

create or replace view ret0_dw.hub_bindings as (
  (
    select ret0_dw.sha1(hub_binding_id) as hub_binding_id, hub_bindings.inserted_at, hub_bindings.updated_at, ret0_dw.sha1(hubs.hub_sid) as hub_id,
    type::text as type, ret0_dw.sha1(community_id) as community_id, ret0_dw.sha1(channel_id) as channel_id
    from hub_bindings inner join hubs on hub_bindings.hub_id = hubs.hub_id
  )
);

create or replace view ret0_dw.node_stats as (
  (
    select ret0_dw.sha1(node_id) as node_id, measured_at, present_sessions, present_rooms from node_stats
  )
);

create or replace view ret0_dw.projects as (
  (
    select ret0_dw.sha1(project_sid) as project_id, ret0_dw.sha1(created_by_account_id) as created_by_account_id, inserted_at, updated_at from projects
  )
);

create or replace view ret0_dw.room_objects as (
  (
    select ret0_dw.sha1(room_object_id) as room_object_id, ret0_dw.sha1(hubs.hub_sid) as hub_id, ret0_dw.sha1(account_id) as account_id, room_objects.inserted_at, room_objects.updated_at
    from room_objects inner join hubs on hubs.hub_id = room_objects.hub_id
  )
);

create or replace view ret0_dw.scenes as (
  (
    select ret0_dw.sha1(scene_sid) as scene_id, state::text as state, ret0_dw.sha1(account_id) as account_id, inserted_at, updated_at, allow_remixing, allow_promotion from scenes
  )
);

create or replace view ret0_dw.session_stats as (
  (
    select ret0_dw.sha1(session_id::text) as session_id, started_at, ended_at, entered_event_received_at,
    ((entered_event_payload->>'isNewDaily')::varchar)::boolean as is_new_daily, 
    ((entered_event_payload->>'isNewMonthly')::varchar)::boolean as is_new_monthly, 
    ((entered_event_payload->>'isNewDayWindow')::varchar)::boolean as is_new_day_window, 
    ((entered_event_payload->>'isNewMonthWindow')::varchar)::boolean as is_new_month_window, 
    (entered_event_payload->>'entryDisplayType')::varchar as entry_display_type, 
    (entered_event_payload->>'initialOccupantCount')::integer as initial_occupant_count, 
    (entered_event_payload->>'userAgent')::varchar as user_agen
    from session_stats
  )
);

create or replace view ret0_dw.web_push_subscriptions as (
  (
    select ret0_dw.sha1(web_push_subscription_id) as web_push_subscription_id, ret0_dw.sha1(hubs.hub_sid) as hub_id,
    web_push_subscriptions.inserted_at, web_push_subscriptions.updated_at, web_push_subscriptions.last_notified_at
    from web_push_subscriptions inner join hubs on hubs.hub_id = web_push_subscriptions.hub_id
  )
);


grant select on all tables in schema ret0_dw to ret_dw;
