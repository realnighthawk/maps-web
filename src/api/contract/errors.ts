/** Mirrors maps-engine `apiErrorBody` / `apiErrorResponse` JSON. */
export interface ApiErrorBody {
  code: string
  message: string
  details?: Record<string, unknown>
}

export interface ApiErrorResponse {
  error: ApiErrorBody
}

export function isApiErrorResponse(v: unknown): v is ApiErrorResponse {
  if (v === null || typeof v !== 'object') return false
  const e = (v as { error?: unknown }).error
  if (e === null || typeof e !== 'object') return false
  const msg = (e as { message?: unknown }).message
  return typeof msg === 'string'
}
