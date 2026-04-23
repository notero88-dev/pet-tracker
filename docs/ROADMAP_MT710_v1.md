# MT710 v1 Capabilities — Implementation Roadmap

**Owner:** Claude (CTO)
**Date:** 2026-04-23
**Source:** `PRD_PetTracker_OnePager.pdf` (2026-04-23)
**Scope:** Ship every MT710 capability marked **Yes** or **Partial** in the PRD to production-quality.

---

## 1. Executive summary

The MT710 hardware already supports everything v1 needs except HR, sleep, and bark monitoring (correctly excluded). Our gap is **not hardware** — it's a **vertical integration gap**: device commands, backend event plumbing, and app UX to drive them. Roughly:

- **~40% of the plumbing exists** (Traccar stores positions + geofences; provisioning API creates the device; Flutter has a WebSocket listener; push-service file layout suggests event handling).
- **~0% has been validated end-to-end on the physical MT710.** We have one real device (IMEI 862407061373209), last reported a position yesterday, currently offline. Nothing in today's session has proven that setting an update interval from the app actually changes the device's behavior.
- **~60% of the user-facing flows don't exist yet** (geofence editor, Home Mode Wi-Fi setup, activity metrics, family sharing).

The plan below is 5 epics. If we parallel-track backend + frontend, v1 ships in roughly **5–7 focused days of build** after today, assuming the MT710 and Traccar cooperate.

---

## 2. What we already have (verified today)

| Piece | Verified |
|---|---|
| Traccar 6.12.2 receives positions from MT710 | ✅ (last position 2026-04-12, device online at various points) |
| MT710 provisioned in Traccar as user + device + link | ✅ |
| Provisioning API creates Traccar user + device idempotently | ✅ (fixed today, HTTP 201/200/409 contract) |
| Flutter app: register + login via Firebase Auth | ✅ (web + iOS signed build) |
| Flutter app: provisioning flow end-to-end | ✅ on web after today's fixes |
| Firestore enabled + accepting writes | ✅ (enabled today in test mode) |
| push-service systemd unit running | ✅ (running but untested — no FCM delivery confirmed) |
| Codemagic CI builds iOS simulator | ✅ (TestFlight blocked on Apple Developer validation) |

---

## 3. What we have but is UNVERIFIED

These exist in the codebase but haven't been exercised end-to-end. **Assumption: half of these don't actually work and we'll discover it when we test.**

| Piece | Risk |
|---|---|
| Traccar → MT710 command forwarding (`/commands/send`) | Unknown whether the device ever receives commands sent via Traccar |
| MT710's actual position cadence today | Unknown — could be 60s, 120s, 300s. PRD target is 10s. |
| push-service consuming Traccar events and sending FCM | Code exists (`services/traccar.js`, `services/notificationService.js`) but never validated |
| Geofence creation via Traccar `/geofences` API | Traccar supports it; Flutter has the wrapper; no UI to create one |
| Real-time WebSocket position updates in app | Code exists (`traccar_websocket.dart`) but never seen live updating the map |
| Battery level surfaced in app | Traccar position attributes carry it; app doesn't display it |

---

## 4. Known gaps (what's actually missing)

### Device side (MT710 commands)
The MT710 manual uses an ASCII command protocol. The commands we need, none of which are wired into our system today:

| Need | MT710 command |
|---|---|
| Set position interval to 10s | `A11,10#` (range 10–600s) |
| Switch to Motion mode | `A12,6#` |
| Switch to Home mode | `A12,8#` |
| Configure home Wi-Fi MACs (up to 3) | `A21,SSID,MAC1,MAC2,MAC3#` |
| Configure on-device geofence | `A22,lat,lng,radius#` |
| Set APN (Claro/Movistar/Tigo for Colombia) | `A10,apn,user,pass#` |
| Find mode (LED/buzzer, to be verified) | TBD from manual re-read |

Traccar has a generic `command` endpoint that accepts a raw text command, which is how we'd send these. **Untested on our setup.**

### Backend side
- No endpoint to change MT710 mode / interval from the app
- No endpoint to configure Home Mode Wi-Fi MACs
- No event → notification routing verified (push-service is a black box right now)
- No activity-minutes calculation from raw accelerometer
- No family-sharing model (who can see which pet)
- No subscription / billing layer at all (not blocking v1 testing, but blocking v1 launch)

### App side
- No geofence editor (create/edit/delete) on the map
- No Home Mode setup flow (scan Wi-Fi, pick 3 MACs, confirm)
- No settings screen to change update interval / mode
- No battery / signal / last-seen display on the device screen
- No family invite flow
- No activity dashboard (steps, minutes active)
- Known bugs from today's session still open: Firestore web init, idempotent-credentials on re-provision, web cookie issue (fixed) — docs/STATUS_2026-04-22.md

---

## 5. Epics

Each epic is a shippable vertical slice. Ordered by dependency.

### EPIC 1 — Baseline validation (1 day)
**Goal:** Prove the MT710 + Traccar + Flutter stack actually works for live position updates before building anything new on top.

- [ ] **BV-1** Power the MT710, confirm it comes online in Traccar. Capture 30 min of positions; measure actual update cadence.
- [ ] **BV-2** Send `A11,10#` to the device via Traccar `/commands/send`. Confirm the cadence drops to ~10s in Traccar position log.
- [ ] **BV-3** Confirm Flutter WebSocket (`traccar_websocket.dart`) receives every new position in real time while the app is open.
- [ ] **BV-4** Inspect what attributes arrive on each position (battery, motion, valid, satellites, accel). Document the schema in `docs/MT710_POSITION_ATTRS.md`.
- [ ] **BV-5** Walk with the device, confirm map updates live in the app.
- [ ] **BV-6** Put the device indoors, confirm Wi-Fi fallback actually changes the fix source to WiFi. Record how Traccar tags it.

**Exit criteria:** Known good 10s cadence, documented position schema, real-time map working on at least one platform (web or iOS TestFlight).

---

### EPIC 2 — Geofence + escape alerts (1–2 days)
**Goal:** Draw a geofence, leave it, get a push within 30s. This is the PRD's #1 safety feature.

Two implementation choices:

- **Option A — Server-side (Traccar)**: Create a Traccar geofence and permission-link it to the device. Traccar evaluates exit/entry events against every incoming position and emits a `geofenceExit` event. push-service consumes the event and fires FCM. **Pros:** works regardless of device mode; simpler. **Cons:** 30s latency bounded by MT710's reporting interval.
- **Option B — Device-side (MT710 Mode 8)**: Send `A22,lat,lng,radius#` to the device. Device evaluates geofence on-chip and wakes up faster on exit. **Pros:** lowest latency, best for Home Mode battery savings. **Cons:** one geofence max (device limitation), requires Mode 8.

**Recommendation:** Ship **A** for v1 (covers all multi-geofence cases) and **A+B combined** for Home Mode (A as safety net, B for battery savings when inside).

Tasks:
- [ ] **GF-1** UI: map screen with a "+ Add zone" button → tap center on map → radius slider (30–300 m) → save
- [ ] **GF-2** Flutter: call `traccar_api.createGeofence()` + `/permissions` to link to device (wrapper already exists)
- [ ] **GF-3** Backend verification: push-service consumes `geofenceExit` Traccar event and fires FCM to user's token
- [ ] **GF-4** FCM token registration: on app start, request notification permission, register token with Firebase, save to Firestore `users/{uid}.fcmToken`
- [ ] **GF-5** Handle incoming push: tap notification → deep-link to the device's last known location
- [ ] **GF-6** End-to-end test: draw fence, drive/walk out, confirm alert arrives within 30s (PRD success metric)
- [ ] **GF-7** Edge cases: fence edit, fence delete, multiple fences per pet, overlapping fences
- [ ] **GF-8** (Stretch) device-side geofence via `A22#` for Home Mode

**Exit criteria:** PRD success metric "Geofence exit → push alert ≤ 30s p95" measured over 10 real exits.

---

### EPIC 3 — Modes & Power Saving Zone (2 days)
**Goal:** Home Mode (Mode 8) with Wi-Fi auto-detection works; user can configure their home zone in < 2 min.

Tasks:
- [ ] **PSZ-1** Provisioning-API: new endpoint `POST /devices/:id/mode` accepting `{ mode: "motion" | "home" }` → translates to `A12,6#` or `A12,8#` + Traccar command forward
- [ ] **PSZ-2** Provisioning-API: new endpoint `POST /devices/:id/home-wifi` accepting `{ ssid, macs: string[] (1-3) }` → translates to `A21,SSID,MAC1,MAC2,MAC3#`
- [ ] **PSZ-3** Flutter: Home Setup flow — "You're home? Let's save this spot." → Wi-Fi scan → up to 3 MACs auto-populated → confirm
- [ ] **PSZ-4** Flutter: device settings screen with mode toggle (Motion / Home) and interval slider (10/30/60/300s)
- [ ] **PSZ-5** Validate: device enters Home Mode, GPS sleeps, battery drain drops. Measure over 24h.
- [ ] **PSZ-6** Validate: device exits Home Mode when walking 30m away; first position fix delivered ≤ 60s after exit

**Exit criteria:** PRD success metric "Battery ≥ 14 days in Home Mode" — run a 3-day pilot to extrapolate.

---

### EPIC 4 — Battery, signal, activity (1 day)
**Goal:** All the secondary UI indicators are populated from real device data.

Tasks:
- [ ] **DEV-1** Parse `battery` / `batteryLevel` from Traccar position `attributes`, display in device card and on map pin
- [ ] **DEV-2** Low-battery alert (<20%) → FCM via push-service, deep-link into the app's charging-tips screen
- [ ] **DEV-3** Parse accelerometer attributes (`motion`, `accel`, or raw); compute active-minutes-today in-app (client-side for v1)
- [ ] **DEV-4** Device "last seen" timestamp displayed prominently when > 5 min stale
- [ ] **DEV-5** Cellular signal strength indicator (Traccar `rssi` or `signal` attribute, if present)

**Exit criteria:** All tiles on the device detail screen show live values.

---

### EPIC 5 — Family sharing (2 days)
**Goal:** Invite a spouse / family member via email; they can see the same pet.

Tasks:
- [ ] **FS-1** Firestore schema: `pets/{petId}` gets `ownerIds: string[]` (array of Firebase UIDs)
- [ ] **FS-2** Traccar: add second user as permissioned reader of the same device (`/permissions` POST)
- [ ] **FS-3** Provisioning-API: new endpoint `POST /devices/:id/invite` — takes `{ inviteeEmail }`, creates Traccar user if needed OR links existing, adds Firestore UID to `ownerIds`
- [ ] **FS-4** Flutter: "Invite family" flow in pet profile; deep-link in FCM to accept invite
- [ ] **FS-5** App: pet list shows shared pets with a small "shared" badge; owner can revoke

**Exit criteria:** Two accounts can see the same MT710 in real time; revoke works.

---

### EPIC 6 — Production hardening (concurrent with above)
Not gated on a specific feature — runs in parallel as items come up.

- [ ] **PH-1** Fix the known `firebase_options.dart` placeholder appIds (run `flutterfire configure` to regenerate)
- [ ] **PH-2** Fix the idempotent-credentials bug in the backend — on 200 idempotent, regenerate + return password (or add `/credentials/reset` endpoint)
- [ ] **PH-3** Tighten Firestore security rules before exiting test mode (30 days out)
- [ ] **PH-4** Move Traccar admin password out of plaintext `.env` (systemd LoadCredential or Vault)
- [ ] **PH-5** Get Apple Developer validation unblocked → first TestFlight build
- [ ] **PH-6** Automated deploy script for backend repo (pull from GitHub, backup, restart) — replace `/tmp/` workflow
- [ ] **PH-7** Install Android Studio + emulator for push notification testing on Android
- [ ] **PH-8** Add minimal test coverage to provisioning-api (jest, at least the /provision happy paths + conflict cases)
- [ ] **PH-9** Set up error monitoring — Sentry on Flutter + Node services (free tier fine)

---

## 6. Suggested sequencing (5–7 build days)

```
Day 1  [EPIC 1]     Baseline validation (device cadence, WebSocket, attributes)
Day 2  [EPIC 2]     Geofence + FCM plumbing
Day 3  [EPIC 2]     Geofence UI + end-to-end test
Day 4  [EPIC 3]     Mode commands + Home Mode UX
Day 5  [EPIC 3/4]   Battery/activity + finish Home Mode
Day 6  [EPIC 5]     Family sharing
Day 7  [EPIC 6]     Hardening, fixes, TestFlight
```

PH items happen in spare moments. EPIC 1 is strictly first — if it reveals that Traccar doesn't actually forward commands to the MT710, the whole plan changes.

---

## 7. Decisions that need to be made up front

Before starting EPIC 1, confirm:

1. **Is the MT710 SIM active on a carrier?** If not, nothing works. (Check: does the device show "online" in Traccar after being powered on outdoors?)
2. **What APN values for the Colombia carrier?** Needed for A10# command if a factory reset was ever done.
3. **Subscription tier design** — what features are gated behind cellular pricing? (Affects what we show in the app for non-paying users.) Not blocking testing, but blocking launch.
4. **Tractive parity or Tractive differentiation?** PRD says benchmark. Does the UI mimic them or go its own way?
5. **Geofence latency target** — PRD says ≤30s p95. Confirm this is acceptable messaging (Tractive markets 2–3s; we're hardware-limited to 10s).

---

## 8. Key risks

| Risk | Mitigation |
|---|---|
| Traccar doesn't forward commands to MT710 reliably | Validate in EPIC 1 on day 1. If broken, pivot to direct TCP connection to MT710 (Mictrack offers a direct-connect option; requires running our own listener) |
| 10s cadence is unacceptable vs. Tractive's 2–3s | Messaging-only risk — hardware-bound. Address in PRD copy ("real-time, ~10s updates") |
| Accelerometer data too noisy for a meaningful activity metric | Ship a simple "minutes active" using motion threshold + time-window aggregation. Don't promise step count. |
| CAT-M1 coverage gaps in Colombia | Test in 3 representative cities before public launch |
| Battery life in Home Mode doesn't hit 14 days | Tune `A11#` interval (maybe 300s in Home Mode, 10s outside). Re-messageable. |
| Firebase FCM iOS not delivering on idle devices | Known platform issue — use `content-available` + APNs priority 10 for location alerts |

---

## 9. Definition of done for "v1 tested and shipped"

- [ ] One human has walked outside the geofence → got a push within 30s
- [ ] One human has gone home → device switched to Home Mode automatically → battery drain slowed
- [ ] Two human accounts can see the same pet moving in real time
- [ ] App installed via TestFlight on a real iPhone (not just web)
- [ ] Device reports for 72 hours continuously without losing connection
- [ ] Low-battery alert fired at ≤20% and delivered to the phone
- [ ] All 5 PRD success metrics measured (numbers in a status doc — some may be preliminary)

Until all of the above are green, v1 is not ready to onboard real users.
