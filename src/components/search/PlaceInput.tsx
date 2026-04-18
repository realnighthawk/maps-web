import type { ReactNode } from 'react'
import {
  useCallback,
  useEffect,
  useId,
  useRef,
  useState,
} from 'react'
import { useApiIsLoaded, useMapsLibrary } from '@vis.gl/react-google-maps'
import type { Place } from '../../stores/routeStore'
import { resolvePlaceFromDeviceGeolocation } from '../../utils/deviceOriginPlace'

interface PlaceInputProps {
  id?: string
  placeholder: string
  value: Place | null
  onChange: (place: Place | null) => void
  onEnter?: () => void
  onEscape?: () => void
  /** Crosshair control to fill from device GPS + reverse geocode (e.g. Origin only). */
  showMyLocationButton?: boolean
  /** Extra control in the trailing column (e.g. swap origin/destination on the destination row). */
  trailingAction?: ReactNode
}

function geolocationErrorMessage(code: number): string {
  switch (code) {
    case 1:
      return 'Location access denied. Allow location for this site in your browser settings.'
    case 2:
      return 'Could not determine your position. Try again or pick a place on the list.'
    case 3:
      return 'Location timed out (high accuracy). Allow location, go outdoors, or search for an address instead.'
    default:
      return 'Could not get your location.'
  }
}

export function PlaceInput({
  id: idProp,
  placeholder,
  value,
  onChange,
  onEnter,
  onEscape,
  showMyLocationButton = false,
  trailingAction,
}: PlaceInputProps) {
  const autoId = useId()
  const id = idProp ?? autoId
  const mapsApiLoaded = useApiIsLoaded()
  const places = useMapsLibrary('places')
  const geocodingLib = useMapsLibrary('geocoding')
  const [text, setText] = useState(value?.name ?? '')
  const [open, setOpen] = useState(false)
  const [locating, setLocating] = useState(false)
  const [geoError, setGeoError] = useState<string | null>(null)
  /** Shown when GPS worked but street address lookup failed (user was falling back to raw coords). */
  const [geoHint, setGeoHint] = useState<string | null>(null)
  const [predictions, setPredictions] = useState<
    google.maps.places.PlacePrediction[]
  >([])
  const sessionRef = useRef<google.maps.places.AutocompleteSessionToken | null>(
    null,
  )
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const listRef = useRef<HTMLUListElement>(null)
  const fetchSeqRef = useRef(0)

  useEffect(() => {
    setText(value?.name ?? '')
  }, [value?.name, value?.lat, value?.lng])

  useEffect(() => {
    if (places) {
      sessionRef.current = new google.maps.places.AutocompleteSessionToken()
    }
  }, [places])

  const runPredictions = useCallback(
    async (input: string) => {
      if (!places || input.trim().length < 2) {
        setPredictions([])
        return
      }
      const seq = ++fetchSeqRef.current
      try {
        const { suggestions } =
          await google.maps.places.AutocompleteSuggestion.fetchAutocompleteSuggestions(
            {
              input: input.trim(),
              sessionToken: sessionRef.current ?? undefined,
            },
          )
        if (seq !== fetchSeqRef.current) return
        const preds = suggestions
          .map((s) => s.placePrediction)
          .filter((p): p is google.maps.places.PlacePrediction => p != null)
        setPredictions(preds)
      } catch {
        if (seq === fetchSeqRef.current) setPredictions([])
      }
    },
    [places],
  )

  const onInputChange = (v: string) => {
    setText(v)
    setOpen(true)
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => void runPredictions(v), 200)
  }

  const selectPrediction = useCallback(
    async (p: google.maps.places.PlacePrediction) => {
      if (!places) return
      try {
        const { place } = await p.toPlace().fetchFields({
          fields: ['location', 'displayName', 'formattedAddress'],
        })
        const loc = place.location
        if (!loc) return
        const lat = loc.lat()
        const lng = loc.lng()
        const name =
          place.displayName ?? place.formattedAddress ?? p.text.text
        onChange({
          name,
          lat,
          lng,
          placeId: place.id,
        })
        setText(name)
        setOpen(false)
        setPredictions([])
        sessionRef.current = new google.maps.places.AutocompleteSessionToken()
      } catch {
        /* ignore — keep current text */
      }
    },
    [places, onChange],
  )

  const useMyLocation = useCallback(() => {
    setGeoError(null)
    setGeoHint(null)
    if (!mapsApiLoaded) {
      setGeoError('Map is still loading. Try again in a moment.')
      return
    }
    if (!geocodingLib) {
      setGeoError('Address lookup is still loading. Wait a second and try again.')
      return
    }
    if (!navigator.geolocation) {
      setGeoError('This browser does not support location.')
      return
    }

    setLocating(true)
    void (async () => {
      try {
        const { place, geoHint } = await resolvePlaceFromDeviceGeolocation()
        onChange(place)
        setText(place.name)
        setOpen(false)
        setPredictions([])
        setGeoHint(geoHint)
      } catch (err) {
        const code =
          err && typeof err === 'object' && 'code' in err
            ? Number((err as GeolocationPositionError).code)
            : 0
        setGeoError(geolocationErrorMessage(code))
      } finally {
        setLocating(false)
      }
    })()
  }, [mapsApiLoaded, geocodingLib, onChange])

  return (
    <div>
      <div className="flex gap-1.5">
        <div className="relative min-w-0 flex-1">
          <input
            id={id}
            type="text"
            autoComplete="off"
            placeholder={placeholder}
            value={text}
            onChange={(e) => {
              setGeoError(null)
              setGeoHint(null)
              onInputChange(e.target.value)
            }}
            onFocus={() => setOpen(true)}
            onBlur={() => {
              window.setTimeout(() => setOpen(false), 180)
            }}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault()
                if (open && predictions[0]) void selectPrediction(predictions[0]!)
                else onEnter?.()
              }
              if (e.key === 'Escape') {
                e.preventDefault()
                onEscape?.()
                setOpen(false)
              }
            }}
            className="w-full rounded-lg border border-slate-200 bg-white/95 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-blue-500/30 placeholder:text-slate-400 focus:border-blue-500 focus:ring-2 dark:border-slate-600 dark:bg-slate-900/95 dark:text-slate-100 dark:placeholder:text-slate-500"
          />
          {open && predictions.length > 0 && (
            <ul
              ref={listRef}
              className="absolute left-0 right-0 top-full z-50 mt-1 max-h-52 overflow-auto rounded-lg border border-slate-200 bg-white py-1 text-sm shadow-lg dark:border-slate-600 dark:bg-slate-900"
              role="listbox"
            >
              {predictions.map((p) => (
                <li key={p.placeId}>
                  <button
                    type="button"
                    className="w-full px-3 py-2 text-left text-slate-800 hover:bg-slate-100 dark:text-slate-100 dark:hover:bg-slate-800"
                    onMouseDown={(e) => e.preventDefault()}
                    onClick={() => void selectPrediction(p)}
                  >
                    {p.text.text}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
        {showMyLocationButton ? (
          <button
            type="button"
            onClick={() => void useMyLocation()}
            disabled={locating || !geocodingLib}
            title={
              !geocodingLib
                ? 'Loading address lookup…'
                : 'Use your current location'
            }
            aria-label="Use your current location"
            className="flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-lg border border-slate-200 bg-white/95 text-slate-600 shadow-sm transition hover:border-blue-400 hover:bg-slate-50 hover:text-blue-600 disabled:cursor-not-allowed disabled:opacity-50 dark:border-slate-600 dark:bg-slate-900/95 dark:text-slate-300 dark:hover:border-blue-500 dark:hover:bg-slate-800 dark:hover:text-blue-400"
          >
            {locating ? (
              <span
                className="h-4 w-4 animate-spin rounded-full border-2 border-slate-300 border-t-blue-500 dark:border-slate-600 dark:border-t-blue-400"
                aria-hidden
              />
            ) : (
              <svg
                className="h-5 w-5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth={2.25}
                strokeLinecap="round"
                aria-hidden
              >
                {/* Classic “my location” GPS target (ring + dot + cardinal ticks) */}
                <circle cx="12" cy="12" r="4.5" />
                <line x1="12" y1="2.25" x2="12" y2="6.5" />
                <line x1="12" y1="21.75" x2="12" y2="17.5" />
                <line x1="2.25" y1="12" x2="6.5" y2="12" />
                <line x1="21.75" y1="12" x2="17.5" y2="12" />
                <circle cx="12" cy="12" r="2" fill="currentColor" stroke="none" />
              </svg>
            )}
          </button>
        ) : null}
        {trailingAction ?? null}
      </div>
      {geoError ? (
        <p className="mt-1 text-xs text-red-600 dark:text-red-400" role="alert">
          {geoError}
        </p>
      ) : null}
      {geoHint ? (
        <p
          className="mt-1 text-xs text-amber-800 dark:text-amber-200/90"
          role="status"
        >
          {geoHint}
        </p>
      ) : null}
    </div>
  )
}
