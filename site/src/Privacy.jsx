import { Footer, Header } from './parts.jsx'

// Mağaza başvurularında da istenen gizlilik metni.
// shortcut: hukuki inceleme yapılmadı; yayından önce KVKK açısından bir avukata okut.
const sections = [
  [
    'Hangi verileri işliyoruz?',
    'Buluşma noktasını hesaplamak için girdiğin başlangıç konumları, ulaşım aracı ve kişi adları. Hesap açılmaz; e-posta, telefon numarası veya reklam kimliği toplanmaz.',
  ],
  [
    'Veriler nereye gönderiliyor?',
    'Konumlar yalnızca rota ve süre hesabı için OpenStreetMap tabanlı servislere gönderilir: OSRM (FOSSGIS e.V., Almanya), Nominatim ve Overpass API. Bu servisler isteği yanıtlamak için işler; Ortak Nokta bu verileri kendi sunucusunda saklamaz.',
  ],
  [
    'Davet linkleri',
    'Davet linki kullandığında gruptaki kişilerin adı, aracı ve başlangıç konumu, grubu kuran kişinin ortak noktayı hesaplayabilmesi için sunucumuzda tutulur. Bu bilgilere yalnızca linke sahip olanlar erişebilir ve grup 24 saat sonra otomatik olarak silinir.',
  ],
  [
    'Cihazında kalanlar',
    'Kaydettiğin buluşmalar ("Adalet defteri") ve tercihlerin yalnızca telefonunda tutulur. Uygulama içinden istediğin an silebilirsin.',
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
