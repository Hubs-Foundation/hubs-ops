set search_path=ret0;

create or replace view ret0_dw.accounts as (
  (
    select ret0_dw.sha1(accounts.account_id) as account_id, inserted_at, updated_at, is_admin from accounts
  )
);
