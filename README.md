# Surfside iOS Tracker

Surfside is a technology company that powers the infrastructure, APIs, and software businesses need to quickly build custom ad platforms for personalized commerce, native ads, sponsored listings, internal promotions, and more.

We help retailers unlock new value to personalize, grow, and monetize their customer experiences like never before. Meanwhile, brands and advertisers can tap into an entirely new performance channel, reaching relevant, high-intent consumers when and where they are most likely to buy.

Surfside iOS Tracker is a Swift Package that provides Surfside iOS tracker. It includes custom event tracking, commerce contexts, and Surfside-specific data collection capabilities.



## Features

- **Discrete commerce events**: stateless, one-call events (`SurfsidePurchaseEvent`, `SurfsideAddToCartEvent`, …) — the event-based way to track commerce, assembled explicitly in a single `tracker.track(event)` call
- **SurfsidePlugin**: the stateful commerce API — accumulate product/transaction/promotion/impression contexts, then fire them with `setCommerceAction(...)`
- **Global Context Management**: persistent source, segment, location, and user contexts that are automatically attached to every event
- **Easy Setup**: `Surfside.createTracker(...)` with environment-based endpoints
- **Multiple Tracker Support**: manage multiple trackers with different configurations
- **Swift Package Manager**: modern Swift package integration

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(path: "./surfside-ios-tracker")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the local path or repository URL
3. Select the version and add to your target

### Versioning

This package follows [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`.

**Tagging a release** (for maintainers):

- Use a **bare** semver tag with **no `v` prefix** — e.g. `1.2.0`, not `v1.2.0`. Pick one form and never mix: SPM treats a `v`-prefixed tag and a bare tag as unrelated versions.
- Bump **MAJOR** for breaking API changes, **MINOR** for backward-compatible features, **PATCH** for backward-compatible fixes.
- Create an **annotated** tag (`-a`) so it records the tagger, date, and message — the professional default for a published release, unlike a lightweight tag:

  ```bash
  git tag -a 1.2.0 -m "1.2.0 — <summary of changes>"
  git push origin 1.2.0
  ```

Consumers then pin the version via SPM:

```swift
.package(url: "https://github.com/surfside-io/surfside-ios-tracker.git", from: "1.0.0")
```

## Quick Start

### 1. Create a Tracker

`Surfside.createTracker(...)` builds a Snowplow tracker, attaches the Surfside plugin, and fires the initial source context. It returns a `SurfsideTrackerResult` with two objects you keep:

- `tracker` (`TrackerController`) — track events with `tracker.track(...)`
- `plugin` (`SurfsidePlugin`) — set global contexts and use the stateful commerce API

```swift
import SurfsideTracker

// In your App init or AppDelegate
let result = Surfside.createTracker(
    namespace: "myApp",
    environment: .production, // or .development
    accountId: "your-account-id",
    sourceId: "your-source-id",
    appId: "com.yourcompany.yourapp" // your unique bundle id
)

let tracker = result.tracker
let plugin = result.plugin
```

Hold onto `tracker` and `plugin` for the app's lifetime (e.g. store them on your `App`/`AppDelegate`). You can also fetch the tracker later by namespace — see [Fetching a Tracker Later](#fetching-a-tracker-later).

**Environment Endpoints:**
- `.development` → `https://c-dev.surfside.io` (for testing only)
- `.production` → `https://col.surfside.io` (**recommended for all production use**)
- Default method: `POST`

> **Important:** All production applications should use `col.surfside.io` as the collector endpoint. This ensures optimal data delivery and processing through Surfside's infrastructure.

For a custom collector endpoint, use the manual overload `Surfside.createTracker(namespace:endpoint:method:accountId:sourceId:appId:)`.

### 2. Set Global Contexts

Global contexts persist across all events and are automatically attached. They are set on the `plugin`:

```swift
// Source context is set automatically during createTracker, but you can update it:
plugin.source(
    accountId: "updated-account-id",
    sourceId: "updated-source-id"
)

// Set location context (persists for all future events)
plugin.setLocation(
    id: "store-123",
    latitude: "40.7128",
    longitude: "-74.0060",
    countryCode: "US",
    zip: "10001",
    state: "NY",
    city: "New York",
    street: "123 Main St",
    name: "Downtown Store"
)

// Set user segment context with both ID and value
plugin.segment(
    segmentId: "premium-users",
    segmentVal: "gold-tier"
)

// Identify user
plugin.identifyUser(
    userId: "user-12345",
    email: "user@example.com"
)
```

### 3. Track Commerce Events

There are two ways to track commerce. **Discrete events** (below) are stateless and explicit — recommended for new code. The **stateful plugin API** is also fully supported; see [Stateful Commerce API](#stateful-commerce-api).

#### Discrete Events (recommended)

Build the context entities and track them in one call — no accumulator state to set up or clear:

```swift
// A purchase: products + a transaction
tracker.track(SurfsidePurchaseEvent(
    transaction: CommerceTransactionEntity(
        id: "txn-789",
        revenue: "79.97",   // revenue is a String on the entity
        currency: "USD"
    ),
    products: [
        CommerceProductEntity(
            id: "product-123",
            name: "Premium Widget",
            brand: "WidgetCorp",
            category: "Electronics",
            price: NSNumber(value: 29.99),
            quantity: NSNumber(value: 2)
        ),
        CommerceProductEntity(
            id: "product-456",
            name: "Basic Widget",
            category: "Electronics",
            price: NSNumber(value: 19.99),
            quantity: NSNumber(value: 1)
        )
    ]
))

// A product-detail view
tracker.track(SurfsideProductViewEvent(products: [
    CommerceProductEntity(id: "product-123", name: "Premium Widget", price: NSNumber(value: 29.99))
]))

// Add to cart
tracker.track(SurfsideAddToCartEvent(products: [
    CommerceProductEntity(id: "product-123", name: "Premium Widget")
]))
```

Every discrete event automatically carries the global contexts (source, location, segment, user) on top of its own entities.

**Available events** (the action each maps to in parentheses):

| Event | Action | Entities |
| --- | --- | --- |
| `SurfsideProductViewEvent` | `detail` | products |
| `SurfsideAddToCartEvent` | `add` | products |
| `SurfsideCartViewEvent` | `cart` | products |
| `SurfsideRemoveFromCartEvent` | `remove` | products |
| `SurfsideProductClickEvent` | `click` | products |
| `SurfsideCheckoutEvent` | `checkout` | products + optional transaction |
| `SurfsidePurchaseEvent` | `purchase` | products + transaction |
| `SurfsideRefundEvent` | `refund` | products + transaction |
| `SurfsidePromotionClickEvent` | `promo_click` | promotions |
| `SurfsidePromotionViewEvent` | `promotion_view` | promotions |
| `SurfsideImpressionEvent` | `impression` | impressions |

#### Stateful Commerce API

The `plugin` accumulates temporary commerce contexts, then sends them together on `setCommerceAction(...)`. The commerce contexts are cleared afterward; global contexts remain.

```swift
// Add product contexts (temporary)
plugin.addProduct(
    id: "product-123",
    name: "Premium Widget",
    brand: "WidgetCorp",
    category: "Electronics",
    price: NSNumber(value: 29.99),
    quantity: NSNumber(value: 2)
)

plugin.addProduct(
    id: "product-456",
    name: "Basic Widget",
    category: "Electronics",
    price: NSNumber(value: 19.99),
    quantity: NSNumber(value: 1)
)

// Add transaction context (temporary)
plugin.addTransaction(
    id: "txn-789",
    revenue: NSNumber(value: 79.97),
    tax: NSNumber(value: 6.40),
    shipping: NSNumber(value: 5.99),
    coupon: "SAVE10",
    currency: "USD"
)

// Track commerce action — sends the event with ALL contexts
// Global contexts (source, location, segment, user) + commerce contexts (products, transaction)
plugin.setCommerceAction(action: "purchase")

// Commerce contexts are now cleared, but global contexts remain
```

### 4. Track Other Events

Non-commerce events go through the `tracker`. They automatically include your global contexts (source, location, segment, user).

#### Screen View Events (iOS)

```swift
// Track screen view
tracker.track(ScreenView(
    name: "ProductDetailScreen",
    id: "product-123",
    type: "detail",
    previousName: "ProductListScreen",
    previousId: "list",
    previousType: "list"
))

// SwiftUI automatic screen tracking
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            Text("Hello, World!")
        }
        .snowplowScreen(name: "ContentView")
    }
}
```

#### iOS-Specific Events

```swift
// Application lifecycle events
tracker.track(Background())
tracker.track(Foreground())

// Timing events
tracker.track(Timing(
    category: "app_performance",
    variable: "screen_load_time",
    timing: 1500, // milliseconds
    label: "ProductDetailScreen"
))

// Error tracking
tracker.track(TrackerError(
    source: "network",
    message: "Failed to load product data",
    stackTrace: Thread.callStackSymbols.joined(separator: "\n")
))
```

#### Standard Events

```swift
// Track a page view
tracker.track(PageView(
    pageUrl: "https://example.com/page",
    pageTitle: "Example Page",
    referrer: "https://example.com/previous"
))

// Track a structured event
tracker.track(Structured(
    category: "ui",
    action: "button_click",
    label: "checkout",
    property: "main_page",
    value: 1.0
))

// Track a self-describing event
tracker.track(SelfDescribing(
    schema: "iglu:com.example/custom_event/jsonschema/1-0-0",
    payload: ["key": "value"]
))
```

### Context Removal

```swift
// Remove specific contexts
plugin.removeLocation()
plugin.removeSegment()

// Location context removed - subsequent events won't include it
tracker.track(Structured(category: "test", action: "after_location_removed"))

// Set location context again
plugin.setLocation(
    id: "store-123",
    latitude: "40.7128",
    longitude: "-74.0060",
    countryCode: "US",
    zip: "10001",
    state: "NY",
    city: "New York",
    street: "123 Main St",
    name: "Downtown Store"
)
```

### Global Context Methods

These methods set persistent contexts that are attached to ALL subsequent events:

```swift
// Source context - identifies the data source
plugin.source(
    accountId: "account-123",
    sourceId: "mobile-app"
)

// User segment context with both ID and value
plugin.segment(
    segmentId: "premium-users",
    segmentVal: "high-value"
)

// Location context with full details
plugin.setLocation(
    id: "store-123",
    latitude: "40.7128",
    longitude: "-74.0060",
    countryCode: "US",
    zip: "10001",
    state: "NY",
    city: "New York",
    street: "123 Main St",
    name: "Downtown Store"
)

// User identification
plugin.identifyUser(
    userId: "user-12345",
    email: "user@example.com"
)
```

### Commerce Context Methods

These stateful methods set temporary contexts that are cleared after a commerce action (see [Stateful Commerce API](#stateful-commerce-api)):

```swift
// Product context
plugin.addProduct(
    id: "product-123",
    name: "Widget",
    brand: "WidgetCorp",
    category: "Electronics",
    price: NSNumber(value: 29.99),
    quantity: NSNumber(value: 1)
)

// Transaction context
plugin.addTransaction(
    id: "txn-789",
    revenue: NSNumber(value: 29.99),
    tax: NSNumber(value: 2.40),
    shipping: NSNumber(value: 5.99),
    currency: "USD"
)

// Promotion context
plugin.addPromotion(
    id: "promo-456",
    name: "Summer Sale",
    creative: "banner-ad",
    position: "header"
)

// Impression context
plugin.addImpression(
    id: "impression-101",
    name: "Product Listing",
    list: "search-results",
    category: "Electronics",
    position: NSNumber(value: 3),
    price: NSNumber(value: 29.99)
)
```

### Event Tracking Methods

```swift
// Commerce action - sends event with all accumulated contexts
plugin.setCommerceAction(
    action: "purchase", // or "add", "remove", "checkout", etc.
    trackerNamespaces: ["myApp"] // optional, defaults to all trackers
)

// Custom self-describing events go through the tracker directly;
// global contexts (source, location, segment, user) are attached automatically
tracker.track(SelfDescribing(
    schema: "iglu:com.example/custom_event/jsonschema/1-0-0",
    payload: ["key": "value"]
))
```


## Advanced Usage

### Multiple Trackers

```swift
// Create multiple trackers for different environments
let dev = Surfside.createTracker(
    namespace: "dev",
    environment: .development,
    accountId: "dev-account",
    sourceId: "mobile-dev"
)

let prod = Surfside.createTracker(
    namespace: "prod",
    environment: .production,
    accountId: "prod-account",
    sourceId: "mobile-prod"
)

// Track to a specific tracker via its own plugin/tracker...
dev.plugin.setCommerceAction(action: "test_purchase")
prod.plugin.setCommerceAction(action: "purchase")

// ...or target namespaces explicitly (the plugin fans out to all trackers by default)
prod.plugin.setCommerceAction(action: "purchase", trackerNamespaces: ["prod"])
```

### Fetching a Tracker Later

If you didn't hold onto the `tracker`, fetch it by namespace:

```swift
let tracker = SurfsideController.shared.getTracker(namespace: "myApp")
// or, via Snowplow's native registry:
let tracker = Surfside.tracker(namespace: "myApp")
```

### Context Lifecycle

```swift
// Set persistent contexts (attached to all events)
plugin.source(accountId: "account-123", sourceId: "mobile")
plugin.setLocation(id: "store-123", city: "New York")
plugin.segment(segmentId: "premium", segmentVal: "gold")

// Regular event includes persistent contexts
tracker.track(SelfDescribing(schema: "iglu:com.example/event1/jsonschema/1-0-0", payload: [:]))
// ^ This event includes: source + location + segment contexts

// Add temporary commerce contexts
plugin.addProduct(id: "product-1", name: "Widget")
plugin.addTransaction(id: "txn-123", revenue: NSNumber(value: 25.00))

// Commerce action includes ALL contexts
plugin.setCommerceAction(action: "purchase")
// ^ This event includes: source + location + segment + product + transaction contexts
// ^ Commerce contexts are cleared after this event

// This event only includes persistent contexts
tracker.track(SelfDescribing(schema: "iglu:com.example/event2/jsonschema/1-0-0", payload: [:]))
// ^ This event includes: source + location + segment contexts (no commerce contexts)
```

### Context Management

```swift
// Update contexts
plugin.segment(segmentId: "vip", segmentVal: "platinum") // replaces previous segment
plugin.setLocation(id: "store-456", city: "Los Angeles") // replaces previous location

// Remove contexts
plugin.removeSegment() // removes current segment
plugin.removeLocation() // removes current location

// Clear commerce contexts manually (usually automatic after a commerce action)
SurfsideController.shared.clearCommerceContexts(for: "myApp")
```


## Best Practices

### 1. Create the Tracker Early
```swift
// In AppDelegate or SceneDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    var tracker: TrackerController?
    var plugin: SurfsidePlugin?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let result = Surfside.createTracker(
            namespace: "myApp",
            environment: .production,
            accountId: "account-123",
            sourceId: "mobile-app"
        )
        self.tracker = result.tracker
        self.plugin = result.plugin
        return true
    }
}
```

### 2. Set Global Contexts Early
```swift
// Set persistent contexts once
plugin.source(accountId: "account-123", sourceId: "mobile")
plugin.identifyUser(userId: currentUser.id)
plugin.setLocation(id: currentStore.id, city: currentStore.city)
plugin.segment(segmentId: "premium", segmentVal: "gold")

// These will be attached to all subsequent events automatically
```

### 3. Commerce Event Pattern
```swift
// Discrete event — build entities and track in one call
tracker.track(SurfsidePurchaseEvent(
    transaction: CommerceTransactionEntity(id: "txn-123", revenue: "25.00", currency: "USD"),
    products: [
        CommerceProductEntity(id: "1", name: "Widget A", price: NSNumber(value: 10.00)),
        CommerceProductEntity(id: "2", name: "Widget B", price: NSNumber(value: 15.00))
    ]
))
```

### 4. Context Updates
```swift
// Update contexts when user state changes
func userChangedLocation(to newStore: Store) {
    plugin.setLocation(
        id: newStore.id,
        state: newStore.state,
        city: newStore.city
    )
}

func userChangedSegment(to newSegment: String, value: String) {
    plugin.segment(
        segmentId: newSegment,
        segmentVal: value
    )
}
```

## Troubleshooting

### Common Issues

**Events not appearing in collector:**
```swift
// Verify tracker is created
print("Tracker namespace: \(tracker.namespace)")
print("Tracker plugins: \(tracker.plugins.identifiers)")
```

**Contexts not attached to events:**
```swift
// Verify plugin is registered
if !tracker.plugins.identifiers.contains("Surfside") {
    print("❌ Surfside plugin not registered")
}

// Check if the tracker can be fetched by namespace
if SurfsideController.shared.getTracker(namespace: "myApp") == nil {
    print("❌ No tracker registered for that namespace")
}
```

**Build/Import errors:**
```swift
// Correct import
import SurfsideTracker  // ✅ Correct
// import SnowplowTracker  // ❌ Wrong

// Check Package.swift dependencies
.package(path: "./surfside-ios-tracker")
```

### Debug Logging

The plugin includes comprehensive logging. Look for these patterns:

```
🔧 Creating SurfsidePlugin for tracker with namespace: myApp
✅ SurfsidePlugin added to tracker
📡 Adding source context to Snowplow globalContexts for namespace: myApp
✅ Source context added to Snowplow globalContexts for namespace: myApp
📡 Adding segment context to Snowplow globalContexts for namespace: myApp
📡 SegmentId: premium-users, SegmentVal: gold-tier
✅ Segment context added to Snowplow globalContexts for namespace: myApp
🛒 Adding product context: product-123
💰 Tracking commerce action: purchase
🧹 Clearing commerce contexts for namespace: myApp
```

## Requirements

- iOS 13.0+
- Swift 5.0+
- Xcode 12.0+
- Snowplow iOS Tracker (included as dependency)

## License

Copyright (c) 2022-2025 Surfside Solutions Inc, Snowplow Analytics Ltd. All rights reserved.

Redistributed under BSD 3-Clause License. See LICENSE file for details.
