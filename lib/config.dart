// Servis adresleri derleme anında değiştirilebilir (kendi OSRM/Nominatim sunucuna
// geçmek için güncelleme gerekmez): flutter run --dart-define=OSRM_CAR_URL=https://...
const osrmCarUrl = String.fromEnvironment('OSRM_CAR_URL',
    defaultValue: 'https://routing.openstreetmap.de/routed-car');
const osrmFootUrl = String.fromEnvironment('OSRM_FOOT_URL',
    defaultValue: 'https://routing.openstreetmap.de/routed-foot');
const nominatimUrl = String.fromEnvironment('NOMINATIM_URL',
    defaultValue: 'https://nominatim.openstreetmap.org');
// Ana Overpass sunucusu yoğunken 502/504 verebiliyor; o zaman yedeği denenir.
// Yedek: Türkiye'den erişilebilen ve tarayıcıdan (CORS) çağrılabilen VK/mail.ru örneği
// (Kasım 2026'da denendi; private.coffee ve kumi.systems buradan yanıt vermedi).
const overpassUrl = String.fromEnvironment('OVERPASS_URL',
    defaultValue: 'https://overpass-api.de/api/interpreter');
const overpassFallbackUrl = String.fromEnvironment('OVERPASS_FALLBACK_URL',
    defaultValue: 'https://maps.mail.ru/osm/tools/overpass/api/interpreter');

// Davet linkleri için (boşsa özellik kapalı). Anon anahtar herkese açık olacak
// şekilde tasarlandı; tablolar yalnızca supabase/schema.sql'deki fonksiyonlarla erişilir.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

// Tanıtım sitesinin adresi (davet linki https://<site>/g/<id> olur). Boşsa yalnızca kod paylaşılır.
const siteUrl = String.fromEnvironment('SITE_URL');

// Hava tahmini: anahtarsız, ticari olmayan kullanımda ücretsiz.
const weatherUrl = String.fromEnvironment('WEATHER_URL', defaultValue: 'https://api.open-meteo.com/v1/forecast');

const tileUrl = String.fromEnvironment('TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

// OSM politikaları uygulamayı tanımlayan, iletişim içeren bir User-Agent ister;
// varsayılan Dart UA'sı engellenir. İletişim adresi: GitHub deposu.
const appUserAgent = 'OrtakNokta/0.1.0 (+https://github.com/mirhatuguzlu/Ortak-Nokta)';
