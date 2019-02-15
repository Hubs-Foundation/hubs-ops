select create_or_replace_admin_view('scenes');

grant select, insert, update on ret0_admin.scenes to ret_admin;
select create_or_replace_admin_view('scene_listings');
grant select, insert, update on ret0_admin.scene_listings to ret_admin;

create or replace view pending_scenes as (
				select scenes.id, scene_sid, scenes.slug, scenes.name, scenes.description, scenes.screenshot_owned_file_id, scenes.model_owned_file_id, scenes.scene_owned_file_id, 
				scenes.attributions, scene_listings.id as scene_listing_id, scenes.updated_at, scenes.allow_remixing as _allow_remixing, scenes.allow_promotion as _allow_promotion
				from scenes
				left outer join scene_listings on scene_listings.scene_id = scenes.id
				where ((scenes.reviewed_at is null or scenes.reviewed_at < scenes.updated_at) and scenes.allow_promotion and scenes.state = 'active')
);

grant select on ret0_admin.pending_scenes to ret_admin;

create or replace view featured_scene_listings as (
				select id, scene_listing_sid, slug, name, description, screenshot_owned_file_id, model_owned_file_id, scene_owned_file_id, attributions, scene_listings.order, tags
				from scene_listings
				where 
				state = 'active' and
				tags->'tags' ? 'featured' and
				exists (select id from scenes s where s.id = scene_listings.scene_id and s.state = 'active' and s.allow_promotion)
);

grant select, update on ret0_admin.featured_scene_listings to ret_admin;
