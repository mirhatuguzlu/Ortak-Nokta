-- Ortak Nokta davet grupları. Supabase > SQL Editor'de bir kez çalıştır.
--
-- Güvenlik modeli: tablolara anon erişim YOK (RLS açık, politika yok, yetkiler
-- geri alınmış). Uygulama yalnızca aşağıdaki üç fonksiyonu çağırabilir ve her biri
-- grup kimliğini (tahmin edilemez UUID) ister. Böylece kimse tüm konumları
-- listeleyemez. Gruplar ve konumlar 24 saat sonra erişilemez olur ve silinir.

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 30),
  mode text not null check (mode in ('walk', 'car')),
  lat double precision not null check (lat between -90 and 90),
  lon double precision not null check (lon between -180 and 180),
  label text not null check (char_length(label) <= 120),
  created_at timestamptz not null default now()
);
create index if not exists members_group_idx on public.members(group_id);

alter table public.groups enable row level security;
alter table public.members enable row level security;
revoke all on public.groups, public.members from anon, authenticated;

create or replace function public.create_group()
returns uuid language sql security definer set search_path = public as $$
  insert into groups default values returning id;
$$;

create or replace function public.join_group(
  gid uuid, p_name text, p_mode text, p_lat double precision, p_lon double precision, p_label text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_id uuid;
begin
  -- Aynı gruba eşzamanlı katılımlarda 5 kişi sınırı aşılmasın.
  perform 1 from groups where id = gid and created_at > now() - interval '24 hours' for update;
  if not found then raise exception 'group_not_found'; end if;
  if (select count(*) from members where group_id = gid) >= 5 then raise exception 'group_full'; end if;
  begin
    insert into members (group_id, name, mode, lat, lon, label)
    values (gid, btrim(p_name), p_mode, p_lat, p_lon, coalesce(p_label, ''))
    returning id into new_id;
  exception when check_violation or not_null_violation then
    raise exception 'invalid_member';
  end;
  return new_id;
end;
$$;

create or replace function public.group_members(gid uuid)
returns table (id uuid, name text, mode text, lat double precision, lon double precision, label text)
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from groups g where g.id = gid and g.created_at > now() - interval '24 hours') then
    raise exception 'group_not_found';
  end if;
  return query
    select m.id, m.name, m.mode, m.lat, m.lon, m.label
    from members m where m.group_id = gid order by m.created_at;
end;
$$;

revoke execute on function public.create_group(), public.join_group(uuid, text, text, double precision, double precision, text),
  public.group_members(uuid) from public;
grant execute on function public.create_group(), public.join_group(uuid, text, text, double precision, double precision, text),
  public.group_members(uuid) to anon;

-- Süresi dolan grupları saatte bir sil (Database > Extensions'tan pg_cron'u aç).
-- create extension if not exists pg_cron;
-- select cron.schedule('ortaknokta-cleanup', '0 * * * *',
--   $$delete from public.groups where created_at < now() - interval '24 hours'$$);
