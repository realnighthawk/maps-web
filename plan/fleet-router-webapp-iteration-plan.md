# Fleet router — web app iteration plan

## Stack decisions

- **Framework:** React 18 + TypeScript
- **Build tool:** Vite
- **Map:** Google Maps via `@vis.gl/react-google-maps` (stay in Google ecosystem — same API key as backend)
- **Styling:** Tailwind CSS (utility-first, fast iteration, good dark mode support)
- **State management:** Zustand (lightweight, no boilerplate — perfect for this scale)
- **HTTP client:** Standard `fetch` with a thin typed wrapper, or `@tanstack/react-query` for caching and loading states
- **Routing:** React Router v6 (minimal — only need a few top-level routes)
- **WebSocket:** Native WebSocket API (for live fleet updates in later iterations)
- **Dev environment:** Vite dev server on `localhost:5173`, proxying API calls to Go backend on `localhost:8080`

### Project structure

```
fleet-router-web/
├── src/
│   ├── main.tsx                     # entry point
│   ├── App.tsx                      # top-level layout + routing
│   ├── api/
│   │   ├── client.ts                # typed fetch wrapper, base URL config
│   │   ├── routes.ts                # route planning API calls
│   │   ├── vehicles.ts              # vehicle endpoints
│   │   ├── fleet.ts                 # fleet state endpoints
│   │   └── types.ts                 # API request/response types (mirrors Go domain types)
│   ├── stores/
│   │   ├── routeStore.ts            # route planning state (origin, dest, planned route, stops)
│   │   ├── mapStore.ts              # map state (center, zoom, selected markers)
│   │   └── appStore.ts              # global app state (active tab, loading states)
│   ├── components/
│   │   ├── map/
│   │   │   ├── MapView.tsx          # full-screen Google Map
│   │   │   ├── RoutePolyline.tsx    # route line on map
│   │   │   ├── ChargerMarker.tsx    # charging stop marker
│   │   │   ├── OriginMarker.tsx     # origin point marker
│   │   │   └── DestMarker.tsx       # destination point marker
│   │   ├── search/
│   │   │   ├── SearchPanel.tsx      # origin + destination input panel
│   │   │   ├── PlaceInput.tsx       # Google Places autocomplete input
│   │   │   └── PlanButton.tsx       # plan route / replan button
│   │   ├── trip/
│   │   │   ├── TripPanel.tsx        # right-side trip summary panel
│   │   │   ├── StatsGrid.tsx        # distance, time, cost stat boxes
│   │   │   ├── StopTimeline.tsx     # origin → stops → destination timeline
│   │   │   ├── FactorTags.tsx       # weather, elevation, traffic tags
│   │   │   └── CostBreakdown.tsx    # cost detail rows
│   │   ├── fleet/
│   │   │   ├── FleetView.tsx        # fleet tab content
│   │   │   └── VehicleCard.tsx      # vehicle summary card
│   │   ├── trips/
│   │   │   ├── TripsView.tsx        # trip history tab content
│   │   │   └── TripRow.tsx          # single trip in history list
│   │   ├── settings/
│   │   │   └── SettingsView.tsx     # settings tab content
│   │   └── shared/
│   │       ├── BottomNav.tsx        # bottom tab bar (Route, Fleet, Trips, Settings)
│   │       ├── LoadingOverlay.tsx   # loading state for route planning
│   │       └── ErrorBanner.tsx      # error display
│   ├── hooks/
│   │   ├── useRoutePlanner.ts       # orchestrates plan route flow
│   │   ├── useMapFit.ts             # auto-fit map bounds to route
│   │   └── useWebSocket.ts          # live fleet updates (later iteration)
│   └── utils/
│       ├── polyline.ts              # decode Google encoded polylines
│       ├── format.ts                # format distance, duration, currency
│       └── geo.ts                   # LatLng helpers, distance calculations
├── public/
├── index.html
├── tailwind.config.ts
├── tsconfig.json
├── vite.config.ts
└── package.json
```

---

## Iteration plan

Each iteration produces a working, visually complete piece of the app. Iterations are ordered so you see something useful on screen as fast as possible.

---

### Iteration 0: Project skeleton + full-screen map

**Goal:** Scaffolded React + TypeScript project with Vite, Tailwind configured, and a full-screen Google Map rendering. The app loads and shows a map centered on San Jose. Nothing else — just the map filling the viewport.

**What to build:**
- Initialize project with Vite React + TypeScript template
- Install and configure Tailwind CSS
- Install `@vis.gl/react-google-maps`
- Create `MapView.tsx` — renders a full-viewport Google Map
- Center on San Jose (37.3382, -121.8863), zoom level 10
- Google Maps API key loaded from environment variable (`VITE_GOOGLE_MAPS_API_KEY`)
- Set up Vite proxy: requests to `/api/*` forward to `http://localhost:8080`
- Create the `api/client.ts` typed fetch wrapper with base URL config

**What to verify:**
- App loads on `localhost:5173`
- Map renders full-screen with no scroll bars or overflow
- Map is interactive (pan, zoom)
- Console shows no errors

**Estimated time:** Half a day

---

### Iteration 1: Search panel + Places autocomplete

**Goal:** The search panel floats over the top-left of the map with origin and destination inputs using Google Places autocomplete. User can type a destination and see suggestions. No route planning yet — just the inputs.

**What to build:**
- Create `SearchPanel.tsx` — floating panel positioned absolute over the map, top-left
- Create `PlaceInput.tsx` — text input wired to Google Places Autocomplete API
  - When user types, show suggestions dropdown
  - When a suggestion is selected, store the place name + lat/lng
  - Style: clean input with subtle border, matches the mockup
- Origin input pre-filled with "Current location" or a default (San Jose)
- Destination input with placeholder "Where to?"
- The dot column between inputs (filled circle → dashed line → square) as visual connector
- Create `routeStore.ts` with Zustand — holds origin and destination as `{ name: string, lat: number, lng: number } | null`
- When destination is selected, drop a red marker on the map at that location
- Create `DestMarker.tsx` and `OriginMarker.tsx` map marker components
- "Plan route" button below the inputs — disabled until destination is set, doesn't do anything yet

**What to verify:**
- Search panel renders cleanly over the map
- Places autocomplete works for both origin and destination
- Selecting a destination drops a marker on the map
- Map auto-pans to show both origin and destination

**Estimated time:** 1 day

---

### Iteration 2: Route planning API integration + route on map

**Goal:** Clicking "Plan route" calls the backend, receives a route plan, and draws the route polyline on the map with charger stop markers. This is the core integration — backend meets frontend.

**What to build:**
- Create `api/types.ts` — TypeScript interfaces mirroring the Go backend response types:
  - `PlanRouteRequest`, `PlanRouteResponse`, `RouteSegment`, `PlannedStop`, `TripCost`, etc.
  - These should exactly match the JSON shapes from the backend's `POST /api/v1/route/plan`
- Create `api/routes.ts` — `planRoute(req: PlanRouteRequest): Promise<PlanRouteResponse>`
- Create `useRoutePlanner.ts` hook:
  - Takes origin and destination from the route store
  - Calls `planRoute()` on the backend
  - Stores the response in the route store
  - Handles loading and error states
- Wire the "Plan route" button to trigger `useRoutePlanner`
- Button shows loading state while request is in flight (spinner or "Planning..." text)
- On success, store the full response in `routeStore`
- Create `RoutePolyline.tsx`:
  - Decode the encoded polyline from the response (build `utils/polyline.ts` decoder)
  - Render as a Google Maps Polyline — blue line with slight transparency halo underneath (matches mockup)
- Create `ChargerMarker.tsx`:
  - For each planned stop in the response, render a blue circle marker with a lightning bolt icon
  - Show a small label below with charger name and charge time (e.g., "EA Salinas — 23 min")
- Create `useMapFit.ts` hook:
  - When a route is planned, auto-fit the map bounds to contain the full route polyline plus all markers
  - Include some padding so markers aren't right at the edges
- Button text changes to "Replan" after a route is planned
- "Replan" clears the current route and re-runs the planning call

**What to verify:**
- Click "Plan route" with San Jose → LA
- Loading state appears briefly
- Route polyline draws on the map along the actual road path
- Charger markers appear at the correct locations along the route
- Map auto-zooms to fit the entire route
- Clicking "Replan" clears and re-fetches

**Estimated time:** 1–2 days

---

### Iteration 3: Trip summary panel

**Goal:** When a route is planned, the trip summary panel slides in on the right side of the map showing distance, time, cost, the stop-by-stop timeline, factors, and cost breakdown. This is the primary information display.

**What to build:**
- Create `TripPanel.tsx` — floating panel, right side, conditionally rendered when a route plan exists in the store
  - Header: "Trip plan" title + "Clear" button
  - Clear button resets the route store and removes the route from the map
- Create `StatsGrid.tsx`:
  - 3-column grid showing distance, total time, and cost
  - Format values nicely: "340 mi", "5h 48m", "$28.50"
  - Build `utils/format.ts` with formatters: `formatDistance(km)`, `formatDuration(seconds)`, `formatCurrency(dollars)`
- Create `StopTimeline.tsx`:
  - Vertical timeline with dots and a connecting line
  - Origin at top (black dot), charging stops in middle (blue dots), destination at bottom (red square)
  - Each stop shows: name, time/power/cost for chargers, arrival → departure SoC
  - Departure time at origin, arrival time at destination
  - SoC displayed with color coding: red below 20%, amber 20-40%, green above 40%
- Create `FactorTags.tsx`:
  - Small pill-shaped tags showing the factors that influenced the route
  - Pull from the response: average temperature, wind, total elevation gain, traffic level
  - Render as a horizontal wrapping flex row of small gray tags
- Create `CostBreakdown.tsx`:
  - Line items: charging cost, session fees, total (bold)
  - Italic line for "Same trip at home rates" comparison
- Interaction between map and panel:
  - Clicking a stop in the timeline should pan/zoom the map to that charger's location
  - Clicking a charger marker on the map should highlight the corresponding stop in the timeline

**What to verify:**
- Plan a route — trip panel appears on the right
- All stats show correct, nicely formatted values
- Timeline shows origin → stops → destination in correct order
- Factor tags reflect the route conditions
- Cost breakdown adds up
- Click "Clear" — panel disappears, route clears from map
- Click a stop in timeline — map pans to that location
- Click a charger marker on map — corresponding stop highlights in panel

**Estimated time:** 1–2 days

---

### Iteration 4: Polish, loading states, and error handling

**Goal:** Handle all the edge cases and make the app feel solid. Loading states, error messages, empty states, and responsive refinements.

**What to build:**
- Create `LoadingOverlay.tsx`:
  - When route is being planned, show a subtle loading indicator
  - Options: skeleton shimmer in the trip panel area, or a small spinner on the plan button, or a progress bar at the top of the search panel
  - Don't block the map — user should still be able to pan/zoom while planning
- Create `ErrorBanner.tsx`:
  - When the backend returns an error, show a dismissible banner
  - Handle specific error codes from the backend:
    - `NO_CHARGER_COVERAGE` — "No chargers found along this route"
    - `VEHICLE_NOT_FOUND` — "Vehicle not configured"
    - `INSUFFICIENT_CHARGE` — "Battery too low to reach the first charger"
    - Generic network errors — "Couldn't reach the server"
  - Banner appears below the search panel, dismisses on click or after 10 seconds
- Empty state for the map before any route is planned:
  - Just the map with the origin marker, no panels or overlays cluttering the screen
- Handle destination change while a route is already planned:
  - Changing the destination should clear the current route and show the plan button as "Plan route" again
  - The old route/markers should disappear immediately
- Keyboard support:
  - Enter key in the destination input triggers route planning
  - Escape key clears the destination input
- URL state:
  - Encode origin and destination in the URL query params: `?from=San+Jose,CA&to=Los+Angeles,CA`
  - On page load, if URL has params, pre-fill the inputs and auto-plan the route
  - This lets you bookmark or share a planned route
- Responsive considerations:
  - Desktop-first, but the panels shouldn't overlap on screens narrower than ~1200px
  - On narrow screens, trip panel could stack below the search panel instead of floating right
  - Don't need mobile layout yet — just make sure it doesn't break at reasonable desktop sizes

**What to verify:**
- Plan a route — smooth loading experience, no layout jank
- Force a backend error (stop the Go server) — error banner appears, dismisses properly
- Change destination while a route is shown — old route clears, new plan button appears
- Enter key plans the route
- Copy the URL after planning — paste in new tab — route auto-plans
- Resize the window — panels don't overlap or break

**Estimated time:** 1 day

---

### Iteration 5: Fleet tab

**Goal:** Build out the Fleet tab — a secondary view showing all vehicles with their current state. Accessed via the bottom nav, replaces the route planner view but keeps the map.

**What to build:**
- Create `BottomNav.tsx`:
  - Floating pill-shaped tab bar at bottom center of the map
  - Four tabs: Route, Fleet, Trips, Settings
  - Active tab has dark fill, others are muted
  - Clicking a tab changes the active view
- Create `appStore.ts`:
  - Tracks the active tab
  - Route tab shows search panel + trip panel
  - Fleet tab shows fleet panel
  - Trips tab shows trip history
  - Settings tab shows settings
- Create `FleetView.tsx`:
  - Floating panel (same position as search panel, left side) showing the fleet
  - Lists all vehicles with current state from `GET /api/v1/fleet/status`
  - Shows vehicle name, SoC/fuel level with color-coded bar, connection status, last updated time
- Create `VehicleCard.tsx`:
  - Each vehicle in the fleet list
  - Shows: name, SoC or fuel percentage, range estimate, connection status (online/offline/charging), data source (OBD/FordPass), last seen location
- Map integration:
  - When on the Fleet tab, show vehicle markers on the map at their last known positions
  - Each vehicle marker shows initials (ME for Mach-E, HC for Civic) color-coded by status
- Wire up `api/vehicles.ts`:
  - `getFleetStatus(): Promise<VehicleStatus[]>`
  - Poll every 30 seconds, or use WebSocket if available (iteration 7)

**What to verify:**
- Click Fleet tab — search panel is replaced by fleet panel
- All fleet vehicles shown with current state
- Vehicle markers appear on map
- Click Route tab — back to route planner
- Fleet data refreshes periodically

**Estimated time:** 1 day

---

### Iteration 6: Trips tab

**Goal:** Build the trip history view — a list of previously planned trips with their key metrics.

**What to build:**
- Create `TripsView.tsx`:
  - Floating panel showing recent trips from `GET /api/v1/trips`
  - Most recent trips first
  - Each trip shows: date, origin → destination, vehicle used, total cost, total distance
- Create `TripRow.tsx`:
  - Compact row for each trip
  - Click to expand or click to re-plan the same route (opens Route tab with origin/destination pre-filled)
- Wire up `api/fleet.ts`:
  - `getTrips(): Promise<Trip[]>`
- Empty state: "No trips yet. Plan your first route!"

**What to verify:**
- Click Trips tab — shows trip history
- Trips list populated from backend
- Click a trip — switches to Route tab with that route's origin and destination pre-filled
- Empty state shows when no trips exist

**Estimated time:** Half a day

---

### Iteration 7: Settings tab + live WebSocket updates

**Goal:** Settings for fleet thresholds and preferences, plus WebSocket connection for real-time fleet state updates.

**What to build:**
- Create `SettingsView.tsx`:
  - Active vehicle selector — which vehicle is used for route planning
  - Vehicle details: shows the active vehicle's specs (battery capacity, range, connector type or fuel tank)
  - Threshold settings: minimum SoC/fuel before triggering a stop, default charge-to percentage
  - Home electricity rate (for cost comparison)
  - Loads current values from `GET /api/v1/config/thresholds`
  - Saves changes via `PUT /api/v1/config/thresholds`
  - This is where the vehicle is selected — it's a setting, not a per-route decision
- Create `useWebSocket.ts` hook:
  - Connects to `WS /api/v1/fleet/live`
  - On message, updates fleet state in the store
  - Auto-reconnect on disconnect with exponential backoff
  - Show connection status indicator somewhere subtle (small dot in the bottom nav area)
- Update `FleetView.tsx`:
  - Vehicle positions and states update in real time via WebSocket
  - Map markers animate smoothly to new positions when vehicles move

**What to verify:**
- Settings tab shows current thresholds and active vehicle
- Change active vehicle — route planner now plans for the selected vehicle
- Change a threshold — saves to backend, next route plan uses the new value
- WebSocket connects on app load
- Push a vehicle state update to Firebase — fleet view updates in real time without page refresh
- Disconnect the WebSocket — reconnects automatically

**Estimated time:** 1–2 days

---

### Iteration 8: Dark mode + visual polish

**Goal:** Dark mode support, animation refinements, and visual polish to make the app feel production-quality.

**What to build:**
- Dark mode:
  - Google Maps has a dark mode style — apply it via map `styles` prop
  - All panels use Tailwind's dark mode classes
  - Respect system preference (`prefers-color-scheme: dark`)
  - Toggle in settings to override system preference
- Animations:
  - Trip panel slides in from the right when a route is planned (CSS transition)
  - Route polyline draws progressively (animate stroke-dashoffset)
  - Charger markers fade in with a slight scale-up
  - Tab transitions are smooth (fade or slide)
- Map style refinements:
  - Subtle, desaturated map style that makes the route line and markers pop
  - Remove unnecessary map POIs (hide business labels, keep road names)
  - Custom map controls positioning (move zoom controls to not overlap panels)
- Typography and spacing audit:
  - Consistent font sizes across all panels
  - Proper spacing rhythm
  - All numbers formatted consistently (no floating point artifacts)
- Final details:
  - Favicon
  - Page title updates with route ("San Jose → LA — Fleet Router")
  - Meta tags for bookmarking

**What to verify:**
- Toggle dark mode — all panels, map, and markers adapt
- System dark mode preference is respected
- Animations are smooth, not janky
- Map style is clean and lets the route information be the focus
- Overall feel is polished and professional

**Estimated time:** 1–2 days

---

## Summary timeline

| Iteration | What | Estimated time |
|---|---|---|
| 0 | Project skeleton + full-screen map | Half day |
| 1 | Search panel + Places autocomplete | 1 day |
| 2 | Route planning API + route on map | 1–2 days |
| 3 | Trip summary panel | 1–2 days |
| 4 | Polish, errors, URL state | 1 day |
| 5 | Fleet tab | 1 day |
| 6 | Trips tab | Half day |
| 7 | Settings + WebSocket | 1–2 days |
| 8 | Dark mode + visual polish | 1–2 days |
| **Total** | | **~8–12 days** |

At full-time pace, this is roughly 2 weeks for a complete, polished web app. The core route planning experience (iterations 0–3) is usable in about 4 days.

---

## Key integration points with the backend

The web app talks to these backend endpoints (built in backend phase 1):

| Endpoint | Used in | Purpose |
|---|---|---|
| `POST /api/v1/route/plan` | Iteration 2 | Core route planning |
| `GET /api/v1/fleet/status` | Iteration 5 | Fleet vehicle list + live state |
| `GET /api/v1/vehicles/{vin}` | Iteration 7 | Vehicle details for settings |
| `GET /api/v1/trips` | Iteration 6 | Trip history list |
| `GET /api/v1/config/thresholds` | Iteration 7 | Load settings |
| `PUT /api/v1/config/thresholds` | Iteration 7 | Save settings |
| `WS /api/v1/fleet/live` | Iteration 7 | Real-time fleet updates |

The Google Maps API key is shared between the backend (Routes API) and the frontend (Maps SDK + Places API). Configure it once as an environment variable.

---

## What this does NOT include

- Mobile-responsive layout (desktop-first, doesn't break on tablet, but not phone-optimized)
- Turn-by-turn navigation (this is a planner, not a nav app — use Google Maps for actual driving)
- Offline support
- User authentication (this is a personal tool, no login needed)
- Push notifications
- Native app wrapper (PWA or Capacitor — possible later but not in scope)
