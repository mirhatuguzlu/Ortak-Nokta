import { useEffect, useState } from 'react'
import { ApiError, MODES, appLink, currentPosition, groupMembers, invitesReady, joinGroup, searchPlaces } from './api.js'
import { Icon, Logo } from './parts.jsx'

const message = (e) => (e instanceof ApiError ? e.message : 'Bir şeyler ters gitti. Tekrar dener misin?')

/** Davet linkini açan kişi: adını, nereden ve nasıl geleceğini ekler. Uygulamadaki JoinScreen'in web hali. */
export default function Join({ groupId }) {
  const [members, setMembers] = useState(null)
  const [fatal, setFatal] = useState(invitesReady ? null : 'Davet özelliği henüz açılmadı.')
  const [joined, setJoined] = useState(false)

  useEffect(() => {
    if (!invitesReady) return
    let alive = true
    const tick = () =>
      groupMembers(groupId)
        .then((m) => alive && setMembers(m))
        .catch((e) => {
          // Davet yoksa bunu göster; geçici ağ hatasında bir sonraki turu bekle.
          if (alive && /bulunamadı/.test(e.message)) setFatal(e.message)
        })
    tick()
    const t = setInterval(tick, 4000)
    return () => {
      alive = false
      clearInterval(t)
    }
  }, [groupId])

  const host = members?.[0]?.name

  return (
    <div className="join-page">
      <header className="join-top">
        <Logo />
        <a className="link" href={appLink(groupId)}>
          Uygulaman varsa orada aç
        </a>
      </header>
      <main className="join-card">
        {fatal ? (
          <div className="join-done">
            <h1>Bu davet açılamadı</h1>
            <p>{fatal}</p>
          </div>
        ) : joined ? (
          <div className="join-done">
            <span className="big-check">
              <Icon name="check" size={34} />
            </span>
            <h1>Tamam, gruptasın</h1>
            <p>
              {host ?? 'Grubu kuran kişi'} herkes katılınca ortak noktayı bulup grupla paylaşacak. Bu sayfayı kapatabilirsin.
            </p>
          </div>
        ) : (
          <JoinForm groupId={groupId} host={host} onJoined={() => setJoined(true)} />
        )}
        {members?.length > 0 && (
          <section className="members">
            <h2>
              Grupta şimdiden {members.length} kişi var <small>(en fazla 5)</small>
            </h2>
            <ul>
              {members.map((m) => (
                <li key={m.id}>
                  <Icon name={m.mode} size={20} />
                  <b>{m.name}</b>
                  <span>{m.label}</span>
                </li>
              ))}
            </ul>
          </section>
        )}
      </main>
    </div>
  )
}

function JoinForm({ groupId, host, onJoined }) {
  const [name, setName] = useState('')
  const [mode, setMode] = useState('walk')
  const [place, setPlace] = useState(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)

  async function submit(e) {
    e.preventDefault()
    if (!name.trim()) return setError('Önce adını yaz.')
    if (!place) return setError('Nereden geleceğini seç.')
    setBusy(true)
    setError(null)
    try {
      await joinGroup(groupId, name.trim(), mode, place)
      onJoined()
    } catch (e) {
      setError(message(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={submit} noValidate>
      <p className="hand">sana bir davet var</p>
      <h1>{host ? `${host} seni bir buluşmaya çağırıyor` : 'Bir buluşmaya çağrıldın'}</h1>
      <p className="muted">
        Nereden ve nasıl geleceğini yaz; Ortak Nokta herkesin yol süresine bakıp kimseyi fazla yormayan yeri bulsun.
      </p>

      <label className="field">
        <span>Adın</span>
        <input value={name} onChange={(e) => setName(e.target.value)} maxLength={30} autoComplete="given-name" placeholder="Örneğin Zeynep" />
      </label>

      <PlacePicker place={place} onPick={setPlace} disabled={busy} />

      <fieldset className="field">
        <legend>Nasıl geleceksin?</legend>
        <div className="choices">
          {Object.entries(MODES).map(([key, label]) => (
            <label key={key} className={mode === key ? 'choice on' : 'choice'}>
              <input type="radio" name="mode" value={key} checked={mode === key} onChange={() => setMode(key)} />
              <Icon name={key} size={22} />
              {label}
            </label>
          ))}
        </div>
      </fieldset>

      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      <button className="btn btn-primary btn-block" disabled={busy}>
        {busy ? 'Ekleniyor…' : 'Gruba katıl'}
      </button>
      <p className="fine">Konumun yalnızca bu gruptakilerle buluşma noktasını hesaplamak için kullanılır ve 24 saat içinde silinir.</p>
    </form>
  )
}

function PlacePicker({ place, onPick, disabled }) {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)

  async function run(job) {
    setBusy(true)
    setError(null)
    try {
      await job()
    } catch (e) {
      setError(message(e))
    } finally {
      setBusy(false)
    }
  }

  const search = () => {
    if (query.trim().length < 3) return setError('En az 3 harf yaz.')
    run(async () => setResults(await searchPlaces(query)))
  }

  if (place) {
    return (
      <div className="field">
        <span>Nereden geleceksin?</span>
        <div className="picked">
          <Icon name="pin" size={22} />
          <span>{place.label}</span>
          <button type="button" className="link" onClick={() => onPick(null)} disabled={disabled}>
            Değiştir
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="field">
      <span>Nereden geleceksin?</span>
      <div className="search">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault()
              search()
            }
          }}
          maxLength={100}
          placeholder="Semt, adres ya da mekan"
          aria-label="Adres ara"
        />
        <button type="button" className="btn btn-quiet" onClick={search} disabled={busy}>
          Ara
        </button>
      </div>
      <button type="button" className="link locate" onClick={() => run(async () => onPick(await currentPosition()))} disabled={busy}>
        <Icon name="locate" size={18} /> Bulunduğum yeri kullan
      </button>
      {busy && <p className="muted">Bakıyorum…</p>}
      {error && <p className="error">{error}</p>}
      {results?.length === 0 && !busy && <p className="muted">Bir şey bulamadım. Biraz farklı yazmayı dener misin?</p>}
      {results?.length > 0 && (
        <ul className="results">
          {results.map((p) => (
            <li key={`${p.lat},${p.lon}`}>
              <button type="button" onClick={() => onPick(p)}>
                <Icon name="pin" size={18} />
                {p.label}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
