// Sitenin dışarıyla konuştuğu tek yer: davet grupları (Supabase RPC) ve adres arama (Nominatim).
// Uygulamadaki lib/services/group_api.dart ve osm_api.dart ile aynı kurallar.

const env = import.meta.env ?? {}
export const supabaseUrl = env.VITE_SUPABASE_URL ?? ''
export const supabaseKey = env.VITE_SUPABASE_ANON_KEY ?? ''
export const invitesReady = Boolean(supabaseUrl && supabaseKey)

const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i
export const parseId = (text) => text?.match(UUID)?.[0].toLowerCase() ?? null

/** `/g/<kimlik>` davet, `/gizlilik` gizlilik, geri kalan her şey ana sayfa. */
export function routeOf(pathname, base = '/') {
  const rest = pathname.startsWith(base) ? pathname.slice(base.length) : pathname
  const seg = rest.split('/').filter(Boolean)
  const id = seg.length === 2 && seg[0] === 'g' ? parseId(seg[1]) : null
  if (id) return { page: 'join', id }
  if (seg[0] === 'gizlilik') return { page: 'privacy' }
  return { page: 'home' }
}

export const appLink = (id) => `ortaknokta://join/g/${id}`

export const MODES = { walk: 'Yürüyerek', car: 'Araçla' }

export class ApiError extends Error {}

// Giriş yapmış kişinin erişim anahtarı; auth.js bağlar (testlerde supabase-js yüklenmesin diye ayrı).
let tokenProvider = async () => null
export const setTokenProvider = (fn) => {
  tokenProvider = fn
}

export function rpcMessage(status, code) {
  return (
    {
      group_not_found: 'Bu davet bulunamadı ya da süresi doldu. Davetler 7 gün geçerli.',
      auth_required: 'Oturumun kapanmış. Tekrar giriş yap.',
      profile_required: 'Önce bir isim seçmelisin.',
      invalid_name: 'İsim 1-30 karakter olmalı.',
      group_full: 'Grup dolmuş, en fazla 5 kişi olabiliyor.',
      invalid_member: 'Bilgilerde bir sorun var. Konumunu kontrol eder misin?',
    }[code] ?? `Sunucu şu an yanıt vermiyor (${status}).`
  )
}

async function fetchJson(url, init) {
  if (!url.startsWith('https://')) throw new ApiError('Güvensiz bağlantı engellendi.')
  let res
  try {
    res = await fetch(url, { ...init, signal: AbortSignal.timeout(15000) })
  } catch {
    throw new ApiError('Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.')
  }
  const text = await res.text()
  if (text.length > 2_000_000) throw new ApiError('Beklenmeyen sunucu yanıtı.')
  let body = null
  try {
    body = text ? JSON.parse(text) : null
  } catch {
    if (res.ok) throw new ApiError('Beklenmeyen sunucu yanıtı.')
  }
  return { res, body }
}

async function rpc(fn, args) {
  if (!invitesReady) throw new ApiError('Davet özelliği henüz açılmadı.')
  const token = await tokenProvider()
  if (!token) throw new ApiError('Önce Google ile giriş yapmalısın.')
  const { res, body } = await fetchJson(`${supabaseUrl}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: { apikey: supabaseKey, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(args),
  })
  if (res.status === 429) throw new ApiError('Çok fazla istek. Biraz sonra tekrar dene.')
  if (!res.ok) throw new ApiError(rpcMessage(res.status, body?.message))
  return body
}

const validPoint = (lat, lon) =>
  Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180

export const joinGroup = (gid, mode, place) =>
  rpc('join_group', {
    gid,
    p_mode: mode,
    p_lat: place.lat,
    p_lon: place.lon,
    p_label: place.label.slice(0, 120),
  })

export async function groupMembers(gid) {
  const rows = await rpc('group_members', { gid })
  if (!Array.isArray(rows)) throw new ApiError('Beklenmeyen sunucu yanıtı.')
  return rows
    .filter((r) => typeof r.name === 'string' && MODES[r.mode] && validPoint(r.lat, r.lon))
    .map((r) => ({
      id: r.id,
      name: r.tag ? `${r.name} (${r.tag})` : r.name, // aynı isimde iki kişi varsa e-postayla ayrışır
      isMe: r.is_me === true,
      mode: r.mode,
      label: String(r.label ?? ''),
    }))
}

/** Giriş yapmış kişinin ismi ve e-postası; isim seçilmemişse name null. */
export async function myProfile() {
  const rows = await rpc('my_profile', {})
  return Array.isArray(rows) && rows[0] ? { name: rows[0].name ?? null, email: String(rows[0].email ?? '') } : null
}

export const setProfile = (name) => rpc('set_profile', { p_name: name.trim() })

/** Nominatim adından kısa, okunur bir etiket üretir (uygulamadaki _label ile aynı). */
export function placeLabel(x) {
  const name = typeof x.name === 'string' ? x.name.trim() : ''
  const parts = String(x.display_name ?? '').split(',').map((s) => s.trim())
  const label = name && parts.length > 1 ? `${name}, ${parts.slice(1, 3).join(', ')}` : parts.slice(0, 3).join(', ')
  return label.slice(0, 120)
}

const searchCache = new Map()

// Nominatim kuralı: otomatik tamamlama yok, yalnızca kullanıcı "Ara"ya basınca çağrılır; sonuçlar önbelleğe alınır.
export async function searchPlaces(query) {
  const q = query.trim()
  if (q.length < 3 || q.length > 100) return []
  const key = q.toLocaleLowerCase('tr')
  if (searchCache.has(key)) return searchCache.get(key)
  const url = `https://nominatim.openstreetmap.org/search?${new URLSearchParams({
    q,
    format: 'jsonv2',
    limit: '6',
    'accept-language': 'tr',
  })}`
  const { res, body } = await fetchJson(url)
  if (res.status === 429) throw new ApiError('Çok fazla arama yapıldı. Biraz sonra tekrar dene.')
  if (!res.ok || !Array.isArray(body)) throw new ApiError('Adres araması şu an çalışmıyor.')
  const places = body
    .map((x) => ({ label: placeLabel(x), lat: Number(x.lat), lon: Number(x.lon) }))
    .filter((p) => validPoint(p.lat, p.lon))
  searchCache.set(key, places)
  return places
}

export function currentPosition() {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) return reject(new ApiError('Tarayıcın konum paylaşmayı desteklemiyor.'))
    navigator.geolocation.getCurrentPosition(
      (p) => resolve({ label: 'Şu anki konumum', lat: p.coords.latitude, lon: p.coords.longitude }),
      () => reject(new ApiError('Konumuna ulaşamadık. İzin vermediysen adresini yazarak arayabilirsin.')),
      { enableHighAccuracy: false, timeout: 15000 },
    )
  })
}
