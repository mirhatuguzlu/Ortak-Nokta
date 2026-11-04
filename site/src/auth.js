// Google ile giriş (Supabase Auth, PKCE). Uygulamadaki lib/ui/auth_screens.dart'ın web hali.
import { createClient } from '@supabase/supabase-js'
import { invitesReady, setTokenProvider, supabaseKey, supabaseUrl } from './api.js'

export const supabase = invitesReady
  ? createClient(supabaseUrl, supabaseKey, { auth: { flowType: 'pkce', detectSessionInUrl: true, persistSession: true } })
  : null

setTokenProvider(async () => (await supabase?.auth.getSession())?.data.session?.access_token ?? null)

/** Girişten sonra aynı davet sayfasına dönülür. */
export const signInWithGoogle = () =>
  supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: window.location.origin + window.location.pathname, queryParams: { prompt: 'select_account' } },
  })

export const signOut = () => supabase.auth.signOut()
