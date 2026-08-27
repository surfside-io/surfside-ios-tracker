# Surfside iOS Tracker

**Documents release 2.0.0** · Swift Package · product name `SurfsideTracker`

The Surfside iOS Tracker is the mobile client for Surfside's commerce media platform. It feeds
first-party commerce events — product views, cart activity, transactions, impressions, promotions —
from an iOS app into Surfside for measurement, modeling, and audience activation.

It is a fork of the Snowplow iOS tracker, so everything the Snowplow tracker can do (screen views,
lifecycle, timing, structured and self-describing events, session and platform contexts) is
available, with Surfside's commerce and account contexts layered on top.

---

## Release status of 2.0.0

2.0.0 is the first release we recommend for client integration. Not every method on the SDK is
production-ready — the table below is the contract.

| Area | API | Status in 2.0.0 |
| --- | --- | --- |
| Tracker setup | `SurfsideHelper.createTracker(...)` | ✅ Stable |
| Account / source context | `source(accountId:sourceId:)` | ✅ Stable |
| Segment context | `segment(segmentId:segmentVal:)`, `removeSegment()` | ✅ Stable |
| Location context | `setLocation(...)`, `removeLocation()` | ✅ Stable |
| Commerce contexts | `addProduct`, `addTransaction`, `addImpression`, `addPromotion` | ✅ Stable |
| Commerce action | `setCommerceAction(action:)` | ✅ Stable |
| Snowplow core events | `tracker.track(...)` | ✅ Stable (upstream) |
| **Identity** | `setUser`, `identifyUser`, `setSurfId` | ⚠️ **Do not integrate yet — see [Identity](#identity--arrives-in-21)** |
| **Advertising / auction** | `auctionInit`, `bidRequested`, `bidResponse`, `bidderDone`, `bidderError`, `noBid` | ⛔ **Not supported — see [Advertising](#advertising--auction-methods-not-supported)** |

> **Integrate the ✅ rows now.** The identity methods land as a supported, documented surface in
> **2.1.0**; adopting them is an additive change to your integration at that point — nothing you
> build against 2.0.0 needs to be rewritten.

---

## Requirements

| | |
| --- | --- |
| Platforms (package manifest) | iOS 11.0+, macOS 10.13+, tvOS 12.0+, watchOS 6.0+, visionOS 1.0+ (visionOS requires a Swift 5.9+ toolchain) |
| Recommended minimum | **iOS 13.0+** — the SwiftUI screen-tracking helpers (`.snowplowScreen(name:)`) require iOS 13 |
| Swift tools version | 5.3 (a 5.9 manifest is also provided and preferred by newer toolchains) |
| Dependencies | None at runtime. `Mocker` is a test-only dependency. |

## Installation

### Swift Package Manager (Xcode)

1. **File → Add Package Dependencies…**
2. Enter `https://github.com/surfside-io/surfside-ios-tracker.git`
3. Dependency rule: **Up to Next Major Version**, starting at `2.0.0`
4. Add the **`SurfsideTracker`** library to your app target

### Swift Package Manager (`Package.swift`)

```swift
dependencies: [
    .package(url: "https://github.com/surfside-io/surfside-ios-tracker.git", from: "2.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SurfsideTracker", package: "surfside-ios-tracker")
        ]
    )
]
```

### Import name

```swift
import SurfsideTracker   // ✅ correct — the product/module name
// import Surfside       // ❌ that is the *package* name, not the module
// import SnowplowTracker // ❌ upstream module name, not used by this fork
```

---

## Quick start

```swift
import SurfsideTracker

// 1 — create a tracker. Do this once, as early as possible in app startup.
let result = SurfsideHelper.createTracker(
    namespace: "myApp",                  // your label for this tracker instance
    environment: .production,            // .production → https://col.surfside.io
    accountId: "your-account-id",        // supplied by Surfside
    sourceId: "your-source-id",          // supplied by Surfside
    appId: "com.yourcompany.yourapp"     // your bundle identifier
)

let tracker = result.tracker             // TrackerController — Snowplow surface
let surfside = result.plugin             // SurfsideEvent — Surfside commerce surface

// 2 — set the contexts that describe *who and where* (persist across all events).
// Note: Swift requires arguments in declaration order — see setLocation below.
surfside.setLocation(id: "store-123", country_code: "US", state: "NY", city: "New York")
surfside.segment(segmentId: "loyalty_tier", segmentVal: "gold")

// 3 — describe a commerce moment, then send it.
surfside.addProduct(
    id: "sku-123",
    name: "Premium Widget",
    category: "Electronics",
    price: NSNumber(value: 29.99),
    quantity: NSNumber(value: 2),
    currency: "USD"
)
surfside.setCommerceAction(action: "add_to_cart")
```

`createTracker` sets the source context for you from `accountId` / `sourceId`, registers the tracker
with `SurfsideController`, and uses `POST`.

### Collector endpoints

| Environment | Endpoint | Use |
| --- | --- | --- |
| `.production` | `https://col.surfside.io` | **All production traffic.** |
| `.development` | `https://c-dev.surfside.io` | Integration testing only. Data here is not for reporting. |

Point release builds at `.production`. If you need a non-standard endpoint (a proxy, or a local
[Snowplow Micro](https://docs.snowplow.io/docs/testing-debugging/snowplow-micro/) for local
verification), use the manual overload:

```swift
let result = SurfsideHelper.createTracker(
    namespace: "myApp",
    endpoint: "http://localhost:9090",
    method: .post,
    accountId: "your-account-id",
    sourceId: "your-source-id",
    appId: "com.yourcompany.yourapp"
)
```

---

## How the context model works

Everything the SDK sends is an **event** with **entities** (contexts) attached. There are two
lifetimes, and the difference is the single most important thing to understand:

**Persistent contexts** — `source`, `segment`, `location` (and, from 2.1, identity). Set once; the
SDK attaches them to *every* subsequent event, including plain Snowplow events like screen views.
Implemented on top of Snowplow's `globalContexts`, one tag per context type
(`surfside-source`, `surfside-segment`, `surfside-location`, …). Calling a setter again **replaces**
the previous value rather than adding a second copy.

**Commerce contexts** — `addProduct`, `addTransaction`, `addImpression`, `addPromotion`. These
accumulate in a buffer, attach to the next `setCommerceAction(...)` event, and are **cleared**
immediately after it. They describe one commerce moment, not app-wide state.

```swift
surfside.addProduct(id: "sku-1", name: "Widget A", price: NSNumber(value: 10.00))
surfside.addProduct(id: "sku-2", name: "Widget B", price: NSNumber(value: 15.00))
surfside.addTransaction(id: "order-123", revenue: NSNumber(value: 25.00), currency: "USD")

surfside.setCommerceAction(action: "purchase")
// → one commerce action event carrying: source + segment + location
//                                     + 2 product entities + 1 transaction entity
// → the product/transaction entities are now cleared; the persistent ones remain

_ = tracker.track(ScreenView(name: "OrderConfirmation"))
// → carries source + segment + location only
```

`setCommerceAction` flushes the emitter, so the event is sent immediately rather than waiting for
the next batch.

### Tracker namespaces

Every Surfside method takes an optional `trackerNamespaces: [String]?`. Omit it and the call applies
to **all registered trackers** — which is what you want with a single tracker. Pass an explicit array
when you run more than one (see [Multiple trackers](#multiple-trackers)).

---

## API reference

### Persistent contexts

```swift
// Account / source — normally set for you by createTracker. Call it to change accounts at runtime.
surfside.source(accountId: "account-123", sourceId: "mobile-app")

// Audience segment. Both arguments are required.
surfside.segment(segmentId: "loyalty_tier", segmentVal: "gold")
surfside.removeSegment()                          // drop it
surfside.removeSegment(segmentId: "loyalty_tier") // drop only if this is the current segment

// Physical location / store. All fields optional — send what you have.
surfside.setLocation(
    id: "store-123",          // your store or location identifier
    latitude: "40.7128",      // strings, not Doubles
    longitude: "-74.0060",
    country_code: "US",       // ISO code
    zip: "10001",
    state_label: "New York",  // full name
    state: "NY",              // abbreviation
    city: "New York",
    street: "123 Main St",
    name: "Downtown Store",
    parent: "region-northeast",
    type: "store",
    category: "retail"
)
surfside.removeLocation()
```

### Commerce contexts

Numeric arguments are `NSNumber` — the API is `@objc`-exposed, so it cannot use Swift optional
`Double`/`Int`. Wrap with `NSNumber(value:)`.

```swift
surfside.addProduct(
    id: "sku-123",
    name: "Premium Widget",
    list: "search-results",
    brand: "WidgetCorp",
    category: "Electronics",
    variant: "Black",
    price: NSNumber(value: 29.99),
    quantity: NSNumber(value: 2),
    coupon: "SAVE10",
    position: NSNumber(value: 3),
    currency: "USD"
)

surfside.addTransaction(
    id: "order-789",
    affiliation: "iOS App",
    revenue: NSNumber(value: 79.97),   // order grand total
    tax: NSNumber(value: 6.40),
    shipping: NSNumber(value: 5.99),
    coupon: "SAVE10",
    list: "checkout",
    step: NSNumber(value: 3),          // checkout step
    option: "Standard Shipping",
    currency: "USD"
)

surfside.addImpression(
    id: "sku-123",
    name: "Premium Widget",
    list: "search-results",
    brand: "WidgetCorp",
    category: "Electronics",
    variant: "Black",
    position: NSNumber(value: 3),
    price: NSNumber(value: 29.99),
    currency: "USD"
)

surfside.addPromotion(
    id: "promo-456",
    name: "Summer Sale",
    creative: "summer_banner_1",
    position: "home_top",              // String, unlike the other positions
    currency: "USD"
)
```

### Commerce actions

```swift
surfside.setCommerceAction(action: "purchase")
```

`action` is a free-form string that names the commerce moment. Values exercised by this SDK and its
sample app are `impression`, `detail`, `add_to_cart`, and `purchase`. The canonical set your reports
key off is defined by the Surfside platform, not by this SDK — **confirm the values for your account
with your Surfside contact** before shipping, since a typo produces events that no model picks up.

See [SURFSIDE.md](SURFSIDE.md) for a recipe per commerce moment and the exact entity payload each
one puts on the wire.

### Standard events

The full Snowplow event surface works and automatically picks up your persistent Surfside contexts.

```swift
_ = tracker.track(ScreenView(name: "ProductDetail"))

_ = tracker.track(Structured(category: "ui", action: "button_click"))

_ = tracker.track(SelfDescribing(
    schema: "iglu:com.example/custom_event/jsonschema/1-0-0",
    payload: ["key": "value"]
))

_ = tracker.track(Timing(category: "app_performance", variable: "screen_load_ms", timing: 1500))

_ = tracker.track(TrackerError(source: "network", message: "Failed to load products"))
```

`track` returns the event's `UUID` and is **not** marked `@discardableResult`, so assign to `_` (or
keep the ID) to avoid an unused-result warning on every call site.

Optional fields are set with chained builder methods rather than initializer arguments — the
initializers take only the required fields:

```swift
_ = tracker.track(ScreenView(name: "ProductDetail").type("detail").previousName("SearchResults"))

_ = tracker.track(
    Structured(category: "ui", action: "button_click")
        .label("checkout")
        .property("cart_page")
        .value(NSNumber(value: 1))
)
```

SwiftUI automatic screen tracking (iOS 13+):

```swift
struct ProductDetailView: View {
    var body: some View {
        VStack { /* … */ }
            .snowplowScreen(name: "ProductDetail")
    }
}
```

There is no Surfside-specific `trackEvent` wrapper — track custom events through
`tracker.track(SelfDescribing(...))`. Contexts attach either way.

### Multiple trackers

```swift
let prod = SurfsideHelper.createTracker(
    namespace: "prod", environment: .production,
    accountId: "prod-account", sourceId: "mobile-prod"
)
let dev = SurfsideHelper.createTracker(
    namespace: "dev", environment: .development,
    accountId: "dev-account", sourceId: "mobile-dev"
)

// Scope every call, or it hits both trackers.
prod.plugin.addProduct(id: "sku-1", name: "Widget", trackerNamespaces: ["prod"])
prod.plugin.setCommerceAction(action: "purchase", trackerNamespaces: ["prod"])
```

### Manual setup without `SurfsideHelper`

Use this when you need to configure session timeouts, autotracking, or other Snowplow
configuration objects.

```swift
let networkConfig = NetworkConfiguration(endpoint: "https://col.surfside.io", method: .post)

let trackerConfig = TrackerConfiguration()
trackerConfig.appId = "com.yourcompany.yourapp"
trackerConfig.sessionContext = true
trackerConfig.platformContext = true
trackerConfig.lifecycleAutotracking = true

let tracker = Surfside.createTracker(
    namespace: "myApp",
    network: networkConfig,
    configurations: [trackerConfig]
)

let surfside = SurfsideEvent()
tracker.plugins.add(plugin: surfside)          // register the plugin
SurfsideController.shared.registerTracker(tracker)  // required — contexts are keyed by namespace
surfside.source(accountId: "your-account-id", sourceId: "your-source-id")
```

Both the `plugins.add` and the `registerTracker` call are required. `SurfsideController` holds the
per-namespace context state; a tracker that is not registered silently receives no Surfside contexts.

### Clearing state

```swift
surfside.removeSegment()
surfside.removeLocation()

// Discard buffered commerce contexts without sending an action —
// e.g. the user abandoned a flow you had already staged products for.
SurfsideController.shared.clearCommerceContexts(for: "myApp")

// Force a send instead of waiting for the next batch.
SurfsideController.shared.flushEvents(for: "myApp")
```

---

## Identity — arrives in 2.1

`setUser`, `identifyUser`, and `setSurfId` exist in 2.0.0 and will compile, **but do not wire them
into your integration yet.**

The identity contexts iOS emits today (`iglu:io.surfside/user`, `iglu:io.surfside/surfId`, and an
`iglu:io.surfside/identify` event) do not match the identity contract the Surfside web SDK and the
platform's schema registry use. Identity sent from iOS on 2.0.0 is therefore **not resolved or
modeled downstream** — the calls succeed on the device and the data goes nowhere useful. Calling
them costs you nothing but buys you nothing.

**2.1.0 makes identity a supported surface.** Planned changes, all confined to the identity methods:

- the user context repoints to the platform's `io.surfside.identity/user` schema (version `1-0-2`);
- `hashed_email` and `hashed_phone` are computed **on the device** as
  `Base64(SHA-256(UID2-normalized value))`, matching the web SDK and the server-side hasher, so raw
  email and phone no longer need to leave the app to resolve an identity;
- `setSurfId` is replaced by the platform's UID context (`uid2`), aligning iOS with web identity
  resolution;
- `identifyUser` aligns with the web SDK's behavior.

Nothing above changes the commerce, location, segment, or source APIs. When 2.1.0 ships, adopting
identity is **additive** — bump the version and add the identity calls to code you already have in
production.

Details are subject to change until 2.1.0 tags; treat this section as direction, not a frozen API.
If you have a launch that depends on transaction-linked identity on iOS, talk to us about timing
before you plan around it.

## Advertising / auction methods (not supported)

`auctionInit`, `bidRequested`, `bidResponse`, `bidderDone`, `bidderError`, and `noBid` are present in
2.0.0 but **unsupported**: the schemas they emit are not registered on the platform, so the events
are not processed. They are retained only for source compatibility with 1.0.0 and are candidates for
removal in a future major version. Do not build against them.

---

## Versioning

This package follows [Semantic Versioning](https://semver.org/). Tags are **bare semver with no `v`
prefix** (`2.0.0`, not `v2.0.0`) — SPM treats the two forms as unrelated version series, so pin
against the bare form.

```swift
// Recommended: take patches and minors, never a breaking change unattended.
.package(url: "https://github.com/surfside-io/surfside-ios-tracker.git", from: "2.0.0")
```

`from: "2.0.0"` picks up 2.1.0 automatically when it ships, which is what you want — 2.1 is additive
for the APIs documented here. See [CHANGELOG.md](CHANGELOG.md) for what changed and what is coming.

**2.0.0 is the feature release**; 2.0.1 is a documentation-only patch on identical code, tagged so a
pinned checkout carries these docs. Either resolves to the same SDK behavior.

### Two version numbers, both correct

You will see a second, unrelated version number — **6.2.2** — and it is not a mistake:

| Where you see it | What it is |
| --- | --- |
| Release tag, SPM pin (`2.0.0`) | **The Surfside release.** This is the one you pin. |
| `"tv": "ios-6.2.2"` in every payload | The **upstream Snowplow tracker version** this SDK forks. Snowplow's own tooling reads `tv`, so it correctly reports the underlying tracker, not the Surfside release. |
| `VERSION` file, `SnowplowTracker.podspec` | The same upstream Snowplow number, for the same reason. |

Pin against the Surfside tag; expect the Snowplow number on the wire.

**Maintainers:** tag annotated releases so the tagger, date, and message are recorded:

```bash
git tag -a 2.0.0 -m "2.0.0 — commerce tracking correctness"
git push origin 2.0.0
```

---

## Verifying your integration

Point a debug build at a local [Snowplow Micro](https://docs.snowplow.io/docs/testing-debugging/snowplow-micro/)
collector and inspect what actually leaves the device:

```bash
docker run --rm -p 9090:9090 snowplow/snowplow-micro:latest
# then: SurfsideHelper.createTracker(namespace:"dev", endpoint:"http://localhost:9090", method:.post, …)
# good events:  http://localhost:9090/micro/good
# rejected:     http://localhost:9090/micro/bad
```

Check that each commerce action arrives with the entities you expect, and that persistent contexts
(source, segment, location) appear on unrelated events too.

Each event will report `"tv": "ios-6.2.2"` — that is the upstream Snowplow tracker version, not the
Surfside release you pinned. See [Two version numbers](#two-version-numbers-both-correct).

## Troubleshooting

**Nothing arrives at the collector**

```swift
print("namespace:", tracker.namespace)
print("plugins:", tracker.plugins.identifiers)          // expect "Surfside"
print("registered:", SurfsideController.shared.getTrackerNamespaces())
```

On a simulator, also confirm the device has network access and that `.production` is not being
blocked by a proxy or App Transport Security rule (`col.surfside.io` is HTTPS; a local Micro over
plain HTTP needs an ATS exception).

**Contexts are missing from events**

Most often the tracker was never registered with `SurfsideController` (only possible with manual
setup — `SurfsideHelper.createTracker` does it for you):

```swift
if SurfsideController.shared.getTracker(namespace: "myApp") == nil {
    print("❌ tracker not registered with SurfsideController")
}
```

Also check the namespace strings match exactly — context state is keyed by namespace, and a typo
in `trackerNamespaces` fails silently.

**Commerce entities missing from a commerce action**

`setCommerceAction` clears the buffer. A second action fired without re-adding products carries none.
Add contexts → fire one action → repeat.

**Build or import errors**

Import `SurfsideTracker` (the module), not `Surfside` (the package) or `SnowplowTracker` (upstream).

**Debug logging**

The Surfside plugin logs to the console with `print()`. Expect lines like:

```
📡 Adding source context to Snowplow globalContexts for namespace: myApp
✅ Source context added to Snowplow globalContexts for namespace: myApp
📡 Adding segment context to Snowplow globalContexts for namespace: myApp
✅ Segment context added to Snowplow globalContexts for namespace: myApp
Commerce action tracked for namespace: myApp
🧹 Commerce contexts cleared for namespace: myApp
```

A `❌ No tracker found for namespace: …` line means the namespace you passed is not registered.

---

## Building this package from source

```bash
make build            # swift build
make test-unit        # unit tests only — the everyday loop
make test-integration # requires Snowplow Micro on :9090
make micro            # start Micro in the foreground
```

Plain `swift test` runs the integration target too and will fail without Micro running.

## Support

Contact your Surfside representative for account IDs, source IDs, the commerce action values
configured for your account, and integration review.

## License

Copyright (c) 2022-2026 Surfside Solutions Inc, Snowplow Analytics Ltd. All rights reserved.

Redistributed under BSD 3-Clause License. See [LICENSE](LICENSE) for details.
