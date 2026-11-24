import { useEffect, useRef } from 'react'
import { BASE, Footer, Header, Icon } from './parts.jsx'

export default function Landing() {
  return (
    <>
      <Header />
      <main>
        <PillHero />
        <Hero />
        <Story />
        <How />
        <Details />
        <Invite />
        <Privacy />
        <Faq />
        <Download />
      </main>
      <Footer />
    </>
  )
}

// MotionSites "Wild Pill": a hairline between the two words opens into a window — the common point itself.
// Free background loop from motionsites.ai/backgrounds ("Lakeside Gathering").
const PILL_VIDEO =
  'https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260323_071151_38c3924f-c312-48af-a196-3fbb80e4226f.mp4'

function PillHero() {
  const root = useRef(null)

  useEffect(() => {
    const el = root.current
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const $ = (s) => el.querySelector(s)
    const stacked = matchMedia('(max-width: 720px)').matches
    const ease = ['cubic-bezier(.5,0,.3,1)', 'cubic-bezier(.45,0,.3,1)', 'cubic-bezier(.4,0,.2,1)']
    const anims = []
    const play = (node, frames, opts) => anims.push(node.animate(frames, { duration: 2100, fill: 'both', ...opts }))

    // Desktop opens sideways, a phone opens top-to-bottom; same hairline → slit → circle → pill curve.
    const pill = $('.pill')
    const size = stacked ? 'height' : 'width'
    const full = stacked ? pill.offsetHeight : pill.offsetWidth
    const circle = stacked ? Math.min(full, pill.offsetWidth) : pill.offsetHeight
    play(pill, [
      { [size]: '2px', clipPath: stacked ? 'inset(0 50%)' : 'inset(50% 0)', offset: 0, easing: ease[0] },
      { [size]: '2px', clipPath: 'inset(0)', offset: 0.14, easing: ease[0] },
      { [size]: `${full * 0.1}px`, offset: 0.3, easing: ease[1] },
      { [size]: `${circle}px`, offset: 0.58, easing: ease[2] },
      { [size]: `${full}px`, clipPath: 'inset(0)', offset: 1 },
    ])
    play($('.pill-line'), [{ opacity: 1 }, { opacity: 1, offset: 0.14 }, { opacity: 0, offset: 0.3 }, { opacity: 0 }])
    play($('.pill-bg'), [{ opacity: 0 }, { opacity: 0, offset: 0.45 }, { opacity: 1, offset: 0.78 }, { opacity: 1 }])
    const settle = { easing: 'cubic-bezier(.2,.8,.2,1)' }
    play($('.pill-note'), [{ opacity: 0, translate: '0 -30px' }, { opacity: 0, offset: 0.5 }, { opacity: 1, translate: '0 0', offset: 0.86 }, { opacity: 1, translate: '0 0' }], settle)
    play($('.pill-foot'), [{ opacity: 0, translate: '0 60px' }, { opacity: 0, offset: 0.52 }, { opacity: 1, translate: '0 0', offset: 0.9 }, { opacity: 1, translate: '0 0' }], settle)
    play($('.pill-rule'), [{ transform: 'scaleX(0)' }, { transform: 'scaleX(0)', offset: 0.4 }, { transform: 'scaleX(1)', offset: 0.95 }, { transform: 'scaleX(1)' }])
    // A finished fill would pin the pill in px; hand sizing back to CSS so resizing still works.
    Promise.all(anims.map((a) => a.finished)).then(() => anims.forEach((a) => a.cancel()), () => {})
    return () => anims.forEach((a) => a.cancel())
  }, [])

  return (
    <section className="pill-hero" ref={root}>
      <svg className="pill-bg" viewBox="0 0 1440 900" preserveAspectRatio="none" aria-hidden="true">
        {Array.from({ length: 12 }, (_, i) => (
          <path
            key={i}
            d={`M-60 ${820 - i * 46} C 320 ${700 - i * 60}, 640 ${980 - i * 70}, 1500 ${360 - i * 52}`}
            strokeWidth={1.2 + (i % 4) * 0.8}
            opacity={0.55 + (i % 3) * 0.12}
          />
        ))}
      </svg>
      <p className="hand pill-note">cumartesi kahvesi nerede içilsin?</p>
      <h1 className="pill-word">
        <span>Ortak</span>
        <span className="pill" aria-hidden="true">
          <video src={PILL_VIDEO} autoPlay muted loop playsInline preload="auto" />
          <i className="pill-line" />
        </span>
        <span>Nokta</span>
      </h1>
      <div className="pill-foot wrap">
        <p className="dropcap">
          Biri yürüyerek, biri arabayla geliyor. Ortak Nokta ikisinin de aşağı yukarı aynı sürede vardığı yeri bulur.
        </p>
        <span className="pill-rule" aria-hidden="true" />
        <a className="btn btn-primary" href="#harita">
          Adil noktayı gör
        </a>
      </div>
    </section>
  )
}

function Hero() {
  return (
    <section className="hero wrap" id="harita">
      <div className="hero-text">
        <h2>
          Ortada değil, <em>adil</em> buluşun.
        </h2>
        <p className="lead">
          Haritanın tam ortası, biri yürüyüp öteki arabayla gelirken hiç de orta sayılmaz. Ortak Nokta herkesin gerçek
          yol süresine bakar ve kimsenin ötekinden fazla yol yapmadığı yeri bulur.
        </p>
        <div className="hero-actions">
          <a className="btn btn-primary" href="#nasil">
            Nasıl işlediğini gör
          </a>
          <span className="quiet">Ücretsiz · Google ile tek dokunuş · reklam yok</span>
        </div>
      </div>
      <HeroMap />
    </section>
  )
}

/** Elle çizilmiş havası olan küçük bir harita: kuş uçumu orta nokta ile adil nokta yan yana. */
function HeroMap() {
  return (
    <figure className="hero-map" aria-label="Ayşe yürüyerek, Can araçla geliyor; adil nokta ikisine de yaklaşık 25 dakika">
      <svg viewBox="0 0 520 440" role="img">
        <rect x="0" y="0" width="520" height="440" rx="28" fill="var(--paper-2)" />
        <path d="M0 300 C 120 280, 180 350, 300 330 S 470 270, 520 290 L520 440 L0 440Z" fill="var(--water)" />
        <g stroke="var(--road)" strokeWidth="14" fill="none" strokeLinecap="round">
          <path d="M40 60 C 140 90, 220 70, 300 110 S 440 120, 500 90" />
          <path d="M120 20 C 130 120, 150 180, 140 270" />
          <path d="M360 30 C 350 110, 380 170, 400 260" />
          <path d="M60 200 C 180 210, 300 190, 470 210" />
        </g>
        <g fill="var(--block)">
          <rect x="180" y="120" width="70" height="52" rx="10" />
          <rect x="270" y="135" width="56" height="40" rx="10" />
          <rect x="40" y="100" width="60" height="70" rx="10" />
          <rect x="420" y="140" width="62" height="50" rx="10" />
          <rect x="200" y="225" width="90" height="40" rx="10" />
        </g>
        {/* rotalar */}
        <path d="M86 238 C 110 210, 130 200, 168 204" stroke="var(--clay)" strokeWidth="5" fill="none" strokeLinecap="round" strokeDasharray="2 10" />
        <path d="M440 70 C 400 100, 380 150, 330 190 S 210 205, 176 204" stroke="var(--green)" strokeWidth="5" fill="none" strokeLinecap="round" />
        {/* kuş uçumu orta nokta */}
        <line x1="86" y1="238" x2="440" y2="70" stroke="var(--ink-soft)" strokeWidth="1.5" strokeDasharray="6 6" opacity=".55" />
        <g transform="translate(263 154)" stroke="var(--ink-soft)" strokeWidth="3" strokeLinecap="round">
          <line x1="-8" y1="-8" x2="8" y2="8" />
          <line x1="8" y1="-8" x2="-8" y2="8" />
        </g>
        <text x="282" y="186" className="map-note">haritanın ortası</text>
        <path d="M290 170 q -8 -4 -16 -10" stroke="var(--ink-soft)" fill="none" strokeWidth="1.5" />
        {/* kişiler */}
        <Pin x={86} y={238} color="var(--clay)" label="A" />
        <Pin x={440} y={70} color="var(--green)" label="C" />
        {/* adil nokta */}
        <g transform="translate(172 204)">
          <circle r="22" fill="var(--sun)" opacity=".35" />
          <circle r="11" fill="var(--ink)" />
          <circle r="4" fill="var(--paper)" />
        </g>
        <text x="132" y="172" className="map-note">tam burası</text>
      </svg>
      <figcaption className="ticket">
        <span className="ticket-place">Kahve Durağı, Moda</span>
        <span className="ticket-row">
          <i className="dot clay" /> Ayşe, yürüyerek <b>24 dk</b>
        </span>
        <span className="ticket-row">
          <i className="dot green" /> Can, araçla <b>25 dk</b>
        </span>
      </figcaption>
    </figure>
  )
}

function Pin({ x, y, color, label }) {
  return (
    <g transform={`translate(${x} ${y})`}>
      <circle r="17" fill={color} stroke="var(--paper)" strokeWidth="4" />
      <text y="6" textAnchor="middle" className="pin-label">
        {label}
      </text>
    </g>
  )
}

function Bars({ title, rows, note, tone }) {
  return (
    <div className={`compare ${tone}`}>
      <h3>{title}</h3>
      {rows.map(([who, min]) => (
        <div className="bar-row" key={who}>
          <span>{who}</span>
          <span className="bar">
            <span style={{ width: `${(min / 45) * 100}%` }} />
          </span>
          <b>{min} dk</b>
        </div>
      ))}
      <p>{note}</p>
    </div>
  )
}

function Story() {
  return (
    <section className="story wrap">
      <div className="story-head">
        <h2>Ayşe ile Can'ın bir akşamı</h2>
        <p>
          Ayşe yürüyerek, Can arabayla geliyor. Haritada ikisinin ortasını işaretlemek kolay; ama orta nokta mesafeyi
          böler, zamanı değil. Köprü, trafik, yokuş, deniz: biri hep fazla yol yapar.
        </p>
      </div>
      <div className="story-grid">
        <Bars
          title="Haritanın ortasında buluşsalar"
          tone="bad"
          rows={[
            ['Ayşe', 41],
            ['Can', 9],
          ]}
          note="Can oturmuş çayını içerken Ayşe hâlâ yolda. Arada 32 dakika var."
        />
        <Bars
          title="Ortak Nokta'nın bulduğu yerde"
          tone="good"
          rows={[
            ['Ayşe', 24],
            ['Can', 25],
          ]}
          note="İkisi de aşağı yukarı aynı anda kapıda. Fark bir dakika."
        />
      </div>
    </section>
  )
}

function How() {
  const steps = [
    ['Kim nereden geliyor?', 'Herkesin çıkış noktasını ve nasıl geleceğini ekle. Ya da linki gruba at, herkes kendini eklesin.'],
    ['Gerçek yollar hesaplanır', 'Onlarca aday nokta için herkesin yürüyüş ya da araç süresi ölçülür; araçta saate göre trafik payı da eklenir.'],
    ['Yer ve saat belli olur', 'En adil nokta, çevresindeki kafeler ve herkesin kaçta çıkması gerektiği. Bir dokunuşla gruba gider.'],
  ]
  return (
    <section className="how wrap" id="nasil">
      <h2>Üç adımda biter</h2>
      <ol className="steps">
        {steps.map(([t, d], i) => (
          <li key={t}>
            <span className="step-no">{i + 1}</span>
            <h3>{t}</h3>
            <p>{d}</p>
          </li>
        ))}
      </ol>
    </section>
  )
}

function Details() {
  const items = [
    ['clock', 'Kim kaçta çıksın?', 'Herkes aynı anda varsın diye kişiye özel çıkış saati. Kapıda bekleyen olmaz.'],
    ['cup', 'Yakında ne var?', 'Noktanın çevresindeki kafe, restoran ve parklar. Birini seç, süreler o mekana göre yenilensin.'],
    ['scale', 'Adalet senin tanımın', 'En uzun yolu kısalt, toplam yolu kısalt ya da süreleri eşitle. Grubunuza hangisi uyuyorsa.'],
    ['share', 'Gruba tek görsel', 'Yer, saat ve kimin kaçta çıkacağı tek bir kartta. WhatsApp grubuna atması kolay.'],
  ]
  return (
    <section className="details wrap">
      <div className="details-side">
        <h2>Küçük ama üzerine düşünülmüş ayrıntılar</h2>
        <aside className="notebook">
          <p className="hand">Geçen sefer yine en uzağa Mert gitti…</p>
          <p>
            <b>Dönüşümlü adalet</b> bunu unutmaz. Kaydettiğiniz buluşmalarda kim fazla yol yaptıysa, sıradaki nokta biraz
            onun tarafına kayar. Defter yalnızca senin telefonunda durur.
          </p>
        </aside>
      </div>
      <ul className="detail-list">
        {items.map(([icon, t, d]) => (
          <li key={t}>
            <Icon name={icon} />
            <div>
              <h3>{t}</h3>
              <p>{d}</p>
            </div>
          </li>
        ))}
      </ul>
    </section>
  )
}

function Invite() {
  return (
    <section className="invite">
      <div className="wrap invite-inner">
        <div>
          <h2>Arkadaşının uygulamayı indirmesi gerekmiyor</h2>
          <p>
            Bir link oluştur, gruba at. Herkes tarayıcıdan adını, nereden geleceğini ve nasıl geleceğini ekler. Sen
            katılanları canlı görürsün, herkes geldiğinde nokta hazır.
          </p>
          <ul className="ticks">
            <li>Üyelik yok</li>
            <li>En fazla 5 kişi</li>
            <li>Konumlar 7 gün sonra silinir</li>
          </ul>
        </div>
        <div className="phone" aria-hidden="true">
          <div className="phone-screen">
            <p className="phone-title">Ayşe seni bir buluşmaya çağırıyor</p>
            <span className="phone-field">Adın</span>
            <span className="phone-field">Nereden geleceksin?</span>
            <span className="phone-chips">
              <span className="on">Yürüyerek</span>
              <span>Araçla</span>
            </span>
            <span className="phone-btn">Gruba katıl</span>
          </div>
        </div>
      </div>
    </section>
  )
}

function Privacy() {
  return (
    <section className="trust wrap">
      <h2>Konumun sende kalır</h2>
      <div className="trust-row">
        <p>
          <b>Hesap yok.</b> E-posta, telefon ya da şifre sormuyoruz. Açıp kullanıyorsun.
        </p>
        <p>
          <b>Saklamıyoruz.</b> Konumlar yalnızca yol hesabı için kullanılır; davet grupları 7 günde silinir.
        </p>
        <p>
          <b>Defter cihazında.</b> Kaydettiğin buluşmalar telefonundan çıkmaz, istediğin an silersin.
        </p>
      </div>
      <a className="link" href={`${BASE}gizlilik`}>
        Gizlilik politikasının tamamı →
      </a>
    </section>
  )
}

function Faq() {
  const qa = [
    ['Ücretli mi?', 'Hayır. Ücretsiz ve reklamsız.'],
    [
      'Trafiği hesaba katıyor mu?',
      'Araç süreleri günün saatine göre tahmini bir trafik payıyla artırılır; iş çıkışında daha fazla. Canlı trafik verisi kullanmıyoruz, bu yüzden süreler bir tahmin.',
    ],
    ['Toplu taşıma var mı?', 'Şimdilik yürüyüş ve araç var. Otobüs ve taksi üzerinde çalışıyoruz.'],
    ['Kaç kişiyle kullanabilirim?', 'Bir buluşmada en fazla 5 kişi.'],
    [
      'Hangi harita verisini kullanıyorsunuz?',
      'Açık kaynak OpenStreetMap verisi, OSRM rota motoru ve Overpass mekan verisi. Haritada bir yanlış görürsen OpenStreetMap üzerinden düzeltebilirsin.',
    ],
  ]
  return (
    <section className="faq wrap" id="sorular">
      <h2>Aklına takılanlar</h2>
      <div className="faq-list">
        {qa.map(([q, a]) => (
          <details key={q}>
            <summary>{q}</summary>
            <p>{a}</p>
          </details>
        ))}
      </div>
    </section>
  )
}

function Download() {
  return (
    <section className="download wrap" id="indir">
      <div className="download-box">
        <h2>Bir sonraki buluşma adil olsun</h2>
        <p>Ortak Nokta çok yakında Google Play ve App Store'da.</p>
        <div className="stores">
          <span className="store">
            <small>Yakında</small>Google Play
          </span>
          <span className="store">
            <small>Yakında</small>App Store
          </span>
        </div>
      </div>
    </section>
  )
}
