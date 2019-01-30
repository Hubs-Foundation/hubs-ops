create schema ret0_admin;
create role postgrest_authenticator noinherit login;

create role postgrest_anonymous;
create role ret_admin;

grant postgrest_anonymous to postgrest_authenticator;
grant ret_admin to postgrest_authenticator;

grant usage on schema ret0_admin to ret_admin;
