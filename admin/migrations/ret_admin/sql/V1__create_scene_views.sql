create or replace function create_or_replace_admin_view(name text)
returns void as
$$
declare
pk character varying(255);
begin

-- Get the primary key
SELECT
  pg_attribute.attname into pk
FROM pg_index, pg_class, pg_attribute, pg_namespace
WHERE
  pg_class.oid = ('ret0.' || name)::regclass AND
  indrelid = pg_class.oid AND
  nspname = 'ret0' AND
  pg_class.relnamespace = pg_namespace.oid AND
  pg_attribute.attrelid = pg_class.oid AND
  pg_attribute.attnum = any(pg_index.indkey)
 AND indisprimary;

-- Create a view with the primary key renamed to id 
execute 'create or replace view ' || name || ' as (select ' || pk || ' as id, '
|| array_to_string(ARRAY(SELECT 'o' || '.' || c.column_name
        FROM information_schema.columns As c
            WHERE table_name = name AND table_schema = 'ret0'
            AND  c.column_name NOT IN(pk)
    ), ',') ||
				' from ret0.' || name || ' as o)';

execute 'grant all privileges on all tables in schema ret0_admin to ret_admin';

end


$$ language plpgsql;

select create_or_replace_admin_view('scenes');
select create_or_replace_admin_view('accounts');
select create_or_replace_admin_view('owned_files');
