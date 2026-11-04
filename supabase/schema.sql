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
-- Hesaba bağlı tercihler (varsayılan araç, ev konumu, bildirim türleri). Uygulama yazar;
-- sunucu yalnızca prefs.notify.<tür> = false olanlara telefon bildirimi göndermez.
alter table public.profiles add column if not exists prefs jsonb not null default '{}'::jsonb
  check (jsonb_typeof(prefs) = 'object' and pg_column_size(prefs) < 4000);

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
-- Grubu sessize alan üyeye telefon bildirimi gitmez (uygulama içi kutuya yine düşer).
alter table public.members add column if not exists muted boolean not null default false;

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

-- ---------- Bildirimler ----------
-- Telefonların FCM anahtarları. Aynı telefonda başka hesapla girilirse anahtar o hesaba geçer.
create table if not exists public.devices (
  token text primary key check (char_length(token) between 10 and 4096),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);
create index if not exists devices_user_idx on public.devices(user_id);

-- Uygulama içi bildirim kutusu. push = true olan her yeni satırı Database Webhook
-- push Edge Function'ına iletir, o da kişinin telefonlarına gönderir.
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  actor uuid,
  kind text not null,
  category text not null check (category in ('group', 'items', 'money', 'live', 'reminder')),
  title text not null,
  body text not null,
  push boolean not null default true,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications(user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.members enable row level security;
alter table public.items enable row level security;
alter table public.expenses enable row level security;
alter table public.devices enable row level security;
alter table public.notifications enable row level security;
revoke all on public.profiles, public.groups, public.members, public.items, public.expenses,
  public.devices, public.notifications from anon, authenticated;

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
drop function if exists public.my_profile(); -- dönüş tipi değişti (prefs eklendi)
create or replace function public.my_profile()
returns table (name text, email text, prefs jsonb) language sql stable security definer set search_path = public as $$
  select p.name, u.email::text, coalesce(p.prefs, '{}'::jsonb)
  from auth.users u left join profiles p on p.id = u.id where u.id = auth.uid();
$$;

create or replace function public.set_prefs(p jsonb) returns void language plpgsql security definer
set search_path = public as $$
begin
  begin
    update profiles set prefs = coalesce(p, '{}'::jsonb), updated_at = now() where id = _uid();
  exception when check_violation then
    raise exception 'invalid_prefs';
  end;
  if not found then raise exception 'profile_required'; end if;
end;
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
               mode text, lat double precision, lon double precision, label text, muted boolean)
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
             mm.mode, mm.lat, mm.lon, mm.label, mm.muted, mm.created_at
      from members mm
      left join profiles p on p.id = mm.user_id
      left join auth.users u on u.id = mm.user_id
      where mm.group_id = gid
    )
    select m.id, m.user_id, m.name,
           case when inside and (select count(*) from m m2 where lower(m2.name) = lower(m.name)) > 1
                then m.email end,
           m.user_id = uid, m.mode, m.lat, m.lon, m.label,
           case when m.user_id = uid then m.muted end -- başkasının sessize aldığı görünmez
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

-- ---------- Canlı yayın (Supabase Realtime, özel kanallar) ----------
-- Bir grupta bir şey değişince 'group:<id>' kanalına, birine bildirim düşünce 'user:<id>'
-- kanalına boş bir "değişti" sinyali gider; uygulama veriyi her zamanki fonksiyonlarla çeker.
-- Kanalı yalnızca grubun üyeleri / kişinin kendisi dinleyebilir (aşağıdaki politika).
create or replace function public._broadcast(p_topic text, p_event text) returns void language plpgsql
security definer set search_path = public as $$
begin
  perform realtime.send('{}'::jsonb, p_event, p_topic, true);
exception when others then
  null; -- canlı yayın kapalıysa ya da o an ulaşılamıyorsa asıl yazma işlemi yine başarılı olsun
end;
$$;

create or replace function public.can_listen(p_topic text) returns boolean language sql stable security definer
set search_path = public as $$
  select case
    when auth.uid() is null then false
    when p_topic = 'user:' || auth.uid() then true
    when p_topic ~ '^group:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then _active(substr(p_topic, 7)::uuid) and _is_member(substr(p_topic, 7)::uuid, auth.uid())
    else false
  end;
$$;

do $$
begin
  if to_regclass('realtime.messages') is not null then
    drop policy if exists "ortaknokta: uyeler dinler" on realtime.messages;
    create policy "ortaknokta: uyeler dinler" on realtime.messages for select to authenticated
      using (realtime.messages.extension = 'broadcast' and public.can_listen((select realtime.topic())));
  end if;
end $$;

create or replace function public._tg_changed() returns trigger language plpgsql security definer
set search_path = public as $$
declare
  j jsonb := to_jsonb(case when tg_op = 'DELETE' then old else new end);
begin
  perform _broadcast('group:' || coalesce(j ->> 'group_id', j ->> 'id'), 'changed');
  return null;
end;
$$;

drop trigger if exists live_groups on public.groups;
drop trigger if exists live_members on public.members;
drop trigger if exists live_items on public.items;
drop trigger if exists live_expenses on public.expenses;
create trigger live_groups after update on public.groups for each row execute function public._tg_changed();
create trigger live_members after insert or update or delete on public.members for each row execute function public._tg_changed();
create trigger live_items after insert or update or delete on public.items for each row execute function public._tg_changed();
create trigger live_expenses after insert or update or delete on public.expenses for each row execute function public._tg_changed();

-- ---------- Bildirimler: kime, ne zaman ----------
-- Kural: kimse kendi yaptığı şey için bildirim almaz; yalnızca o gruptakiler alır.
--   group    : biri gruba katıldı · biri nereden geleceğini değiştirdi · buluşma yeri netleşti  → gruptaki herkes
--   items    : listeye bir şey eklendi → herkes  ·  bir iş sana verildi → yalnızca sen
--   money    : seni ilgilendiren masraf eklendi/silindi → ödeyen + paylaşanlar
--   live     : yoldayım / gecikeceğim / vardım → gruptaki herkes
--   reminder : defter silinmeden 1 gün önce, hesapta masraf varsa → herkes
-- Grubu sessize alan ya da o türü kapatan kişiye telefon bildirimi gitmez; kutusuna yine düşer.
create or replace function public._name(uid uuid) returns text language sql stable security definer
set search_path = public as $$
  select coalesce((select name from profiles where id = uid), 'Biri');
$$;

create or replace function public._tl(kurus integer) returns text language sql immutable as $$
  select regexp_replace(replace(to_char(kurus / 100.0, 'FM999999990.00'), '.', ','), ',00$', '') || ' TL';
$$;

create or replace function public._notify(gid uuid, p_actor uuid, recipients uuid[], p_kind text, p_category text,
                                          p_title text, p_body text) returns void
language plpgsql security definer set search_path = public as $$
declare
  r record;
begin
  for r in
    select m.user_id, m.muted, p.prefs from members m left join profiles p on p.id = m.user_id
    where m.group_id = gid and m.user_id = any(recipients) and m.user_id is distinct from p_actor
  loop
    -- Aynı kişiden aynı türde okunmamış bir bildirim 2 dakika içinde geldiyse yenisi açılmaz,
    -- öncekine eklenir: listeye 10 şey ekleyen telefonu 10 kez öttürmesin.
    update notifications n
      set body = left(case when p_kind = 'items_added' then n.body || ', ' || p_body else p_body end, 200),
          title = left(p_title, 120), created_at = now()
      where n.user_id = r.user_id and n.group_id = gid and n.kind = p_kind and n.actor is not distinct from p_actor
        and n.read_at is null and n.created_at > now() - interval '2 minutes';
    if not found then
      insert into notifications (user_id, group_id, actor, kind, category, title, body, push)
      values (r.user_id, gid, p_actor, p_kind, p_category, left(p_title, 120), left(p_body, 200),
              not r.muted and (r.prefs -> 'notify' ->> p_category) is distinct from 'false');
    end if;
    perform _broadcast('user:' || r.user_id, 'notify');
  end loop;
end;
$$;

create or replace function public._everyone(gid uuid) returns uuid[] language sql stable security definer
set search_path = public as $$
  select array(select user_id from members where group_id = gid);
$$;

create or replace function public._tg_member_notify() returns trigger language plpgsql security definer
set search_path = public as $$
declare
  everyone uuid[] := _everyone(new.group_id);
begin
  if tg_op = 'INSERT' then
    perform _notify(new.group_id, new.user_id, everyone, 'joined', 'group', _name(new.user_id) || ' gruba katıldı',
                    'Grupta artık ' || cardinality(everyone) || ' kişi var. Ortak noktaya bir bak.');
  else
    perform _notify(new.group_id, new.user_id, everyone, 'moved', 'group',
                    _name(new.user_id) || ' nereden geleceğini değiştirdi', 'Ortak nokta değişebilir; sonuca bir göz at.');
  end if;
  return null;
end;
$$;

create or replace function public._tg_item_notify() returns trigger language plpgsql security definer
set search_path = public as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then return null; end if;
  if tg_op = 'INSERT' then
    perform _notify(new.group_id, actor, _everyone(new.group_id), 'items_added', 'items',
                    _name(actor) || ' listeye ekledi', new.name);
  elsif new.who is not null and new.who is distinct from old.who and new.who <> actor then
    perform _notify(new.group_id, actor, array[new.who], 'assigned', 'items', _name(actor) || ' sana bir iş verdi',
                    '"' || new.name || '" senden. Getiremeyeceksen listeden değiştir.');
  end if;
  return null;
end;
$$;

create or replace function public._tg_expense_notify() returns trigger language plpgsql security definer
set search_path = public as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then return null; end if; -- süresi dolan grubun silinmesi bildirim üretmez
  if tg_op = 'INSERT' then
    perform _notify(new.group_id, actor, new.for_whom || new.payer, 'expense', 'money',
                    _name(actor) || ' hesaba masraf ekledi',
                    new.what || ': ' || _tl(new.kurus) || ', kişi başı ~' || _tl(new.kurus / cardinality(new.for_whom)) || '.');
  else
    perform _notify(old.group_id, actor, old.for_whom || old.payer, 'expense_removed', 'money',
                    _name(actor) || ' bir masrafı sildi', old.what || ' (' || _tl(old.kurus) || ') hesaptan çıkarıldı.');
  end if;
  return null;
end;
$$;

create or replace function public._tg_spot_notify() returns trigger language plpgsql security definer
set search_path = public as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null or new.spot = '' then return null; end if;
  perform _notify(new.id, actor, _everyone(new.id), 'spot', 'group', 'Buluşma yeri netleşti',
                  _name(actor) || ': ' || new.spot);
  return null;
end;
$$;

drop trigger if exists notify_join on public.members;
drop trigger if exists notify_move on public.members;
drop trigger if exists notify_items on public.items;
drop trigger if exists notify_expenses on public.expenses;
drop trigger if exists notify_spot on public.groups;
create trigger notify_join after insert on public.members for each row execute function public._tg_member_notify();
create trigger notify_move after update of lat, lon, mode on public.members for each row
  when (old.lat is distinct from new.lat or old.lon is distinct from new.lon or old.mode is distinct from new.mode)
  execute function public._tg_member_notify();
create trigger notify_items after insert or update of who on public.items for each row execute function public._tg_item_notify();
create trigger notify_expenses after insert or delete on public.expenses for each row execute function public._tg_expense_notify();
create trigger notify_spot after update of spot on public.groups for each row
  when (old.spot is distinct from new.spot) execute function public._tg_spot_notify();

-- "Yoldayım / gecikeceğim / vardım": sonuç ekranındaki düğme gruptaki herkese haber verir.
create or replace function public.ping(gid uuid, p_kind text, p_minutes integer) returns void language plpgsql
security definer set search_path = public as $$
declare
  uid uuid := _uid();
  who text := _name(uid);
  mins text := least(greatest(coalesce(p_minutes, 1), 1), 600)::text;
  spot text;
begin
  perform _require_member(gid);
  if p_kind is null or p_kind not in ('on_way', 'late', 'arrived') then raise exception 'invalid_ping'; end if;
  select g.spot into spot from groups g where g.id = gid;
  perform _notify(gid, uid, _everyone(gid), p_kind, 'live',
    case p_kind when 'on_way' then who || ' yola çıktı' when 'late' then who || ' gecikecek'
                else who || ' buluşma yerine vardı' end,
    case p_kind when 'on_way' then '~' || mins || ' dk sonra orada.' when 'late' then '~' || mins || ' dk geç kalacak.'
                else coalesce(nullif(spot, ''), 'Seni bekliyor.') end);
end;
$$;

create or replace function public.set_muted(gid uuid, p boolean) returns void language plpgsql security definer
set search_path = public as $$
begin
  perform _require_member(gid);
  update members set muted = coalesce(p, false) where group_id = gid and user_id = _uid();
end;
$$;

create or replace function public.my_notifications() returns json language sql stable security definer
set search_path = public as $$
  select coalesce(json_agg(json_build_object('id', n.id, 'group_id', n.group_id, 'kind', n.kind, 'title', n.title,
                                             'body', n.body, 'created_at', n.created_at, 'read', n.read_at is not null)
                           order by n.created_at desc), '[]'::json)
  from (select * from notifications where user_id = _uid() and created_at > now() - interval '30 days'
        order by created_at desc limit 50) n;
$$;

-- p_ids null: hepsini okundu say.
create or replace function public.mark_read(p_ids uuid[]) returns void language plpgsql security definer
set search_path = public as $$
begin
  update notifications set read_at = now()
  where user_id = _uid() and read_at is null and (p_ids is null or id = any(p_ids));
end;
$$;

create or replace function public.register_device(p_token text, p_platform text) returns void language plpgsql
security definer set search_path = public as $$
declare
  uid uuid := _uid();
begin
  begin
    insert into devices (token, user_id, platform) values (p_token, uid, p_platform)
    on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
  exception when check_violation or not_null_violation then
    raise exception 'invalid_device';
  end;
  -- Kişi başı en fazla 10 cihaz; en eskisi düşer.
  delete from devices where user_id = uid and token not in
    (select token from devices where user_id = uid order by updated_at desc limit 10);
end;
$$;

create or replace function public.unregister_device(p_token text) returns void language plpgsql security definer
set search_path = public as $$
begin
  delete from devices where token = p_token and user_id = _uid();
end;
$$;

-- Defter silinmeden bir gün önce, hesapta masraf varsa herkese hatırlatma (zamanlayıcı çağırır).
create or replace function public._remind_expiring() returns void language plpgsql security definer
set search_path = public as $$
declare
  g record;
begin
  for g in
    select gr.id from groups gr
    where gr.created_at <= now() - interval '6 days' and gr.created_at > now() - interval '7 days'
      and exists (select 1 from expenses e where e.group_id = gr.id)
      and not exists (select 1 from notifications n where n.group_id = gr.id and n.kind = 'expiring')
  loop
    perform _notify(g.id, null, _everyone(g.id), 'expiring', 'reminder', 'Buluşma defteri yarın silinecek',
                    'Hesabı kapatmayı unutma: kimin kime ne vereceğini son bir kez gör.');
  end loop;
end;
$$;

-- ---------- Yetkiler: yalnızca giriş yapmış kullanıcılar, yalnızca bu fonksiyonlar ----------
-- Supabase yeni fonksiyonlara authenticated'a da doğrudan yetki verir; yardımcılar (_active,
-- _is_member...) dışarıdan çağrılıp üyelik sızdırmasın diye önce hepsi geri alınır.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.my_profile(), public.set_profile(text), public.set_prefs(jsonb), public.delete_account(),
  public.create_group(), public.join_group(uuid, text, double precision, double precision, text),
  public.group_members(uuid), public.gathering(uuid), public.set_spot(uuid, text),
  public.add_items(uuid, text[]), public.set_item(uuid, uuid, boolean), public.delete_item(uuid),
  public.add_expense(uuid, text, uuid, integer, uuid[]), public.delete_expense(uuid),
  public.ping(uuid, text, integer), public.set_muted(uuid, boolean),
  public.my_notifications(), public.mark_read(uuid[]),
  public.register_device(text, text), public.unregister_device(text),
  public.can_listen(text) -- canlı kanal politikası çağırır; yalnızca "ben bu grupta mıyım" söyler
to authenticated;

-- ---------- Zamanlanmış işler (Database > Extensions'tan pg_cron açıksa kurulur) ----------
-- Aynı adla tekrar kurmak eski işi günceller.
do $do$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('ortaknokta-cleanup', '0 * * * *', $$
      delete from public.groups where created_at < now() - interval '7 days';
      delete from public.notifications where created_at < now() - interval '30 days';
      delete from public.devices where updated_at < now() - interval '90 days';
    $$);
    perform cron.schedule('ortaknokta-remind', '30 * * * *', $$select public._remind_expiring()$$);
  else
    raise notice 'pg_cron kapalı: süresi dolan gruplar silinmez, hatırlatma gitmez. Açıp bu dosyayı tekrar çalıştır.';
  end if;
end $do$;
