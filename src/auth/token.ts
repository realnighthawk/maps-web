/** Where the API client gets the signed-in user's session token. Set once by AuthBridge; null means "no sign-in". */
type TokenGetter = () => Promise<string | null>

let getter: TokenGetter | null = null

export function setTokenGetter(g: TokenGetter | null): void {
  getter = g
}

export async function getAuthToken(): Promise<string | null> {
  return getter ? getter() : null
}
