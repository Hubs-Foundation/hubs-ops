create schema ret0_dw;
create role ret_dw noinherit login;

grant usage on schema ret0_dw to ret_dw;
grant usage on schema ret0 to ret_dw;
