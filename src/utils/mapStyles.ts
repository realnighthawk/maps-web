import { ColorScheme } from '@vis.gl/react-google-maps'

/**
 * With a mapId, Google does not allow `styles` on the map — styling is done in
 * Cloud Console for that Map ID. Light/dark basemap can still follow the app theme.
 */
export function resolvedMapColorScheme(isDark: boolean): ColorScheme {
  return isDark ? ColorScheme.DARK : ColorScheme.LIGHT
}
