revoke all on ret_admin.scenes from ret_admin;
revoke all on ret_admin.accounts from ret_admin;
revoke all on ret_admin.owned_files from ret_admin;
revoke all on ret_admin.hubs_metrics from ret_admin;

grant select, insert, update on ret_admin.scenes to ret_admin;
grant select, insert, update on ret_admin.accounts to ret_admin;
grant select, insert, update on ret_admin.owned_files to ret_admin;
grant select on ret_admin.hubs_metrics to ret_admin;
