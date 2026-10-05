import { ClerkProvider, SignIn, SignedIn, SignedOut, useAuth } from '@clerk/clerk-react'
import { useEffect, type ReactNode } from 'react'
import { getClerkPublishableKey, isRouterMode } from '../config/mapsEngine'
import { setTokenGetter } from './token'

/** Hands Clerk's token getter to the API client for as long as the user is signed in. */
function AuthBridge({ children }: { children: ReactNode }) {
  const { getToken } = useAuth()
  useEffect(() => {
    setTokenGetter(() => getToken())
    return () => setTokenGetter(null)
  }, [getToken])
  return <>{children}</>
}

/**
 * With a router configured, the app is only for signed-in people: their drives live in their own maps-engine
 * instance, reached through the router with a Clerk session token. Without one (local dev against an engine
 * directly), there is no sign-in and the app renders as before.
 */
export function AuthGate({ children }: { children: ReactNode }) {
  if (!isRouterMode()) {
    // Only a dev server talks to an engine directly. A deployed build must be behind the router and Clerk.
    if (import.meta.env.PROD) {
      return (
        <div className="flex h-screen items-center justify-center bg-slate-100 p-6 text-center text-sm text-slate-600 dark:bg-slate-950 dark:text-slate-300">
          This build has no VITE_ROUTER_ORIGIN, so it can't sign you in or reach your maps engine.
        </div>
      )
    }
    return <>{children}</>
  }

  const key = getClerkPublishableKey()
  if (!key) {
    return (
      <div className="flex h-screen items-center justify-center bg-slate-100 p-6 text-center text-sm text-slate-600 dark:bg-slate-950 dark:text-slate-300">
        VITE_ROUTER_ORIGIN is set, but VITE_CLERK_PUBLISHABLE_KEY is not, so there is no way to sign in.
      </div>
    )
  }
  return (
    <ClerkProvider publishableKey={key}>
      <SignedOut>
        <div className="flex h-screen items-center justify-center bg-slate-100 dark:bg-slate-950">
          <SignIn routing="hash" />
        </div>
      </SignedOut>
      <SignedIn>
        <AuthBridge>{children}</AuthBridge>
      </SignedIn>
    </ClerkProvider>
  )
}
