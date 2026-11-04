# Kurulum: hesaplar, davet linkleri, bildirimler ve tanıtım sitesi

Uygulamanın kendisi hiçbir kurulum olmadan, hesapsız ve yalnızca o telefonda çalışır. Aşağıdakiler
**Google ile giriş, davet linkleri, ortak liste/hesap, canlı güncelleme ve bildirimler** için gerekir.
Hepsi ücretsiz katmanlarda çalışır. Sıra önemli: Supabase → Google Cloud → Firebase → derleme.

Menü adları Kasım 2026'daki arayüze göredir; Supabase ve Google adları sık değiştirir. Bir menüyü
bulamazsan sayfanın üstündeki arama kutusuna adını yaz.

---

## 1. Supabase

### 1.1 Proje ve şema

1. <https://supabase.com/dashboard> → **New project**. Bölge: **Central EU (Frankfurt)**.
   Türkiye'ye en yakın bölge bu ve veriler AB içinde kalır.
2. Sol menü **Database → Extensions** → arama kutusuna `pg_cron` yaz → aç.
   Bu eklenti süresi dolan grupları siler ve "defter yarın silinecek" hatırlatmasını gönderir.
3. Sol menü **SQL Editor** → **New query** → [`supabase/schema.sql`](supabase/schema.sql)'in tamamını
   yapıştır → **Run**.
   - Eski şemayı kurduysan aynısını tekrar çalıştırman yeterli; kendini yükseltir.
   - Sonuçta "pg_cron kapalı" uyarısı görürsen 2. adımı yapıp şemayı tekrar çalıştır.

### 1.2 Anahtarlar

**Project Settings → API Keys** sayfasından:
- **Publishable key** (`sb_publishable_…`) → uygulamada `SUPABASE_ANON_KEY`, sitede `VITE_SUPABASE_ANON_KEY`.
  Eski projelerde **Legacy API Keys** sekmesindeki `anon` anahtarı da olur.
- Proje adresi (`https://<proje>.supabase.co`) → `SUPABASE_URL`. Üstteki **Connect** düğmesinde de yazar.

Bu anahtar herkese açık olacak şekilde tasarlandı: tablolar ona kapalı, fonksiyonlar yalnızca Google
ile giriş yapmış kişiye açık. **Secret key (`sb_secret_…`) ve `service_role` anahtarını asla
uygulamaya, siteye ya da depoya koyma.**

### 1.3 Canlı güncelleme (Realtime)

Biri gruba katılınca, listeye bir şey ekleyince ya da masraf girince diğerlerinin ekranı kendiliğinden
yenilenir. Bildirim kutusu da aynı yolla anında dolar. Şema gereken izni kendisi kurar.
Yalnızca grubun üyeleri o grubun kanalını dinleyebilir.

- **Realtime → Settings** → **Allow public access** seçeneğini **kapat** ve kaydet.
  Uygulama yalnızca özel kanal kullanır; bu ayar kanalların izinsiz dinlenmesini engeller.

Realtime çalışmasa da uygulama bozulmaz: ekranlar 30 sn'de bir kendisi yenilenir.

---

## 2. Google Cloud: Google ile giriş

Supabase bağlıysa uygulama ve site herkesten giriş ister.

1. <https://console.cloud.google.com> → üstteki proje seçici → **New project** → adı `Ortak Nokta`.
   Firebase'i de aynı projeye bağlayacağız (3. bölüm).
2. Arama kutusuna **Google Auth Platform** yaz ve aç. Proje ilk kez açılıyorsa **Get started** de:
   - **App information**: uygulama adı `Ortak Nokta`, destek e-postası olarak kendi Gmail'in.
   - **Audience**: **External**.
   - **Contact information**: e-postan → **Create**.
3. Sol menü **Audience** → **Test users** → **Add users** → kendi Gmail'in ve deneyecek arkadaşların.
   Uygulama "Testing" durumundayken yalnızca bu kişiler girebilir. Herkese açmak için sonra aynı
   sayfada **Publish app** de. Yalnızca `email`, `profile` ve `openid` istediğimiz için Google
   inceleme istemez.
4. Sol menü **Data Access** → **Add or remove scopes** → `.../auth/userinfo.email`,
   `.../auth/userinfo.profile` ve `openid` seç → **Update** → **Save**.
5. Sol menü **Clients** → **Create client**:
   - **Application type**: **Web application**, adı `Supabase`.
   - **Authorized redirect URIs** → **Add URI** → `https://<proje>.supabase.co/auth/v1/callback`.
     Doğru adresi Supabase'de **Authentication → Sign In / Providers → Google** sayfasında
     **Callback URL (for OAuth)** olarak görürsün.
   - **Create** → çıkan **Client ID** ve **Client secret**'ı kopyala. Secret yalnızca bir kez tam görünür.
6. Supabase → **Authentication → Sign In / Providers → Google** → **Enable Sign in with Google** →
   Client ID ve Client Secret'ı yapıştır → **Save**.
7. Supabase → **Authentication → URL Configuration**:
   - **Site URL**: sitenin ana adresi, örneğin `https://<kullanıcı>.github.io/<depo>`.
   - **Redirect URLs** → **Add URL** ile şunları tek tek ekle:
     - `ortaknokta://login-callback` (Android ve iOS uygulaması)
     - `https://<kullanıcı>.github.io/<depo>/**` (site ve davet sayfaları)
     - `http://localhost:5173/**` (site, yerel deneme)
     - `http://localhost:5174/**` (uygulamanın web hali, yerel deneme)

Giriş yapan herkes ilk seferde bir isim seçer; ismi sonra **Profil** sekmesinden değiştirir.
Bir grupta aynı isimde iki kişi olursa grubun üyeleri isimlerin yanında e-postayı görür. Başka
durumda e-posta kimseye gösterilmez.

---

## 3. Firebase: telefon bildirimleri

Bu bölümü yapmazsan her şey yine çalışır. Bildirimler uygulamadaki **Bildirimler** sekmesine anında
düşer, yalnızca telefona bildirim gelmez.

### 3.1 Proje ve Android uygulaması

1. <https://console.firebase.google.com> → **Create a project**. Ad yerine alttaki
   **Add Firebase to Google Cloud project** bağlantısıyla 2. bölümdeki `Ortak Nokta` projesini seç.
   Google Analytics'i kapatabilirsin; bildirim için gerekmez.
2. Proje ana sayfasında **Android** simgesi (Add app):
   - **Android package name**: `com.ortaknokta.ortak_nokta` (birebir aynı olmalı).
   - Takma ad: `Ortak Nokta Android` → **Register app**.
   - `google-services.json`'ı indir ama **projeye koyma**. Uygulama Firebase'i bu dosyayla değil,
     derleme değerleriyle açar. Sonraki adımları **Next** ile geç.
3. Sol üstte ⚙️ → **Project settings**:
   - **General** sekmesi → **Your apps** → Android uygulaması → **App ID** (`1:…:android:…`)
     → `FIREBASE_ANDROID_APP_ID`.
   - Aynı sayfada **Project ID** → `FIREBASE_PROJECT_ID`.
   - Aynı sayfada **Web API Key** → `FIREBASE_API_KEY`. Boşsa indirdiğin `google-services.json`'daki
     `current_key` değerini kullan.
   - **Cloud Messaging** sekmesi → **Firebase Cloud Messaging API (V1)** "Enabled" olmalı.
     Değilse yanındaki ⋮ → **Manage API in Google Cloud Console** → **Enable**.
     Aynı sekmedeki **Sender ID** → `FIREBASE_SENDER_ID`.

Bu dört değer gizli değildir; uygulamanın içine gömülür.

### 3.2 iOS (Mac ve Apple Developer hesabı gerekir)

1. Firebase proje ana sayfası → **Add app → iOS**. **Bundle ID** `com.ortaknokta.ortakNokta`
   olmalı. Bu uygulamanın **App ID**'si → `FIREBASE_IOS_APP_ID`. `GoogleService-Info.plist`'teki
   `API_KEY` değeri → `FIREBASE_IOS_API_KEY`.
2. <https://developer.apple.com/account> → **Certificates, IDs & Profiles → Keys** → **+** →
   **Apple Push Notifications service (APNs)** → `.p8` dosyasını indir ve **Key ID**'yi not al.
3. Firebase → **Project settings → Cloud Messaging → Apple app configuration** →
   **APNs Authentication Key → Upload** → `.p8` dosyası, Key ID ve Team ID.
4. Xcode'da `ios/Runner.xcworkspace` → **Runner** target → **Signing & Capabilities** →
   **+ Capability** → **Push Notifications**. Bir kez daha **+ Capability** → **Background Modes** →
   **Remote notifications**'ı işaretle.

### 3.3 Gönderici: Supabase Edge Function

Bildirimi telefona sunucu gönderir; uygulama yalnızca bildirim kutusuna yazar.

1. Firebase → **Project settings → Service accounts** → **Generate new private key** → **Generate key**.
   İnen JSON dosyası gizlidir; depoya koyma, kimseyle paylaşma.
2. Rastgele bir parola üret. Bunu webhook ile fonksiyon arasında ortak gizli değer olarak kullanacağız:

   ```bash
   node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"
   ```

3. Supabase → **Edge Functions → Secrets** → **Add new secret**:
   - `FCM_SERVICE_ACCOUNT` → 1. adımdaki JSON dosyasının **tamamını** yapıştır.
   - `PUSH_WEBHOOK_SECRET` → 2. adımdaki parola.
   - (Yalnızca **API Keys → Legacy** anahtarlarını kapattıysan) `PUSH_SECRET_KEY` →
     **API Keys**'te oluşturduğun bir **Secret key** (`sb_secret_…`).
4. Supabase → **Edge Functions** → **Deploy a new function** → **Via Editor**:
   - Fonksiyon adı: `push`.
   - Kod: [`supabase/functions/push/index.ts`](supabase/functions/push/index.ts)'in tamamını yapıştır.
   - **Deploy function**.
5. Fonksiyonun sayfası → **Details** (ya da **Settings**) → **Verify JWT with legacy secret** /
   **Enforce JWT verification** seçeneğini **kapat** → **Save**. Webhook kullanıcı oturumu taşımaz;
   güvenliği `x-webhook-secret` başlığı sağlar.

   Terminal kullanmak istersen 4. ve 5. adımın yerine:

   ```bash
   npx supabase functions deploy push --no-verify-jwt --project-ref <proje>
   ```

6. Supabase → **Integrations → Database Webhooks** (ilk kez açıyorsan **Enable webhooks**) →
   **Create a new hook**:
   - **Name**: `push`
   - **Table**: `public.notifications`, **Events**: yalnızca **Insert**
   - **Type of webhook**: **Supabase Edge Functions** → fonksiyon `push`, method `POST`,
     timeout `5000`.
   - **HTTP Headers** → **Add a new header**: ad `x-webhook-secret`, değer 2. adımdaki parola.
     `Content-type: application/json` başlığı kalsın.
   - **Create webhook**.
7. Deneme: telefonda giriş yap, bir grup kur ve "Biri katılınca haber vereyim mi?" sorusuna
   **Evet** de. Başka bir hesapla gruba katıl; ilk telefona bildirim gelmeli. Gelmezse
   **Edge Functions → push → Logs** sayfasına bak:
   - `403` → webhook başlığı yanlış.
   - `sent: 0` → telefon kaydı yok, yani izin verilmedi ya da Firebase değerleri eksik.
   - `FCM 401` / `403` → hizmet hesabı JSON'u eksik yapıştırılmış ya da FCM API kapalı.

### Kim, ne zaman bildirim alır

| Tür (Ayarlar'da kapatılabilir) | Ne olunca | Kime |
|---|---|---|
| Grup hareketleri | Biri gruba katıldı · biri nereden geleceğini değiştirdi · buluşma yeri netleşti | Gruptaki herkes |
| Kim ne getiriyor | Sana bir iş verildi | Yalnızca sen |
| | Listeye bir şey eklendi (2 dk içindekiler tek bildirimde birleşir) | Gruptaki herkes |
| Hesap | Seni ilgilendiren masraf eklendi ya da silindi | Ödeyen ve paylaşanlar |
| Yoldayım / vardım | Yola çıktı · gecikecek · vardı (sonuç ekranındaki **Yoldayım** düğmesi) | Gruptaki herkes |
| Hatırlatmalar | Defter yarın silinecek ve hesapta masraf var | Gruptaki herkes |

Her tür için şu kurallar geçerli:
- Kimse kendi yaptığı şey için bildirim almaz.
- Bir grubu o grubun sayfasından sessize alan kişiye telefon bildirimi gitmez; bildirim kutusuna yine düşer.
- Aynı kişiden aynı türde 2 dakika içinde gelen ikinci bildirim yenisini açmaz, öncekini günceller.
  Böylece telefon art arda ötmez.
- Telefonda aynı grubun aynı türdeki bildirimleri üst üste binmez, birbirinin yerine geçer.

---

## 4. Tanıtım sitesi (React, GitHub Pages)

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
   `VITE_SUPABASE_ANON_KEY` ekle (publishable anahtar herkese açık olacak şekilde tasarlandı).

Adres, depo adı `<kullanıcı>.github.io` ise `https://<kullanıcı>.github.io`, değilse
`https://<kullanıcı>.github.io/<depo>` olur; iş akışı alt yolu kendisi ayarlar. Derleme `index.html`'i
`404.html` olarak da kopyalar, böylece `/g/...` ve `/gizlilik` adresleri doğrudan açılır.

---

## 5. Uygulamayı bu ayarlarla derlemek

Değerleri her seferinde yazmamak için proje kökünde `defines.json` oluştur. Dosya `.gitignore`'da;
depoya girmez.

```json
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_...",
  "SITE_URL": "https://<kullanıcı>.github.io/<depo>",
  "FIREBASE_API_KEY": "AIza...",
  "FIREBASE_PROJECT_ID": "ortak-nokta-xxxx",
  "FIREBASE_SENDER_ID": "1234567890",
  "FIREBASE_ANDROID_APP_ID": "1:1234567890:android:abc...",
  "FIREBASE_IOS_APP_ID": "1:1234567890:ios:def...",
  "FIREBASE_IOS_API_KEY": "AIza..."
}
```

```bash
flutter run --dart-define-from-file=defines.json
```

Mağaza derlemesi:

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=defines.json
```

Bir değer verilmezse yalnızca o özellik kapanır:
- Supabase yoksa uygulama hesapsız çalışır, davet menüsü "yakında" der.
- Firebase yoksa telefon bildirimi gelmez, bildirim kutusu yine çalışır.

---

## 6. Sonra yapılabilecekler

- **App Links / Universal Links:** Şu an davet linki sitede açılır. Sitedeki "Uygulamada aç" düğmesi
  `ortaknokta://join/g/<kod>` ile uygulamayı açar. Linkin doğrudan uygulamada açılması için:
  - sitede `/.well-known/assetlinks.json` (Android) ve `apple-app-site-association` (iOS) dosyaları;
  - manifest ve entitlement ayarları.

  Bunun için önce paket adı ve imzalama anahtarı kesinleşmeli.
- **Web'de telefon bildirimi:** Şu an yalnızca Android ve iOS'ta var; site ve web hali bildirim
  kutusunu kullanır. Eklemek için Firebase'de bir Web Push sertifikası (VAPID) ve sitede bir
  service worker gerekir.
- **Mağaza linkleri:** Uygulama yayınlanınca `site/src/Landing.jsx` içindeki `Download` bölümündeki
  rozetler "Yakında" yerine mağaza adresine bağlanır.
- **Kötüye kullanım:** `create_group` kişi başı günde 20 ile sınırlı. Daha fazlası gerekirse Supabase'de
  hız sınırı ya da Cloudflare Turnstile eklenebilir.
