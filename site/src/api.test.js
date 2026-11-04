import { test } from 'node:test'
import assert from 'node:assert/strict'
import { parseId, placeLabel, routeOf, rpcMessage } from './api.js'

const id = '3f2b8c1e-9a4d-4e6f-b1c2-0d9e8f7a6b5c'

test('davet adresleri', () => {
  assert.deepEqual(routeOf(`/g/${id}`), { page: 'join', id })
  assert.deepEqual(routeOf(`/Ortak-Nokta/g/${id.toUpperCase()}`, '/Ortak-Nokta/'), { page: 'join', id })
  assert.deepEqual(routeOf('/g/abc'), { page: 'home' })
  assert.deepEqual(routeOf(`/x/${id}`), { page: 'home' })
  assert.deepEqual(routeOf('/gizlilik'), { page: 'privacy' })
  assert.equal(parseId(`link: https://site/g/${id}`), id)
  assert.equal(parseId(null), null)
})

test('sunucu hataları kullanıcıya anlaşılır gelir', () => {
  assert.match(rpcMessage(400, 'group_full'), /5 kişi/)
  assert.match(rpcMessage(500, 'secret internal detail'), /\(500\)/)
})

test('adres etiketi kısa kalır', () => {
  assert.equal(placeLabel({ name: 'Moda Sahili', display_name: 'Moda Sahili, Moda, Kadıköy, İstanbul, Türkiye' }), 'Moda Sahili, Moda, Kadıköy')
  assert.equal(placeLabel({ display_name: 'Bağdat Caddesi, Kadıköy, İstanbul, Türkiye' }), 'Bağdat Caddesi, Kadıköy, İstanbul')
})
