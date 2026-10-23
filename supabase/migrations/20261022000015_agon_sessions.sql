-- Express sessions must persist across Vercel's independent serverless instances.
create table if not exists public.agon_sessions (
  session_id text primary key,
  session_data jsonb not null,
  expires_at timestamptz not null
);

create index if not exists agon_sessions_expires_at_idx
  on public.agon_sessions (expires_at);

alter table public.agon_sessions enable row level security;
revoke all on public.agon_sessions from anon, authenticated;
grant all on public.agon_sessions to service_role;
