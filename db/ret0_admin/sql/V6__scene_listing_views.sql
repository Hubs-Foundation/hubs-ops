drop view ret0_admin.scene_listings;
select create_or_replace_admin_view('scene_listings');
grant select, insert, update on ret0_admin.scene_listings to ret_admin;

create or replace view pending_scenes as (
				select scenes.id, scene_sid, scenes.slug, scenes.name, scenes.description, scenes.screenshot_owned_file_id, scenes.model_owned_file_id, scene.scene_owned_file_id, 
				scenes.attributions, scene_listings.id as scene_listing_id, scenes.updated_at 
				from scenes
				left outer join scene_listings on scene_listings.scene_id = scenes.id
				where ((scenes.reviewed_at is null or scenes.reviewed_at < scenes.updated_at) and scenes.allow_promotion and scenes.state = 'active')
);

grant select on ret0_admin.pending_scenes to ret_admin;
