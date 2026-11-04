-- Ortak Nokta: hesaplar, davet grupları ve ortak buluşma defteri.
-- Supabase > SQL Editor'de çalıştır. Tekrar çalıştırmak güvenlidir (eski kurulumu da yükseltir).
--
-- Güvenlik modeli: tablolara doğrudan erişim YOK (RLS açık, politika yok, yetkiler geri
-- alınmış). Uygulama ve site yalnızca aşağıdaki fonksiyonları, Google ile giriş yapmış
-- kullanıcı olarak (authenticated rolü) çağırabilir. Her fonksiyon auth.uid() ile kimin
-- çağırdığını bilir; grup verisini yalnızca gruptaki kişiler değiştirebilir.
-- E-posta adresleri yalnızca aynı grupta aynı isimde iki kişi varsa, ayırt etmek için
-- o grubun üyelerine gösterilir. Gruplar 7 gün sonra erişilemez olur ve silinir.

-- ---------- Profiller ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 30),
  updated_at timestamptz not null default now()
);

-- ---------- Gruplar ve üyeler ----------
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);
alter table public.groups add column if not exists owner uuid references auth.users(id) on delete set null;
alter table public.groups add column if not exists spot text not null default '' check (char_length(spot) <= 80);

create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  name text,
  mode text not null check (mode in ('walk', 'car')),
  lat double precision not null check (lat between -90 and 90),
  lon double precision not null check (lon between -180 and 180),
  label text not null check (char_length(label) <= 120),
  created_at timestamptz not null default now()
);
-- Eski (hesapsız) kurulumdan yükseltme: isim artık profilden gelir.
alter table public.members alter column name drop not null;
alter table public.members drop constraint if exists members_name_check;
alter table public.members add column if not exists user_id uuid references auth.users(id) on delete cascade;
create index if not exists members_group_idx on public.members(group_id);
create unique index if not exists members_group_user_idx on public.members(group_id, user_id);

-- ---------- Ortak buluşma defteri ----------
-- who/payer/for_whom kullanıcı kimlikleridir; eklenirken gruptaki biri oldukları denetlenir.
-- Hesabını silen birinin masrafı kaybolmasın diye bunlar yabancı anahtar değildir.
create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  who uuid,
  done boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists items_group_idx on public.items(group_id);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  what text not null check (char_length(btrim(what)) between 1 and 40),
  payer uuid not null,
  kurus integer not null check (kurus between 1 and 100000000),
  for_whom uuid[] not null check (cardinality(for_whom) between 1 and 5),
  created_at timestamptz not null default now()
);
create index if not exists expenses_group_idx on public.expenses(group_id);

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.members enable row level security;
alter table public.items enable row level security;
alter table public.expenses enable row level security;
revoke all on public.profiles, public.groups, public.members, public.items, public.expenses from anon, authenticated;

-- ---------- Yardımcılar (dışarı açık değil) ----------
create or replace function public._uid() returns uuid language plpgsql stable as $$
begin
  if auth.uid() is null then raise exception 'auth_required'; end if;
  return auth.uid();
end;
$$;

create or replace function public._active(gid uuid) returns boolean language sql stable security definer
set search_path = public as $$
  select exists (select 1 from groups where id = gid and created_at > now() - interval '7 days');
$$;

create or replace function public._is_member(gid uuid, uid uuid) returns boolean language sql stable security definer
set search_path = public as $$
  select exists (select 1 from members where group_id = gid and user_id = uid);
$$;

-- Çağıran bu aktif grubun üyesi değilse hata verir.
create or replace function public._require_member(gid uuid) returns void language plpgsql stable security definer
set search_path = public as $$
begin
  if not _active(gid) then raise exception 'group_not_found'; end if;
  if not _is_member(gid, _uid()) then raise exception 'not_member'; end if;
end;
$$;

-- ---------- Profil ----------
create or replace function public.my_profile()
returns table (name text, email text) language sql stable security definer set search_path = public as $$
  select p.name, u.email::text from auth.users u left join profiles p on p.id = u.id where u.id = auth.uid();
$$;

create or replace function public.set_profile(p_name text) returns void language plpgsql security definer
set search_path = public as $$
begin
  begin
    insert into profiles (id, name) values (_uid(), btrim(p_name))
    on conflict (id) do update set name = excluded.name, updated_at = now();
  exception when check_violation or not_null_violation then
    raise exception 'invalid_name';
  end;
end;
$$;

-- Hesabı ve ona bağlı her şeyi (profil, grup üyelikleri) kalıcı olarak siler.
create or replace function public.delete_account() returns void language plpgsql security definer
set search_path = public as $$
begin
  delete from auth.users where id = _uid();
end;
$$;

-- ---------- Gruplar ----------
-- Eski (hesapsız) sürümün fonksiyonu; imzası değiştiği için kaldırılır.
drop function if exists public.join_group(uuid, text, text, double precision, double precision, text);
drop function if exists public.group_members(uuid);

create or replace function public.create_group() returns uuid language plpgsql security definer
set search_path = public as $$
declare
  new_id uuid;
begin
  -- Kötüye kullanıma karşı: kişi başı günde en fazla 20 grup.
  if (select count(*) from groups where owner = _uid() and created_at > now() - interval '1 day') >= 20 then
    raise exception 'rate_limited';
  end if;
  insert into groups (owner) values (_uid()) returning id into new_id;
  return new_id;
end;
$$;

-- Aynı kişi aynı linki tekrar açarsa yeni kayıt açılmaz, konumu ve aracı güncellenir.
create or replace function public.join_group(
  gid uuid, p_mode text, p_lat double precision, p_lon double precision, p_label text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  uid uuid := _uid();
  pname text;
  mid uuid;
begin
  select name into pname from profiles where id = uid;
  if pname is null then raise exception 'profile_required'; end if;
  -- Aynı gruba eşzamanlı katılımlarda 5 kişi sınırı aşılmasın.
  perform 1 from groups where id = gid and created_at > now() - interval '7 days' for update;
  if not found then raise exception 'group_not_found'; end if;
  begin
    update members set mode = p_mode, lat = p_lat, lon = p_lon, label = coalesce(p_label, '')
    where group_id = gid and user_id = uid returning id into mid;
    if mid is null then
      if (select count(*) from members where group_id = gid) >= 5 then raise exception 'group_full'; end if;
      insert into members (group_id, user_id, mode, lat, lon, label)
      values (gid, uid, p_mode, p_lat, p_lon, coalesce(p_label, ''))
      returning id into mid;
    end if;
  exception when check_violation or not_null_violation then
    raise exception 'invalid_member';
  end;
  return mid;
end;
$$;

-- tag: aynı isimde başka üye varsa e-posta (yalnızca grubun üyeleri görür), yoksa null.
create or replace function public.group_members(gid uuid)
returns table (id uuid, user_id uuid, name text, tag text, is_me boolean,
               mode text, lat double precision, lon double precision, label text)
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := _uid();
  inside boolean;
begin
  if not _active(gid) then raise exception 'group_not_found'; end if;
  inside := _is_member(gid, uid);
  return query
    with m as (
      select mm.id, mm.user_id, coalesce(p.name, mm.name, '?') as name, u.email::text as email,
             mm.mode, mm.lat, mm.lon, mm.label, mm.created_at
      from members mm
      left join profiles p on p.id = mm.user_id
      left join auth.users u on u.id = mm.user_id
      where mm.group_id = gid
    )
    select m.id, m.user_id, m.name,
           case when inside and (select count(*) from m m2 where lower(m2.name) = lower(m.name)) > 1
                then m.email end,
           m.user_id = uid, m.mode, m.lat, m.lon, m.label
    from m order by m.created_at;
end;
$$;

-- ---------- Ortak defter ----------
create or replace function public.gathering(gid uuid) returns json language plpgsql stable security definer
set search_path = public as $$
begin
  perform _require_member(gid);
  return (
    select json_build_object(
      'spot', g.spot,
      'items', coalesce((select json_agg(json_build_object('id', i.id, 'name', i.name, 'who', i.who, 'done', i.done)
                                         order by i.created_at) from items i where i.group_id = gid), '[]'::json),
      'expenses', coalesce((select json_agg(json_build_object('id', e.id, 'what', e.what, 'payer', e.payer,
                                                              'kurus', e.kurus, 'for', e.for_whom)
                                            order by e.created_at) from expenses e where e.group_id = gid), '[]'::json))
    from groups g where g.id = gid);
end;
$$;

create or replace function public.set_spot(gid uuid, p_spot text) returns void language plpgsql security definer
set search_path = public as $$
begin
  perform _require_member(gid);
  update groups set spot = left(btrim(coalesce(p_spot, '')), 80) where id = gid;
end;
$$;

create or replace function public.add_items(gid uuid, p_names text[]) returns uuid[] language plpgsql security definer
set search_path = public as $$
declare
  ids uuid[];
begin
  perform _require_member(gid);
  if (select count(*) from items where group_id = gid) + coalesce(cardinality(p_names), 0) > 60 then
    raise exception 'too_many';
  end if;
  begin
    with ins as (
      insert into items (group_id, name, created_at)
      select gid, btrim(n), now() + (o * interval '1 microsecond') from unnest(p_names) with ordinality as t(n, o)
      returning id, created_at
    )
    select array_agg(id order by created_at) into ids from ins;
  exception when check_violation or not_null_violation then
    raise exception 'invalid_item';
  end;
  return coalesce(ids, '{}');
end;
$$;

create or replace function public.set_item(iid uuid, p_who uuid, p_done boolean) returns void language plpgsql security definer
set search_path = public as $$
declare
  gid uuid;
begin
  select group_id into gid from items where id = iid;
  if gid is null then raise exception 'not_found'; end if;
  perform _require_member(gid);
  if p_who is not null and not _is_member(gid, p_who) then raise exception 'invalid_item'; end if;
  update items set who = p_who, done = coalesce(p_done, false) where id = iid;
end;
$$;

create or replace function public.delete_item(iid uuid) returns void language plpgsql security definer
set search_path = public as $$
declare
  gid uuid;
begin
  select group_id into gid from items where id = iid;
  if gid is null then return; end if;
  perform _require_member(gid);
  delete from items where id = iid;
end;
$$;

create or replace function public.add_expense(gid uuid, p_what text, p_payer uuid, p_kurus integer, p_for uuid[])
returns uuid language plpgsql security definer set search_path = public as $$
declare
  eid uuid;
begin
  perform _require_member(gid);
  if (select count(*) from expenses where group_id = gid) >= 100 then raise exception 'too_many'; end if;
  if not _is_member(gid, p_payer)
     or (select count(distinct u) from unnest(p_for) u) <> cardinality(p_for)
     or exists (select 1 from unnest(p_for) u where not _is_member(gid, u)) then
    raise exception 'invalid_expense';
  end if;
  begin
    insert into expenses (group_id, what, payer, kurus, for_whom)
    values (gid, btrim(p_what), p_payer, p_kurus, p_for) returning id into eid;
  exception when check_violation or not_null_violation then
    raise exception 'invalid_expense';
  end;
  return eid;
end;
$$;

create or replace function public.delete_expense(eid uuid) returns void language plpgsql security definer
set search_path = public as $$
declare
  gid uuid;
begin
  select group_id into gid from expenses where id = eid;
  if gid is null then return; end if;
  perform _require_member(gid);
  delete from expenses where id = eid;
end;
$$;

-- ---------- Yetkiler: yalnızca giriş yapmış kullanıcılar, yalnızca bu fonksiyonlar ----------
-- Supabase yeni fonksiyonlara authenticated'a da doğrudan yetki verir; yardımcılar (_active,
-- _is_member...) dışarıdan çağrılıp üyelik sızdırmasın diye önce hepsi geri alınır.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.my_profile(), public.set_profile(text), public.delete_account(),
  public.create_group(), public.join_group(uuid, text, double precision, double precision, text),
  public.group_members(uuid), public.gathering(uuid), public.set_spot(uuid, text),
  public.add_items(uuid, text[]), public.set_item(uuid, uuid, boolean), public.delete_item(uuid),
  public.add_expense(uuid, text, uuid, integer, uuid[]), public.delete_expense(uuid)
to authenticated;

-- Süresi dolan grupları saatte bir sil (Database > Extensions'tan pg_cron'u aç).
-- create extension if not exists pg_cron;
-- select cron.unschedule('ortaknokta-cleanup');
-- select cron.schedule('ortaknokta-cleanup', '0 * * * *',
--   $$delete from public.groups where created_at < now() - interval '7 days'$$);
