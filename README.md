# Ortak Nokta

Kuş uçumu değil, **gerçek yol ağına** ve **herkesin kendi ulaşım aracına** göre adil buluşma noktası bulan Flutter uygulaması.

## Nasıl çalışır
1. 2–5 kişi başlangıç konumunu (adres arama, GPS veya haritadan dokunarak) ve aracını seçer.
2. Ağırlık merkezi etrafında 7×7 aday nokta üretilir (`lib/engine/meeting_engine.dart`).
3. Aynı araçla gelenler için tek bir OSRM `table` isteğiyle her adaya gerçek süre/mesafe alınır.
   Yola 250 m'den uzak adaylar (deniz, park) elenir.
4. **En uzun yolculuğu en kısa** olan aday seçilir (eşitlikte toplam süre). Gerekçeler kullanıcıya gösterilir:
   süreler, kişiler arası fark ve kuş uçumu orta noktaya göre kazanç.

| Araç | Durum |
|------|-------|
| Yürüyüş, şahsi araç | ✅ OSRM (araç süreleri saate göre tahmini trafik katsayısıyla çarpılır) |
| Otobüs, taksi | ⏳ "Yakında" — arayüzde görünür, seçilince bilgi verir |

## Özellikler
- **Adalet modu:** En adil (en uzun yolculuk en kısa), En hızlı (toplam süre en kısa), Eşit süre (fark en az).
- **Kim kaçta çıksın:** Herkesin aynı anda varması için kişiye özel çıkış saati; varış saati seçilebilir.
- **Yakındaki mekanlar:** Adil noktanın 450 m çevresindeki kafe, restoran, bar, park (Overpass API).
  Birine dokununca süreler o mekana göre yeniden hesaplanır.
- **Paylaşım kartı:** Buluşma yeri, süreler ve çıkış saatleri tek görselde (WhatsApp, hikâye).
- **Adalet defteri / dönüşümlü adalet:** Kaydedilen buluşmalarda fazla yol yapan kişi bir sonraki
  seçimde ±%25'e kadar lehine ağırlıklandırılır. Kayıtlar yalnızca cihazda (`shared_preferences`).
- **Davet linki:** Grup kurucusu linki paylaşır, herkes uygulamadan veya web sitesinden kendi konumunu
  ekler (Supabase, 24 saatte silinir). Kurulum: [SETUP.md](SETUP.md).
- **Tanıtım sitesi:** Flutter web, `lib/site/`. Davet linkleri de sitede açılır.

## Yapı
```
lib/config.dart                 servis adresleri (--dart-define ile değiştirilebilir), User-Agent
lib/models.dart                 TravelMode, Place, Participant, Venue
lib/engine/meeting_engine.dart  saf algoritma: aday ızgara, adalet modları, çıkış saatleri, defter (test edilir)
lib/services/osm_api.dart       OSM ağ trafiği tek kapı (OSRM, Nominatim, Overpass)
lib/services/planner.dart       akış: table → seçim → rota → adres
lib/services/group_api.dart     davet grupları (Supabase RPC)
lib/services/history_store.dart adalet defteri ve tercihler (cihazda)
lib/ui/                         uygulama ekranları
lib/site/                       tanıtım sitesi (flutter build web -t lib/site/main.dart)
supabase/schema.sql             davet grupları veritabanı
```
Yeni ulaşım türü eklemek: `TravelMode`'a `osrmUrl` ver (ör. kendi OSRM'inde bisiklet profili) — başka değişiklik gerekmez.
Toplu taşıma için OSRM yetmez; OpenTripPlanner (GTFS) gibi ayrı bir servis gerekir.

## Güvenlik
- Gizli anahtar yok. Supabase `anon` anahtarı herkese açık olacak şekilde tasarlandı ve derleme anında
  `--dart-define` ile verilir (depoda yok). Tablolar anon role kapalı; yalnızca grup kimliği isteyen üç
  fonksiyon açık, böylece kimse tüm konumları listeleyemez.
- Yalnızca HTTPS (`osm_api.dart` kontrolü + Android `usesCleartextTraffic=false` + iOS ATS).
- Tüm yanıtlar şema ve koordinat aralığı kontrolünden geçer, 2 MB sınırı ve 15 sn zaman aşımı var; hatalar kullanıcıya iç ayrıntı sızdırmadan gösterilir.
- Kullanıcı girdisi sınırlı (isim 30, arama 100 karakter). `allowBackup=false`.
- Konum saklanmaz, loglanmaz; yalnızca rota için OSM servislerine gider (uygulama içi "Hakkında" ekranında belirtilir).
- Release derlemesi:
  ```bash
  flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
  ```

## Lisanslar ve kullanım koşulları (kontrol edildi)
| Bileşen | Lisans / Koşul |
|---------|----------------|
| OSM verisi | ODbL — "© OpenStreetMap katkıcıları" atfı **görünür** olmalı (haritada sağ üstte) |
| OSRM | BSD-2 |
| flutter_map | BSD-3 |
| FOSSGIS/OSRM demo sunucusu | ≤1 istek/sn, geçerli User-Agent, "haritayı düzelt" bağlantısı; **ticari olmayan, makul kullanım** |
| Nominatim | ≤1 istek/sn, **otomatik tamamlama yasak** (arama yalnızca "Ara"ya basınca), önbellek zorunlu |
| Overpass API | Makul kullanım (günde <10.000 sorgu); ana sunucu yoğunken yedek örnek denenir, sonuç önbelleğe alınır |
| OSM harita karoları | Belirgin User-Agent, çevrimdışı indirme/ön yükleme yasak |

⚠️ Uygulama büyür veya ticari olursa (reklam, ücretli) kendi OSRM + Nominatim + karo sunucusuna ya da ücretli bir sağlayıcıya geçilmeli. Kod değişmez:
```bash
flutter build appbundle --dart-define=OSRM_CAR_URL=https://... --dart-define=OSRM_FOOT_URL=https://... --dart-define=NOMINATIM_URL=https://... --dart-define=TILE_URL=https://.../{z}/{x}/{y}.png
```

## Geliştirme
```bash
flutter pub get
flutter test
flutter run
```
