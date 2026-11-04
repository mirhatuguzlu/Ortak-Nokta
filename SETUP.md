# Kurulum: davet linkleri ve tanıtım sitesi

Uygulamanın kendisi hiçbir kurulum olmadan çalışır. Aşağıdakiler yalnızca **davet linkleri**
ve **tanıtım sitesi** için gerekir. Hepsi ücretsiz katmanlarda çalışır.

## 1. Supabase (davet linkleri)

1. <https://supabase.com> → **New project**. Bölge olarak **Frankfurt (eu-central-1)** seç
   (Türkiye'ye en yakın; KVKK açısından AB içinde kalır).
2. Sol menü **SQL Editor** → [`supabase/schema.sql`](supabase/schema.sql) içeriğini yapıştır → **Run**.
3. (Önerilen) **Database → Extensions** → `pg_cron`'u aç, sonra `schema.sql`'in en altındaki
   iki yorum satırını SQL Editor'de çalıştır. Süresi dolan gruplar saatte bir silinir.
   Açmasan da 24 saati geçen gruplara erişilemez; yalnızca veritabanında kalırlar.
4. **Project Settings → API** sayfasından iki değeri al:
   - `Project URL` → `SUPABASE_URL`
   - `anon public` anahtarı → `SUPABASE_ANON_KEY`

   `anon` anahtarı herkese açık olacak şekilde tasarlandı; tablolar ona kapalı, yalnızca üç
   fonksiyon açık. **`service_role` anahtarını asla uygulamaya veya depoya koyma.**

Bana bu iki değeri gönderebilirsin ya da aşağıdaki komutlarda kendin kullanabilirsin.

## 2. Tanıtım sitesi (React, GitHub Pages)

Site uygulamadan ayrı bir projedir: [`site/`](site) (React + Vite). Davet linkleri
(`https://<site>/g/<kod>`) uygulaması olmayan kişiler için sitede açılır.

Yerelde:

```bash
cd site
npm install
npm run dev
```

Davet sayfasını yerelde denemek için `site/.env.example`'ı `site/.env.local` olarak kopyalayıp değerleri doldur.

**GitHub Pages ile yayın (ücretsiz):** `main`'e `site/` altında bir değişiklik gittiğinde
[`.github/workflows/site.yml`](.github/workflows/site.yml) siteyi derleyip yayınlar. Bir kez:

1. Depo → **Settings → Pages → Source: GitHub Actions**.
2. **Settings → Secrets and variables → Actions → Variables** altına `VITE_SUPABASE_URL` ve
   `VITE_SUPABASE_ANON_KEY` ekle (anon anahtar herkese açık olacak şekilde tasarlandı).

Adres, depo adı `<kullanıcı>.github.io` ise `https://<kullanıcı>.github.io`, değilse
`https://<kullanıcı>.github.io/<depo>` olur; iş akışı alt yolu kendisi ayarlar. Derleme `index.html`'i
`404.html` olarak da kopyalar, böylece `/g/...` ve `/gizlilik` adresleri doğrudan açılır.

## 3. Uygulamayı bu ayarlarla derlemek

```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ... --dart-define=SITE_URL=https://<kullanıcı>.github.io/<depo>
```

Mağaza derlemesi:

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ... --dart-define=SITE_URL=https://<kullanıcı>.github.io/<depo>
```

Bu değerler verilmezse davet menüsü "yakında" mesajı gösterir; diğer her şey çalışır.

## 4. Sonra yapılabilecekler

- **App Links / Universal Links:** Şu an davet linki sitede açılır, sitedeki "Uygulamada aç"
  düğmesi `ortaknokta://join/g/<kod>` ile uygulamayı açar. Link doğrudan uygulamada açılsın
  istersen sitede `/.well-known/assetlinks.json` (Android) ve `apple-app-site-association` (iOS)
  dosyaları ve manifest/entitlement ayarları gerekir; bunun için önce paket adı ve imzalama
  anahtarı kesinleşmeli.
- **Mağaza linkleri:** Uygulama yayınlanınca `site/src/Landing.jsx` içindeki `Download` bölümündeki rozetler
  "Yakında" yerine mağaza adresine bağlanır.
- **Kötüye kullanım:** `create_group` herkes tarafından çağrılabilir. Ücretsiz katmanda sorun
  olmaz; kötüye kullanım görürsen Supabase'de hız sınırı veya Cloudflare Turnstile eklenebilir.
