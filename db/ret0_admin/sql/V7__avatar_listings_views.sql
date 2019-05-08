select create_or_replace_admin_view('avatars');
grant select, insert, update on ret0_admin.avatars to ret_admin;

select create_or_replace_admin_view('avatar_listings');
grant select, insert, update on ret0_admin.avatar_listings to ret_admin;

create or replace view pending_avatars as (
       select avatars.id, avatar_sid, avatars.slug, avatars.name, avatars.description, avatars.thumbnail_owned_file_id,
       avatars.base_map_owned_file_id, avatars.emissive_map_owned_file_id, avatars.normal_map_owned_file_id, avatars.orm_map_owned_file_id,
       avatars.attributions, avatar_listings.id as avatar_listing_id, avatars.updated_at, avatars.allow_remixing as allow_remixing, avatars.allow_promotion as allow_promotion
       from avatars
       left outer join avatar_listings on avatar_listings.avatar_id = avatars.id
       where ((avatars.reviewed_at is null or avatars.reviewed_at < avatars.updated_at) and avatars.allow_promotion and avatars.state = 'active')
);
grant select on ret0_admin.pending_avatars to ret_admin;


create or replace view featured_avatar_listings as (
       select id, avatar_listing_sid, slug, name, description, thumbnail_owned_file_id,
       base_map_owned_file_id, emissive_map_owned_file_id, normal_map_owned_file_id, orm_map_owned_file_id,
       attributions, avatar_listings.order, updated_at, tags
       from avatar_listings
       where
       state = 'active' and
       tags->'tags' ? 'featured' and
       exists (select id from avatars s where s.id = avatar_listings.avatar_id and s.state = 'active' and s.allow_promotion)
);
grant select, update on ret0_admin.featured_avatar_listings to ret_admin;
