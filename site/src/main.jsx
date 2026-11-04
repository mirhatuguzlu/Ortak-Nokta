import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { routeOf } from './api.js'
import Landing from './Landing.jsx'
import Join from './Join.jsx'
import Privacy from './Privacy.jsx'
import './styles.css'

// Üç sayfa için yönlendirici kütüphanesi gereksiz; GitHub Pages 404.html ile her adresi buraya düşürür.
const route = routeOf(location.pathname, import.meta.env.BASE_URL)
const page = route.page === 'join' ? <Join groupId={route.id} /> : route.page === 'privacy' ? <Privacy /> : <Landing />

createRoot(document.getElementById('root')).render(<StrictMode>{page}</StrictMode>)
