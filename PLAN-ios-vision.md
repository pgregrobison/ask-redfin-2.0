# Plan: Bring the "iOS Vision" prototype into the native app, on Nova

Source: Claude Design project "6 Month Ask Redfin Vision", entry page **iOS Vision** (+ the embedded **DreamHomeMemory** / **Dream Home Sorter** it opens from the My home tab). Desktop, Airbnb and spec-only pages are out of scope.

Guiding rule: match the prototype's *behavior and look*, but build it with the native iOS patterns this app already uses (TabView + bottom accessory, NavigationStack zoom pushes, native sheets with detents, MapKit, Liquid Glass with fallbacks, SF-style haptics). Where the web prototype hand-rolls something iOS gives us for free, use the iOS version.

### Decisions (confirmed 2026-11-04)
- **Old flows:** Vision's chat/Find/handoff model wins. Handoff "Request tour" → existing tour booking wizard; "Continue to Rocket" → existing mortgage prequal wizard. Tour Day (banner + scripted thread) is retired.
- **My home tab:** becomes Dream Home. Homeowner/seller dashboard + Open to Offers stubs are removed (kept in git history).
- **Font:** WNTL Text (woff2 → OTF/TTF), Inter removed.
- **Data:** prototype's 335 Seattle listings + 14 exterior photos + region polygons replace MockData; existing local house photos may be reused to add variety.
- **Before starting:** commit the current uncommitted work (41 files) as a checkpoint so the Nova migration diff is reviewable on its own.

---

## Phase 0 — Nova foundation (replaces current Theme tokens)

1. **Tokens → `Theme.swift` rewritten as Nova** (keep the `Theme.X.y` call sites so the whole app re-skins at once; ~900 existing references).
   - Colors: full Nova ramps (brand, gray, blue, green, yellow, data-viz, opacity ramps) + semantic tokens (`bg.primary/secondary/tertiary`, `text`, `textSubtle`, `border`, `icon*`, `info/success/warning`), light + dark as dynamic colors.
   - Type: Nova ramp (heading 18–40, label 12–20, body 14–18, caption 10–12, tracked) using `Font.custom(_:size:relativeTo:)` so Dynamic Type works again.
   - Radii: pill 100, round 24, card 20, field 12, field-sm 8, tag 6. Elevation 1–5 as shadow modifiers. Motion: Nova eases + durations, and the `ASK_REDFIN_MOTION` constants (char delay 14ms, comma 110, sentence 340, dots 550, steps 3000…).
2. **Font**: register WNTL Text (400/500/700/900) and remove Inter. *(see question)*
3. **Icons**: convert the Nova sprite symbols the prototype uses (~80) into template SVG imagesets (`nova.house`, `nova.filter_handles`…), with a `NovaIcon` view. SF Symbols remain only for system chrome where Nova has no equivalent.
4. **Nova SwiftUI components** (`Views/Nova/`): `NovaButtonStyle` (primary/secondary/tertiary/apply × x-small/small/default/large, dark→red press), `NovaIconButton`, `NovaChip` (default/outline/selected), `NovaTag`, `NovaBadge`, `NovaCard` (default/secondary/dark/brand/image), `NovaBanner`, `NovaToggleStyle`, `NovaTextField`, `NovaGlass` (the frosted pill/popover recipe, mapped to `.glassEffect` on iOS 26).
5. Sweep hard-coded colors/fonts (MyHomeView, detail views) onto tokens; delete dead views (`ListingDetailView`, `RedfinDetailView`, `NudgeBubbleView`, unused button styles).

## Phase 1 — Data + search engine

- Import the prototype's `listings.json` (335 Seattle homes) + 14 exterior photos + `regions.json` neighborhood polygons, with the same deterministic derived attributes (transit score, condition, features, basement, garage, the 5 known criteria). *(see question)*
- `SearchState` model mirroring the prototype: locations, filters (price/beds/baths/types/sqft/HOA/features), criteria with nice/must/dealbreaker modes + on/off, refinements, analysis, sort, favorites, saved search, highlights, tours, watches, hidden. Ranking = criteria-match count; must/dealbreaker are hard filters; match badge "4/5".
- Snapshot/undo per chat turn; persistence of current session + up to 8 threads (3 seeded demo threads).

## Phase 2 — Find homes (map + list)

- **Map (MapKit)**: price pills / dots (top 100 get pills), selected & highlighted states (red, scale, glow), analysis color ramp, tour-plan numbered pins, region mask (`MapPolygon` veil outside the selected areas), camera auto-fit after result changes.
- **Map style menu**: Streets / Light / Dark + 3D toggle → `mapStyle(.standard(emphasis:))`, dark color scheme, `MapCamera` pitch 45.
- **Analysis legend** glass card.
- **Top pill bar** (horizontal scroll, glass): Filters (count badge) · Location · Price · Beds & baths · divider · criterion pills (toggle; long-press → Nice/Must/Dealbreaker menu — wiring up the action sheet the prototype left unconnected) · refinement pills · analysis pill. Animated insert/remove.
- **Selected-home carousel**: native paging `ScrollView` (`scrollTargetBehavior(.paging)`), tapped home + 9 nearest, swipe re-centers map; tab bar minimizes while showing. Tap → existing zoom-push detail.
- **List view**: Nova secondary cards, "Hot home" tag, match badge, Save search button, paging "Show 24 more".
- **Location search**: native popover (`.presentationCompactAdaptation(.popover)`) with search field, multi-select places.
- **Price / Beds popovers** and the **Filters sheet** (native sheet, detents): view toggle, sort chips, criteria, histogram + dual-thumb price slider, home type, beds, baths, sqft, HOA, features, "Show N homes".

## Phase 3 — Ask Redfin bar + chat sheet

- **Bottom Ask bar** lives in `.tabViewBottomAccessory` (already used): leading chevron/“+” morph, rotating placeholder, voice button, spring-in send button, **AI glow sweep while busy**, in-bar thinking/done toast, **floating reply bubble** when chat is closed.
- **Chat sheet**: native `.sheet` with detents (`.fraction(0.88)`, `.large`) — gains the drag-to-dismiss the prototype only fakes. Glass header (Chats menu, close), disclaimer, messages per AskMessage spec (user bubble, event rows with "Saved to your dream home" link, done row, streamed bot text with tappable addresses + bolded numbers), AskWorking (dots → steps after 3s → collapsed "Checked 26 homes"), up to 3 suggestion chips, feedback (thumbs, copy, retry, "Tell us more" panel, toasts, Undo change).
- **Add menu** ("+") with Add photos / Take a photo / Find visual inspiration / Things to try catalog — reuse existing PhotosPicker + camera pickers.
- **Threads**: New chat, open archived thread restores search.

## Phase 4 — Intent router (scripted brain)

Port the prototype's regex router into `ChatService`, in tiers so each lands testable:
1. Core: location add/switch/expand, price/beds/baths parsing, criteria add + modes, feature filters, home type, start fresh / pick up where I left off.
2. Questions: superlatives + "next one", ordinals, street, address/pronoun follow-ups, averages, short sales, transit, condition, honest fallback, guardrails (safety, families, good deal).
3. Analysis & travel time: distance to parks/grocery/schools/landmarks, price per sqft, transit, drive/walk/bike/transit time.
4. Planning: similar homes, best fit, afford (mortgage math), tour, agent, watch, tour-day plan → itinerary → debrief, compare, photo/inspiration.

## Phase 5 — Inline chat widgets

Home card carousel + "Show N homes on map", CTA button, compare table, tour-day picker, itinerary (route drawn with `MapPolyline` on the main map), debrief reaction chips, watch cards (+ simulated trigger), confirm buttons, inspiration tiles, add-photo.

## Phase 6 — Handoff sheets

Tour / Rocket / Agent handoff sheets (summary of what the agent/Rocket will see, day/time chips, payment breakdown). *(see question about the existing tour + mortgage wizards)*

## Phase 7 — My home → Dream Home

- Mad-lib header ("I'm buying my **dream home** **in less than 6 months ▾**") with native `Menu`, alerts sheet.
- Sections: It must be in (regions, location pills, add place) · I can spend (buying-power calculate → tiers, target range) · It must have / Bonus points if it has (drag pills between buckets with `draggable`/`dropDestination`, move up/down buttons) · It looks like (photo piles) · It can't have · Maybe it also has (recommendation + "Sort N more").
- **Dream Home Sorter**: full-screen swipe deck (DragGesture; left = nice, right = must, down = dealbreaker, skip, undo, intro nudge, zone haptics) → done summary → save.
- Sheets: Find inspiration, Add area, Dream home alerts. "Find homes that match" FAB runs the dream home as a search on Find. Two-way sync with `SearchState`.

## Phase 8 — Intro + polish

Auto-play intro (types the Seattle query, presses send) behind the existing Launch Demo debug toggle; reduced-motion handling; dark mode pass; Debug panel entries for the new toggles; verify on iPhone 18 Pro simulator.

---

### Not ported (prototype gaps)
For you / Saved / My Redfin stay as the app's existing screens (prototype has none). Voice and share stay no-ops/simulated. Mapbox token in the prototype is not carried over.
