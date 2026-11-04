// Ortak Nokta: yeni bildirimi kişinin telefonlarına Firebase Cloud Messaging (HTTP v1) ile gönderir.
// Tetikleyen: Database Webhook (public.notifications, INSERT). Kurulum: SETUP.md > Bildirimler.
//
// Gizli değerler (Edge Functions > Secrets):
//   FCM_SERVICE_ACCOUNT  Firebase'den indirilen hizmet hesabı JSON'unun tamamı
//   PUSH_WEBHOOK_SECRET  Webhook'un x-webhook-secret başlığında gönderdiği rastgele metin
//   PUSH_SECRET_KEY      (isteğe bağlı) eski service_role anahtarı kapalıysa yeni bir sb_secret_... anahtarı
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından kendiliğinden verilir.
import { createClient } from 'npm:@supabase/supabase-js@2.49.4'
import { JWT } from 'npm:google-auth-library@10'

interface Notification {
  id: string
  user_id: string
  group_id: string | null
  kind: string
  title: string
  body: string
  push: boolean
}

const account = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '{}')
const secret = Deno.env.get('PUSH_WEBHOOK_SECRET') ?? ''
const db = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('PUSH_SECRET_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)
const google = new JWT({
  email: account.client_email,
  key: account.private_key,
  scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
})

Deno.serve(async (req) => {
  // JWT doğrulaması kapalı (webhook kullanıcı oturumu taşımaz); yerine ortak gizli değer.
  if (!secret || req.headers.get('x-webhook-secret') !== secret) return new Response('forbidden', { status: 403 })

  const { type, record } = (await req.json()) as { type: string; record: Notification }
  if (type !== 'INSERT' || !record?.push) return Response.json({ skipped: true })

  const { data: devices, error } = await db.from('devices').select('token').eq('user_id', record.user_id)
  if (error) return Response.json({ error: error.message }, { status: 500 })
  if (!devices?.length) return Response.json({ sent: 0 })

  const { token: access } = await google.getAccessToken()
  // Aynı grubun aynı türdeki bildirimleri telefonda üst üste binmez, birbirinin yerine geçer.
  const tag = `${record.group_id ?? 'app'}:${record.kind}`.slice(0, 64)
  let sent = 0
  for (const { token } of devices) {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${access}` },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: record.title, body: record.body },
          data: { group_id: record.group_id ?? '', kind: record.kind, id: record.id },
          android: { priority: 'high', notification: { tag } },
          apns: { headers: { 'apns-collapse-id': tag } },
        },
      }),
    })
    if (res.ok) sent++
    // 404: uygulama silinmiş ya da anahtar yenilenmiş; bir daha denenmesin.
    else if (res.status === 404) await db.from('devices').delete().eq('token', token)
    else console.error('FCM', res.status, await res.text())
  }
  return Response.json({ sent })
})
