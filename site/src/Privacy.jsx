import { Footer, Header } from './parts.jsx'

// Mağaza başvurularında da istenen gizlilik metni.
// shortcut: hukuki inceleme yapılmadı; yayından önce KVKK açısından bir avukata okut.
const sections = [
  [
    'Hangi verileri işliyoruz?',
    'Buluşma noktasını hesaplamak için girdiğin başlangıç konumları, ulaşım aracı ve kişi adları. Davet linki, ortak liste ve hesap için Google ile giriş yapılır: Google hesabının e-posta adresi ve seçtiğin isim tutulur. Telefon numarası veya reklam kimliği toplanmaz.',
  ],
  [
    'Veriler nereye gönderiliyor?',
    'Konumlar yalnızca rota ve süre hesabı için OpenStreetMap tabanlı servislere gönderilir: OSRM (FOSSGIS e.V., Almanya), Nominatim, Overpass API ve Photon (komoot, Almanya); buluşma noktasının yaklaşık konumu hava tahmini için Open-Meteo’ya (İsviçre) gönderilir. Bu servisler isteği yanıtlamak için işler; Ortak Nokta bu verileri kendi sunucusunda saklamaz.',
  ],
  [
    'Davet linkleri',
    'Davet linki kullandığında gruptaki kişilerin adı, aracı ve başlangıç konumu ile grubun ortak listesi, masrafları ve buluşma yeri notu sunucumuzda (Supabase, Frankfurt) tutulur. Konumlara yalnızca giriş yapmış ve linke sahip olanlar, liste ve masraflara yalnızca grubun üyeleri erişebilir. E-posta adresin yalnızca grupta seninle aynı isimde biri varsa, sizi ayırt etmek için o grubun üyelerine gösterilir. Grup ve içindekiler 7 gün sonra otomatik olarak silinir.',
  ],
  [
    'Cihazında kalanlar',
    'Kaydettiğin buluşmalar ("Adalet defteri") ve tercihlerin yalnızca telefonunda tutulur. Uygulama içinden istediğin an silebilirsin.',
  ],
  [
    'Hesabını silmek',
    'Uygulamada Hesabım > Hesabımı sil ile profilin ve grup üyeliklerin kalıcı olarak silinir. Başkalarının masraf kayıtlarındaki tutarlar, onların hesabı bozulmasın diye isimsiz olarak kalır.',
  ],
  ['Konum izni', '"Konumum" düğmesine bastığında bir kez konum alınır. Uygulama arka planda konum izlemez.'],
]

export default function Privacy() {
  return (
    <>
      <Header />
      <main className="wrap prose">
        <h1>Gizlilik</h1>
        <p className="lead">Kısaca: hesap yok, reklam yok, konumların satılmaz ve saklanmaz.</p>
        {sections.map(([t, b]) => (
          <section key={t}>
            <h2>{t}</h2>
            <p>{b}</p>
          </section>
        ))}
      </main>
      <Footer />
    </>
  )
}
