export const BASE = import.meta.env.BASE_URL

export function Logo() {
  return (
    <a className="logo" href={BASE} aria-label="Ortak Nokta ana sayfa">
      <svg viewBox="0 0 32 32" width="30" height="30" aria-hidden="true">
        <circle cx="7" cy="22" r="4.5" fill="var(--clay)" />
        <circle cx="25" cy="9" r="4.5" fill="var(--green)" />
        <path d="M10 20 Q 14 17 15.5 16.5 M22 11 Q 18 14 16.5 15.5" stroke="var(--ink)" strokeWidth="2" fill="none" strokeLinecap="round" />
        <circle cx="16" cy="16" r="3.2" fill="var(--ink)" />
      </svg>
      Ortak Nokta
    </a>
  )
}

export function Header() {
  return (
    <header className="top">
      <div className="wrap top-inner">
        <Logo />
        <nav>
          <a href={`${BASE}#nasil`}>Nasıl işliyor</a>
          <a href={`${BASE}#sorular`}>Sorular</a>
          <a className="btn btn-small" href={`${BASE}#indir`}>
            Uygulama
          </a>
        </nav>
      </div>
    </header>
  )
}

export function Footer() {
  return (
    <footer className="foot">
      <div className="wrap foot-inner">
        <Logo />
        <p>İki kişinin arasındaki en adil yolu bulmaya çalışan küçük bir proje.</p>
        <nav>
          <a href={`${BASE}gizlilik`}>Gizlilik</a>
          <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">
            Harita verisi © OpenStreetMap katkıcıları
          </a>
          <span>© {new Date().getFullYear()} Ortak Nokta</span>
        </nav>
      </div>
    </footer>
  )
}

const paths = {
  clock: 'M12 7v5l3 2 M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18',
  cup: 'M4 9h12v5a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5z M16 10h2a2.5 2.5 0 0 1 0 5h-2 M8 3c0 1.5 1 1.5 1 3 M12 3c0 1.5 1 1.5 1 3',
  scale: 'M12 4v16 M7 20h10 M5 8h14 M5 8l-3 6a3 3 0 0 0 6 0z M19 8l-3 6a3 3 0 0 0 6 0z',
  share: 'M12 15V3 M8 7l4-4 4 4 M6 11H5a1 1 0 0 0-1 1v8a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-8a1 1 0 0 0-1-1h-1',
  walk: 'M13 4a1.5 1.5 0 1 0 0 .1 M10 21l2-6 3 3v3 M12 15l-1-5 4 2 2 3 M11 10l-3 2v3',
  car: 'M5 16V12l2-5h10l2 5v4z M5 16v2 M19 16v2 M8 13h.01 M16 13h.01',
  pin: 'M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z M12 7.5a2.5 2.5 0 1 0 0 5a2.5 2.5 0 0 0 0-5',
  locate: 'M12 2v3 M12 19v3 M2 12h3 M19 12h3 M12 6a6 6 0 1 0 0 12a6 6 0 0 0 0-12',
  check: 'M5 12.5l4.5 4.5L19 7',
}

export function Icon({ name, size = 26 }) {
  return (
    <svg className="icon" viewBox="0 0 24 24" width={size} height={size} aria-hidden="true">
      <path d={paths[name]} fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}
