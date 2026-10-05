import { isApiErrorResponse } from './contract/errors'
import { getApiV1Base } from '../config/mapsEngine'
import { getAuthToken } from '../auth/token'

const BASE_URL = getApiV1Base()

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    /** For logging only; UI must not branch on this. */
    public code?: string,
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const token = await getAuthToken()
  const response = await fetch(`${BASE_URL}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options?.headers,
    },
    ...options,
  })

  if (!response.ok) {
    let message = `Request failed with status ${response.status}`
    let code: string | undefined
    try {
      const body: unknown = await response.json()
      if (isApiErrorResponse(body)) {
        message = body.error.message || message
        code = body.error.code
      } else if (body && typeof body === 'object' && typeof (body as { error?: unknown }).error === 'string') {
        // The router's own errors are {"error":"no_tenant"}.
        code = (body as { error: string }).error
        message = code
      }
    } catch {
      // non-JSON error body, use defaults
    }
    throw new ApiError(response.status, message, code)
  }

  return response.json() as Promise<T>
}

export const api = {
  get<T>(path: string): Promise<T> {
    return request<T>(path)
  },
  post<T>(path: string, body: unknown): Promise<T> {
    return request<T>(path, {
      method: 'POST',
      body: JSON.stringify(body),
    })
  },
  put<T>(path: string, body: unknown): Promise<T> {
    return request<T>(path, {
      method: 'PUT',
      body: JSON.stringify(body),
    })
  },
}
