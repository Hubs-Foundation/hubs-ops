set search_path=ret0;

create or replace view ret0_dw.account_favorites as (
  (
    select ret0_dw.sha1(account_favorites.account_favorite_id) as account_favorite_id, ret0_dw.sha1(account_favorites.account_id) as account_id, ret0_dw.sha1(account_favorites.hub_id) as hub_id, inserted_at, updated_at from account_favorites
  )
);

create or replace view ret0_dw.hubs as (
  (
    select ret0_dw.sha1(hubs.hub_sid) as hub_id, hubs.inserted_at, hubs.updated_at, hubs.max_occupant_count,
    hubs.spawned_object_types, ret0_dw.sha1(scenes.scene_sid) as scene_id, ret0_dw.sha1(hubs.created_by_account_id) as created_by_account_id,
    hubs.last_active_at, hubs.embedded from hubs left outer join scenes on hubs.scene_id = scenes.scene_id
  )
);

