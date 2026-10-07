# Low-end device plan

Status: **parked** (2026-10-06). Everything so far was tested only as debug
builds on a fast emulator, never on a budget phone.

## Where low-end phones (2–3 GB RAM, older SoCs) will struggle

1. **Search, the biggest cost.** Every search loads the full *desktop* Google
   Maps site in a hidden WebView (`DirectionsRemoteDataSourceImpl`).
   - About 3–10 s on the emulator; likely 10–25 s on a budget phone. The 25 s
     timeout means some searches would fail outright.
   - The hidden WebView and MapLibre are in memory together, so 2 GB phones
     risk being killed for low memory.
   - The first search downloads several MB of scripts and images (mobile
     data cost). Later searches are lighter because of the cache.
2. **Map drawing is mostly fine.** MapLibre needs OpenGL ES 3.0 (most
   phones since ~2014). The tilted 3D buildings may stutter on very weak GPUs.
3. **The navigation loop does more work than needed.** On every GPS fix
   (1 Hz):
   - `RouteEntity.cumulativeMeters` is recomputed several times
     (`locate`, `bearingAt`, `pointAt`, `slice`, `stepStartMeters`).
   - `RouteMap._redraw` resends the whole route GeoJSON (1000+ points) over the
     platform channel just to move the arrow and the grey "driven" split.
4. **Debug vs release.** Debug builds are much slower. Measure in release.

## Fixes, in order of impact

1. **Slim the hidden WebView.** Use InAppWebView content blockers or request
   interception to block map tiles (`/maps/vt`, `khms`), images, fonts and
   Street View (`streetviewpixels`). Only the directions response is needed.
2. **Keep one hidden WebView warm** and reuse it between searches instead of a
   cold start every time (this also speeds up rerouting).
3. **Compute route distances once.** Cache cumulative distances and step
   starts when the route is parsed (e.g. compute them in the model and store
   them on the entity).
4. **Split map sources by update rate.** Set the route once per route. Update
   only the arrow source every fix, and redraw the traveled/remaining split
   every ~50 m.
5. **Lighter map on weak devices.** Pick a flat map without 3D buildings when
   the phone has little RAM.
6. **Measure.** Release build on a low-spec emulator (2 GB RAM, 2 cores).
   Record time-to-routes, memory and frame times before and after each fix.
   Ideally also test on a real budget phone (e.g. Tecno or Itel).
