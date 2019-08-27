set search_path=ret0;

select create_or_replace_admin_view('projects');
grant select, insert, update on ret0_admin.projects to ret_admin;
