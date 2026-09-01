# Changelog

All notable changes to the Surfside iOS Tracker. This project follows
[Semantic Versioning](https://semver.org/). Release tags are **bare semver, no `v` prefix**
(`2.0.0`, not `v2.0.0`).

---

## 2.1.0 — 2026-09-01

Makes identity a **supported** surface on iOS and brings it in line with the Surfside web SDK
and the platform's schema registry. Verified end-to-end on dev: `setUser` → on-device hash →
collector → resolved `uid2`, riding the same rails the web SDK already uses.

### Identity

- **User context repointed** to the platform identity schema `io.surfside.identity/user`, version
  `1-0-2` (hashed identifiers only; raw `email`/`phone` dropped from the schema), replacing the
  old `io.surfside/user` (`1-0-0`).
- **Client-side hashing.** `hashed_email` and `hashed_phone` are computed on the device as
  `Base64(SHA-256(UID2-normalized value))` — the same normalization the web SDK and the server-side
  hasher use — so raw email and phone no longer leave the app to resolve an identity. Hashing
  parity with the web SDK is locked by golden-vector tests.
- **`setUser` accepts the web SDK's full profile field set** (`address`, `age`, `company`,
  `createdAt`, `dateOfBirth`, `firstName`, `gender`, `lastName`) alongside `userId`, `email`,
  `phone`, and also sets the atomic `userId` (web-SDK parity).
- **`removeUser` added** — clears the user context set by `setUser` (e.g. on logout), so subsequent
  events carry no user identity; mirrors the web SDK's `removeUser`.
- **`getResolvedIdentity` added** — reads back the resolved `userId` / device id so a host app can
  broker identity to other Surfside SDKs without them depending on the tracker.

### Removed

- **`identifyUser`, `setSurfId`, and the advertising/auction methods** (`auctionInit`,
  `bidRequested`, `bidResponse`, `bidderDone`, `bidderError`, `noBid`) — along with their event and
  entity classes (`AuctionEntity`, the `*Event` types, `IdentifyUserEvent`). None were resolved or
  modeled downstream — the schemas they emitted (`io.surfside/surfId`, `io.surfside/identify`,
  `io.surfside/auction_init`, …) are not part of the platform contract, and `identifyUser` was
  additionally emitting raw email. **`setUser` is the single supported identity path**; if you
  referenced any removed method on a 2.0.0 build, delete the call.

### Commerce

- **`transaction.revenue` and `impression.price` now serialize as JSON numbers**, not strings
  (`revenue?.doubleValue` / `price?.doubleValue`), matching `product.price` and the web SDK.
  Previously these two fields shipped stringified — a silent same-event inconsistency. (JJRC-283)

### Internal

- Fixed the two pre-existing unit-test flakes (`TestLinkDecorator`, `TestTrackerConfiguration`);
  `make test-unit` is green.

**Impact on a 2.0.0 integration:** none of the commerce, location, segment, or source APIs change.
Adopting identity is additive — bump the dependency and add the identity calls. Because 2.1.0 is a
minor release, `from: "2.0.0"` picks it up automatically. If you consume the two commerce fields
above as JSON strings, update your parsing to read numbers.

---

## 2.0.2 — 2026-07-28

Documentation only. **No code changes since 2.0.0** — the compiled SDK and the data it emits are
unchanged.

- `README.md`: new **"Two version numbers, both correct"** table explaining that the SDK ships as
  `2.0.x` while every payload reports `"tv": "ios-6.2.2"` and the `VERSION` file and podspec carry
  `6.2.2`. That number is the upstream Snowplow tracker version this fork is built on, not a
  packaging error. Cross-referenced from *Verifying your integration*, where integrators inspecting
  payloads in Snowplow Micro hit it first.

---

## 2.0.1 — 2026-07-27

Documentation only. **No code changes since 2.0.0** — the compiled SDK and the data it emits are
byte-for-byte identical. Tagged so that consumers pinned with `from: "2.0.0"` resolve a checkout
containing the corrected documentation.

- `README.md` rewritten against the shipped 2.0.0 API: correct module name, SPM install pinned to
  2.0.0, accurate method signatures, the persistent-vs-commerce context model, a release-status table,
  and explicit warnings on the identity and advertising methods.
- `SURFSIDE.md` rewritten as a commerce tracking reference: schemas emitted, per-field wire types, and
  a recipe per commerce moment.
- `CHANGELOG.md` added, including the planned 2.1.0 identity work.

Every code sample in both documents was compile-checked against this release.

---

## 2.0.0 — 2026-07-17

**Commerce tracking correctness.** This is the first release recommended for client integration.

### Breaking

- **Transactions and impressions are now entities on the commerce action event, not standalone
  events.** In 1.0.0, `addTransaction` and `addImpression` immediately fired their own events —
  despite the `add…` naming — under `iglu:io.surfside/commerce_transaction/jsonschema/1-0-0` and
  `iglu:io.surfside/commerce_impression/jsonschema/1-0-0`. They now buffer like products and
  promotions do, and attach to the next `setCommerceAction(...)` event as
  `iglu:io.surfside.commerce/transaction/jsonschema/1-0-0` and
  `iglu:io.surfside.commerce/impression/jsonschema/1-0-0`.

  *Wire impact:* those two `io.surfside/commerce_*` event types are no longer emitted. Any downstream
  model keyed on them must read the entities on the commerce action event instead. Client code does
  not change — the same calls in the same order now produce one correctly-shaped event.

- **Persistent contexts unified onto Snowplow's `globalContexts`.** Source, segment, location, and
  user contexts are registered under stable tags (`surfside-source`, `surfside-segment`,
  `surfside-location`, `surfside-user`, `surfside-surfId`) and are remove-then-added on re-set, so
  calling a setter twice **replaces** the value instead of attaching duplicate entities.

- **Public API removed.** `SurfsideEvent.init(trackerNamespace:)`, `setTrackerNamespace(_:)`,
  `pluginAdded(to:)`, `activate(tracker:)`, and `entitiesConfiguration`;
  `SurfsideController.addGlobalContext(entity:trackerNamespace:identifier:)` and
  `clearGlobalContexts(for:)`. Context management is now driven by the plugin's context setters and
  Snowplow's global-context system rather than by callers assembling entities by hand.

### Fixed

- Duplicate persistent entities when a context setter was called more than once for a namespace.
- Commerce contexts are reliably cleared after each commerce action, so a subsequent action no longer
  inherits the previous moment's products.
- Test suite compiles and runs again; unit tests are separated from the Micro-dependent integration
  target (see `make test-unit` vs `make test-integration`).

### Added

- `Makefile` with `build`, `test-unit`, `test-integration`, `test-all`, and `micro` targets.
- Unit coverage for Surfside global contexts and commerce contexts
  (`Tests/SurfsideTests/SurfsideGlobalContextsTests.swift`,
  `Tests/SurfsideTests/SurfsideCommerceContextsTests.swift`).
- Documented versioning and release-tagging policy.

### Not supported in this release

- **Identity** — `setUser`, `identifyUser`, `setSurfId`. These compile and run, but the schemas they
  emit are not part of the platform's identity contract, so the data is not resolved or modeled
  downstream. Supported in 2.1.0.
- **Advertising / auction** — `auctionInit`, `bidRequested`, `bidResponse`, `bidderDone`,
  `bidderError`, `noBid`. Emit unregistered schemas; not processed. Retained only for source
  compatibility with 1.0.0 and candidates for removal in a future major version.

### Upgrading from 1.0.0

1. Update the dependency to `from: "2.0.0"`.
2. Confirm you are not calling any of the removed APIs listed above. The supported path is
   `SurfsideHelper.createTracker(...)` for setup, the context setters for state, and
   `setCommerceAction(...)` to send.
3. If you had a `SurfsideEvent(trackerNamespace:)` initializer call, replace it with
   `SurfsideEvent()` plus `tracker.plugins.add(plugin:)` and
   `SurfsideController.shared.registerTracker(tracker)` — or just use `SurfsideHelper`.
4. Note for anyone querying the data: `io.surfside/commerce_transaction` and
   `io.surfside/commerce_impression` events stop arriving from upgraded apps.

### Documentation

Earlier docs showed `import Surfside`, a `SurfsidePlugin` type, a `SurfsideEvent.trackEvent(...)`
helper, and a no-argument `clearCommerceContexts()` — none of which exist. The correct module is
`SurfsideTracker`, the plugin type is `SurfsideEvent`, custom events go through
`tracker.track(SelfDescribing(...))`, and clearing takes a namespace:
`SurfsideController.shared.clearCommerceContexts(for:)`. `README.md` and `SURFSIDE.md` were rewritten
against the shipped 2.0.0 API.

---

## 1.0.0

Initial release. Snowplow iOS tracker fork with the Surfside plugin: source, segment, and location
contexts; product, transaction, impression, and promotion commerce data; commerce actions; and the
identity and auction methods since superseded or deprecated as described above.
