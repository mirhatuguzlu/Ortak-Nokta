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
// Overpass yoğunken (Kasım 2026: ana sunucu 502, yedek 504/18 sn) mekanlar buradan gelir:
// aynı OSM verisi, ~1 sn, ama açılış saati gibi ayrıntılar olmadan.
const photonUrl = String.fromEnvironment('PHOTON_URL', defaultValue: 'https://photon.komoot.io');
const overpassFallbackUrl = String.fromEnvironment('OVERPASS_FALLBACK_URL',
    defaultValue: 'https://maps.mail.ru/osm/tools/overpass/api/interpreter');

// Varsayılanlar bu projenin herkese açık istemci değerleri (sitede de yayında); gizli anahtar
// (service_role / sb_secret / servis hesabı JSON) buraya ASLA yazılmaz. --dart-define ile değiştirilebilir.
// Davet linkleri için (boşsa özellik kapalı). Anon anahtar herkese açık olacak
// şekilde tasarlandı; tablolar yalnızca supabase/schema.sql'deki fonksiyonlarla erişilir.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://fzmwgfuczibcilmnmahs.supabase.co');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ6bXdnZnVjemliY2lsbW5tYWhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM3NDA1OTgsImV4cCI6MjEwOTMxNjU5OH0.Cb0bpsChMSscnHmHqHvdBQqks8s5CN5lK5HrZky2KkY');
// Telefonda uygulama içi Google girişi: Google Cloud'daki Web istemcisinin kimliği (Supabase'deki ile aynı)
// ve iOS istemcisinin kimliği. Gizli değildir.
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '206608857674-49hndoei2vds2ajgkv2m3i59nqvkfreu.apps.googleusercontent.com');
const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

// Telefon bildirimleri (Firebase Cloud Messaging). Boşsa yalnızca uygulama içi bildirim kutusu
// çalışır. Değerler: Firebase > Proje ayarları > Genel > Uygulamaların (SETUP.md > Bildirimler).
const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyCfA-9pbT9qntXtCjRGoLKdXX_PoxzCo1o');
const firebaseIosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'ortak-nokta-513810');
const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '206608857674');
const firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '1:206608857674:android:051ac056b5d46e33e404b3');
const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

// Tanıtım sitesinin adresi (davet linki https://<site>/g/<id> olur). Boşsa yalnızca kod paylaşılır.
const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://mirhatuguzlu.github.io/Ortak-Nokta');

// Hava tahmini: anahtarsız, ticari olmayan kullanımda ücretsiz.
const weatherUrl = String.fromEnvironment('WEATHER_URL', defaultValue: 'https://api.open-meteo.com/v1/forecast');

const tileUrl = String.fromEnvironment('TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

// OSM politikaları uygulamayı tanımlayan, iletişim içeren bir User-Agent ister;
// varsayılan Dart UA'sı engellenir. İletişim adresi: GitHub deposu.
const appUserAgent = 'OrtakNokta/0.1.0 (+https://github.com/mirhatuguzlu/Ortak-Nokta)';
