# Kurulum: davet linkleri ve tanıtım sitesi

Uygulamanın kendisi hiçbir kurulum olmadan çalışır. Aşağıdakiler yalnızca **davet linkleri**
ve **tanıtım sitesi** için gerekir. Hepsi ücretsiz katmanlarda çalışır.

## 1. Supabase (davet linkleri)

1. <https://supabase.com> → **New project**. Bölge olarak **Frankfurt (eu-central-1)** seç
   (Türkiye'ye en yakın; KVKK açısından AB içinde kalır).
2. Sol menü **SQL Editor** → [`supabase/schema.sql`](supabase/schema.sql) içeriğini yapıştır → **Run**.
   Eski (hesapsız) şemayı kurduysan aynısını tekrar çalıştırman yeterli; kendini yükseltir.
3. (Önerilen) **Database → Extensions** → `pg_cron`'u aç, sonra `schema.sql`'in en altındaki
   iki yorum satırını SQL Editor'de çalıştır. Süresi dolan gruplar saatte bir silinir.
   Açmasan da 7 günü geçen gruplara erişilemez; yalnızca veritabanında kalırlar.
4. **Project Settings → API** sayfasından iki değeri al:
   - `Project URL` → `SUPABASE_URL`
   - `anon public` anahtarı → `SUPABASE_ANON_KEY`

   `anon` anahtarı herkese açık olacak şekilde tasarlandı; tablolar ona kapalı. Fonksiyonlar
   yalnızca Google ile giriş yapmış kullanıcıya açık. **`service_role` anahtarını asla uygulamaya veya depoya koyma.**

Bana bu iki değeri gönderebilirsin ya da aşağıdaki komutlarda kendin kullanabilirsin.

### Google ile giriş (zorunlu: Supabase bağlıysa uygulama giriş ister)

1. <https://console.cloud.google.com> → yeni proje → **APIs & Services → OAuth consent screen**:
   kullanıcı türü **External**, uygulama adı "Ortak Nokta", destek e-postası. Kapsamlar: `email`,
   `profile`, `openid` (varsayılanlar). Test aşamasında kendi Gmail'ini **Test users**'a ekle.
2. **Credentials → Create credentials → OAuth client ID → Web application**.
   **Authorized redirect URIs**: `https://<proje>.supabase.co/auth/v1/callback`
   (Supabase'de Authentication → Providers → Google sayfasında "Callback URL" olarak yazar).
3. Supabase → **Authentication → Providers → Google** → Enable; Client ID ve Client Secret'ı yapıştır.
4. Supabase → **Authentication → URL Configuration → Redirect URLs** listesine ekle:
   - `ortaknokta://login-callback` (Android/iOS uygulaması)
   - Sitenin adresi ve davet yolu: `https://<kullanıcı>.github.io/<depo>/**`
   - Yerel deneme: `http://localhost:5173/**` (site) ve `http://localhost:5174/**` (uygulamanın web hali)

   **Site URL** alanına sitenin ana adresini yaz.

Giriş yapan herkes ilk seferde bir isim seçer. Bir grupta aynı isimde iki kişi olursa grubun
üyeleri isimlerin yanında e-postayı görür; başka durumda e-posta kimseye gösterilmez.
Supabase yapılandırılmadan derlenen uygulama girişsiz, yalnızca bu cihazda çalışır.

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
