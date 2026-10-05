import { ApiError } from '../api/client'

/** What to tell a person about a failed request, in plain words. `what` completes "Could not load your …". */
export function describeError(e: unknown, what: string): string {
  if (e instanceof ApiError) {
    // The router answers these itself, before the request reaches your maps-engine.
    if (e.code === 'no_tenant') return "Your maps engine isn't set up yet, so there's nothing to show."
    if (e.status === 401 || e.status === 403) return 'Your sign-in has expired. Reload the page to sign in again.'
  }
  return `Could not load your ${what}.`
}
