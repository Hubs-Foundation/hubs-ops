do 
$$ 
begin
  execute format('grant connect on database %I to postgrest_authenticator', current_database());
end;
$$;
