# Surfside iOS Tracker

**Documents release 2.1.0** · Swift Package · product name `SurfsideTracker`

The Surfside iOS Tracker is the mobile client for Surfside's commerce media platform. It feeds
first-party commerce events (product views, cart activity, and transactions) from an iOS app into
Surfside for measurement, modeling, and audience activation.

It is a fork of the Snowplow iOS tracker, so everything the Snowplow tracker can do (screen views,
lifecycle, timing, structured and self-describing events, session and platform contexts) is
available, with Surfside's commerce and account contexts layered on top.

---

## Release status of 2.1.0

2.1.0 adds a supported **identity** surface on top of 2.0.0's commerce SDK. Not every method is
production-ready. The table below is the contract.

| Area | API | Status in 2.1.0 |
| --- | --- | --- |
| Tracker setup | `SurfsideHelper.createTracker(...)` | ✅ Stable |
| Account / source context | `source(accountId:sourceId:)` | ✅ Stable |
| Segment context | `segment(segmentId:segmentVal:)`, `removeSegment()` | ✅ Stable |
| Location context | `setLocation(...)`, `removeLocation()` | ✅ Stable |
| Commerce contexts | `addProduct`, `addTransaction` | ✅ Stable |
| Commerce action | `setCommerceAction(action:)` | ✅ Stable |
| Snowplow core events | `tracker.track(...)` | ✅ Stable (upstream) |
| **Identity** | `setUser`, `removeUser`, `getResolvedIdentity` | ✅ **Stable, see [Identity](#identity)** |

> **Adopting identity is additive.** It layers onto a 2.0.0 integration with no changes to the
> commerce, location, segment, or source APIs, bump the dependency and add the identity calls.
> **Removed in 2.1.0:** `setSurfId`, `identifyUser`, and the advertising/auction methods
> (`auctionInit`, `bidRequested`, `bidResponse`, `bidderDone`, `bidderError`, `noBid`), none were
> resolved downstream. If you referenced any on a 2.0.0 build, delete the call; `setUser` is the
> supported identity path.

---

## Requirements

| | |
| --- | --- |
| Platforms (package manifest) | iOS 11.0+, macOS 10.13+, tvOS 12.0+, watchOS 6.0+, visionOS 1.0+ (visionOS requires a Swift 5.9+ toolchain) |
| Recommended minimum | **iOS 13.0+**, the SwiftUI screen-tracking helpers (`.snowplowScreen(name:)`) require iOS 13 |
| Swift tools version | 5.3 (a 5.9 manifest is also provided and preferred by newer toolchains) |
| Dependencies | None at runtime. `Mocker` is a test-only dependency. |

## Installation

### Swift Package Manager (Xcode)

1. **File → Add Package Dependencies…**
2. Enter `https://github.com/surfside-io/surfside-ios-tracker.git`
3. Dependency rule: **Up to Next Major Version**, starting at `2.1.0`
4. Add the **`SurfsideTracker`** library to your app target

### Swift Package Manager (`Package.swift`)

```swift
dependencies: [
    .package(url: "https://github.com/surfside-io/surfside-ios-tracker.git", from: "2.1.0")
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
import SurfsideTracker   // ✅ correct: the product/module name
// import Surfside       // ❌ that is the *package* name, not the module
// import SnowplowTracker // ❌ upstream module name, not used by this fork
```

---

## Quick start

A standard integration is four steps: create the tracker, add location, add the user when you know
them, then track commerce moments.

```swift
import SurfsideTracker

// 1. Create a tracker once, as early as possible in app startup.
//    This also sets your Surfside source (account + source) for you.
let result = SurfsideHelper.createTracker(
    namespace: "myApp",                  // your label for this tracker instance
    environment: .production,            // .production → https://col.surfside.io
    accountId: "your-account-id",        // supplied by Surfside
    sourceId: "your-source-id",          // supplied by Surfside
    appId: "com.yourcompany.yourapp"     // your bundle identifier
)

let tracker = result.tracker             // TrackerController: Snowplow surface
let surfside = result.plugin             // SurfsideEvent: Surfside commerce surface

// 2. Add location. Persists across every event until you change it.
surfside.setLocation(id: "store-123", country_code: "US", state: "NY", city: "New York")

// 3. Add the user when you know who they are (e.g. after login). Persists until removeUser.
//    email and phone are hashed ON THE DEVICE; raw values never leave it. See Identity below.
surfside.setUser(userId: "your-app-user-id", email: "user@example.com", phone: "+14155550123")

// 4. Track a commerce moment: add the product, then name the action.
surfside.addProduct(
    id: "sku-123",
    name: "Premium Widget",
    category: "Electronics",
    price: NSNumber(value: 29.99),
    currency: "USD"
)
surfside.setCommerceAction(action: "detail")
```

`createTracker` sets the source context for you from `accountId` / `sourceId`, registers the tracker
with `SurfsideController`, and uses `POST`.

The five commerce moments (`detail`, `add`, `remove`, `checkout`, `purchase`) are covered under
[Commerce actions](#commerce-actions) below. **[SURFSIDE.md](SURFSIDE.md) is the full commerce
reference:** a copy-paste recipe for each moment and the exact payload it puts on the wire.

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

**Persistent contexts**: `source`, `segment`, `location`, and identity (`setUser`). Set once; the
SDK attaches them to *every* subsequent event, including plain Snowplow events like screen views.
Implemented on top of Snowplow's `globalContexts`, one tag per context type
(`surfside-source`, `surfside-segment`, `surfside-location`, …). Calling a setter again **replaces**
the previous value rather than adding a second copy.

**Commerce contexts**: `addProduct` and `addTransaction`. These accumulate in a buffer, attach to
the next `setCommerceAction(...)` event, and are **cleared** immediately after it. They describe one
commerce moment, not app-wide state.

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
to **all registered trackers**, which is what you want with a single tracker.

---

## API reference

### Persistent contexts

```swift
// Account / source: normally set for you by createTracker. Call it to change accounts at runtime.
surfside.source(accountId: "account-123", sourceId: "mobile-app")

// Audience segment. Both arguments are required.
surfside.segment(segmentId: "loyalty_tier", segmentVal: "gold")
surfside.removeSegment()                          // drop it
surfside.removeSegment(segmentId: "loyalty_tier") // drop only if this is the current segment

// Physical location / store. All fields optional; send what you have.
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

Numeric arguments are `NSNumber`: the API is `@objc`-exposed, so it cannot use Swift optional
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
```

`addTransaction` belongs to the `checkout` and `purchase` moments only; `detail`, `add`, and
`remove` send a product entity and nothing else.

### Commerce actions

Every commerce event is the same shape: **add entities → name the action**. The action names the
moment; the entities describe it. The standard flow is five moments:

| Moment | What you send | Action |
| --- | --- | --- |
| Product detail viewed | one `addProduct` | `detail` |
| Added to cart | one `addProduct` | `add` |
| Removed from cart | one `addProduct` | `remove` |
| Checkout started | the whole cart (an `addProduct` per line) + one `addTransaction` | `checkout` |
| Purchase completed | the whole cart (an `addProduct` per line) + one `addTransaction` | `purchase` |

`detail`, `add`, and `remove` are product-only: one product entity and the action. **Only `checkout`
and `purchase` carry a transaction** (order id, grand total, tax, shipping) alongside every line item.

```swift
surfside.addProduct(id: "sku-123", name: "Premium Widget", price: NSNumber(value: 29.99), currency: "USD")
surfside.setCommerceAction(action: "add")
```

`action` is a free-form string; the values above are what this SDK exercises. The canonical set your
reports key off is defined by the Surfside platform, not by this SDK. **Confirm the values for your
account with your Surfside contact** before shipping, since a typo produces events that no model picks up.

**[SURFSIDE.md](SURFSIDE.md) is the full commerce reference:** a copy-paste recipe for every moment
above and the exact entity payload each one puts on the wire.

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

Optional fields are set with chained builder methods rather than initializer arguments; the
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

There is no Surfside-specific `trackEvent` wrapper; track custom events through
`tracker.track(SelfDescribing(...))`. Contexts attach either way.

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
SurfsideController.shared.registerTracker(tracker)  // required: contexts are keyed by namespace
surfside.source(accountId: "your-account-id", sourceId: "your-source-id")
```

Both the `plugins.add` and the `registerTracker` call are required. `SurfsideController` holds the
per-namespace context state; a tracker that is not registered silently receives no Surfside contexts.

### Clearing state

```swift
surfside.removeSegment()
surfside.removeLocation()

// Discard buffered commerce contexts without sending an action -
// e.g. the user abandoned a flow you had already staged products for.
SurfsideController.shared.clearCommerceContexts(for: "myApp")

// Force a send instead of waiting for the next batch.
SurfsideController.shared.flushEvents(for: "myApp")
```

---

## Identity

Identity is a **supported surface as of 2.1.0**. Set a user once and the SDK attaches a persistent
identity context to every subsequent event, exactly like `source` / `segment` / `location`.

```swift
// Identify the user. email and phone are hashed ON THE DEVICE; raw values never leave it.
surfside.setUser(
    userId: "your-app-user-id",
    email: "user@example.com",       // -> hashed_email
    phone: "+14155550123"            // -> hashed_phone (UID2 E.164 normalization)
    // optional profile fields: address, age, company, createdAt, dateOfBirth,
    // firstName, gender, lastName
)

// On logout, clear it so later events carry no user identity.
surfside.removeUser()
```

**How identity resolves.** `setUser` emits the platform identity context
`iglu:io.surfside.identity/user/jsonschema/1-0-2`. `email` and `phone` are hashed on-device as
`Base64(SHA-256(UID2-normalized value))`, the same normalization the web SDK and the server-side
hasher use, so **raw email and phone never leave the app**. The Surfside collector resolves the
hashed identifiers to a `uid2` token downstream; iOS rides the same rails the web SDK does. The
app-supplied `userId` is also set as the atomic Snowplow user id.

**Reading identity back:** `getResolvedIdentity(trackerNamespace:)` returns the resolved `userId`
and, when session tracking is on, the stable per-install device id, so a host app can broker
identity to other Surfside SDKs without them depending on the tracker.

**Removed in 2.1.0:** `identifyUser`, `setSurfId`, and the advertising/auction methods
(`auctionInit`, `bidRequested`, `bidResponse`, `bidderDone`, `bidderError`, `noBid`). None were
resolved or modeled downstream; `setUser` is the single supported identity path. If you referenced
any on a 2.0.0 build, delete the call.

Adopting identity is **additive**: it changes none of the commerce, location, segment, or source
APIs. Because 2.1.0 is a minor release, `from: "2.0.0"` picks it up automatically.

---

## Versioning

This package follows [Semantic Versioning](https://semver.org/). Tags are **bare semver with no `v`
prefix** (`2.0.0`, not `v2.0.0`); SPM treats the two forms as unrelated version series, so pin
against the bare form.

```swift
// Recommended: take patches and minors, never a breaking change unattended.
.package(url: "https://github.com/surfside-io/surfside-ios-tracker.git", from: "2.1.0")
```

`from: "2.1.0"` pins the current release and picks up later patches and minors (2.1.x, 2.2.x)
automatically, never a major unattended. Already on `from: "2.0.0"`? That resolves to 2.1.0 too;
2.1 is additive for the APIs documented here. See [CHANGELOG.md](CHANGELOG.md) for what changed.

**2.1.0 is the current release**: it adds the supported identity surface on top of 2.0.0's commerce
SDK. (2.0.1 / 2.0.2 were documentation-only patches on the 2.0.0 code.)

### Two version numbers, both correct

You will see a second, unrelated version number (**6.2.2**), and it is not a mistake:

| Where you see it | What it is |
| --- | --- |
| Release tag, SPM pin (`2.1.0`) | **The Surfside release.** This is the one you pin. |
| `"tv": "ios-6.2.2"` in every payload | The **upstream Snowplow tracker version** this SDK forks. Snowplow's own tooling reads `tv`, so it correctly reports the underlying tracker, not the Surfside release. |
| `VERSION` file, `SnowplowTracker.podspec` | The same upstream Snowplow number, for the same reason. |

Pin against the Surfside tag; expect the Snowplow number on the wire.

**Maintainers:** tag annotated releases so the tagger, date, and message are recorded:

```bash
git tag -a 2.1.0 -m "2.1.0: supported identity surface (setUser, UID2 hashing)"
git push origin 2.1.0
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

Each event will report `"tv": "ios-6.2.2"`; that is the upstream Snowplow tracker version, not the
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
setup, `SurfsideHelper.createTracker` does it for you):

```swift
if SurfsideController.shared.getTracker(namespace: "myApp") == nil {
    print("❌ tracker not registered with SurfsideController")
}
```

Also check the namespace strings match exactly: context state is keyed by namespace, and a typo
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
make test-unit        # unit tests only: the everyday loop
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
