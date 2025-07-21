# Surfside iOS Tracker

Surfside is a technology company that powers the infrastructure, APIs, and software businesses need to quickly build custom ad platforms for personalized commerce, native ads, sponsored listings, internal promotions, and more.

We help retailers unlock new value to personalize, grow, and monetize their customer experiences like never before. Meanwhile, brands and advertisers can tap into an entirely new performance channel, reaching relevant, high-intent consumers when and where they are most likely to buy. 

Surfside iOS Tracker is a Swift Package that provides Surfside iOS tracker. It includes custom event tracking, commerce contexts, and Surfside-specific data collection capabilities.



## Features

- **SurfsideEvent**: Extends Surfside Tracker with advanced functionality for tracking user and commerce events
- **Global Context Management**: Persistent contexts for source, segment, and location data
- **Commerce Event Tracking**: Product, transaction, and promotion contexts with automatic cleanup
- **Easy Setup**: Helper utilities for quick tracker configuration with environment-based endpoints
- **Multiple Tracker Support**: Manage multiple trackers with different configurations
- **Swift Package Manager**: Modern Swift package integration

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

## Quick Start

### 1. Create Tracker with SurfsideHelper

#### Environment-Based Configuration (Recommended)

```swift
import SurfsideTracker

// Create a tracker with environment-based configuration
let result = SurfsideHelper.createTracker(
    namespace: "myApp",
    environment: .development, // or .production
    accountId: "your-account-id",
    sourceId: "your-source-id",
    appId: "com.yourcompany.yourapp" // your unique bundle id
)

let tracker = result.tracker
let surfsideEvent = result.plugin
```

**Environment Endpoints:**
- `.development` → `https://c-dev.surfside.io` (for testing only)
- `.production` → `https://col.surfside.io` (**recommended for all production use**)
- Default method: `POST`

> **Important:** All production applications should use `col.surfside.io` as the collector endpoint. This ensures optimal data delivery and processing through Surfside's infrastructure.

#### Manual Configuration

```swift
// Create a tracker with custom endpoint and method
let result = SurfsideHelper.createTracker(
    namespace: "myApp",
    endpoint: "https://your-custom-collector.com",
    method: .post, // or .get
    accountId: "your-account-id",
    sourceId: "your-source-id",
    appId: "com.yourcompany.yourapp" // optional
)

let tracker = result.tracker
let surfsideEvent = result.plugin
```

### 2. Set Global Contexts

Global contexts persist across all events and are automatically attached:

```swift
// Source context is automatically set during tracker creation
// But you can update it if needed:
surfsideEvent.source(
    accountId: "updated-account-id",
    sourceId: "updated-source-id"
)

// Set location context (persists for all future events)
surfsideEvent.setLocation(
    id: "store-123",
    name: "Downtown Store",
    street: "123 Main St",
    city: "New York",
    state: "NY",
    zip: "10001",
    country_code: "US",
    latitude: "40.7128",
    longitude: "-74.0060"
)

// Set user segment context with both ID and value
surfsideEvent.segment(
    segmentId: "premium-users",
    segmentVal: "gold-tier"
)

// Identify user
surfsideEvent.identifyUser(
    userId: "user-12345",
    email: "user@example.com"
)
```

### 3. Track Commerce Events

Commerce contexts are temporary and cleared after the commerce action:

```swift
// Add product contexts (temporary)
surfsideEvent.addProduct(
    id: "product-123",
    name: "Premium Widget",
    price: NSNumber(value: 29.99),
    quantity: NSNumber(value: 2),
    category: "Electronics",
    brand: "WidgetCorp"
)

surfsideEvent.addProduct(
    id: "product-456",
    name: "Basic Widget",
    price: NSNumber(value: 19.99),
    quantity: NSNumber(value: 1),
    category: "Electronics"
)

// Add transaction context (temporary)
surfsideEvent.addTransaction(
    id: "txn-789",
    revenue: NSNumber(value: 79.97),
    currency: "USD",
    tax: NSNumber(value: 6.40),
    shipping: NSNumber(value: 5.99),
    coupon: "SAVE10"
)

// Track commerce action - this sends the event with ALL contexts
// Global contexts (source, location, segment, user) + commerce contexts (products, transaction)
surfsideEvent.setCommerceAction(action: "purchase")

// Commerce contexts are now cleared, but global contexts remain
```

### 4. Track Events

#### Screen View Events (iOS)

Track screen views in your iOS app:

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

Track iOS-specific events and contexts:

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

All these events will automatically include your global contexts (source, location, segment, user).

#### Standard Events

Regular events automatically get global contexts attached:

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
surfsideEvent.removeLocation()
surfsideEvent.removeSegment()

// Location context removed - subsequent events won't include it
tracker.track(Structured(category: "test", action: "after_location_removed"))

// Set location context again
surfsideEvent.setLocation(
    id: "store-123",
    name: "Downtown Store",
    street: "123 Main St",
    city: "New York",
    state: "NY",
    zip: "10001",
    country_code: "US",
    latitude: "40.7128",
    longitude: "-74.0060"
)

// Ready for next commerce event
```

### Global Context Methods

These methods set persistent contexts that are attached to ALL subsequent events:

```swift
// Source context - identifies the data source
surfsideEvent.source(
    accountId: "account-123",
    sourceId: "mobile-app"
)

// User segment context with both ID and value
surfsideEvent.segment(
    segmentId: "premium-users",
    segmentVal: "high-value"
)

// Location context with full details
surfsideEvent.setLocation(
    id: "store-123",
    name: "Downtown Store",
    street: "123 Main St",
    city: "New York",
    state: "NY",
    zip: "10001",
    country_code: "US",
    latitude: "40.7128",
    longitude: "-74.0060"
)

// User identification
surfsideEvent.identifyUser(
    userId: "user-12345",
    email: "user@example.com",
    phone: "+1-555-123-4567"
)
```

### Commerce Context Methods

These methods set temporary contexts that are cleared after a commerce action:

```swift
// Product context
surfsideEvent.addProduct(
    id: "product-123",
    name: "Widget",
    price: NSNumber(value: 29.99),
    quantity: NSNumber(value: 1),
    category: "Electronics",
    brand: "WidgetCorp"
)

// Transaction context
surfsideEvent.addTransaction(
    id: "txn-789",
    revenue: NSNumber(value: 29.99),
    currency: "USD",
    tax: NSNumber(value: 2.40),
    shipping: NSNumber(value: 5.99)
)

// Promotion context
surfsideEvent.addPromotion(
    id: "promo-456",
    name: "Summer Sale",
    creative: "banner-ad",
    position: "header"
)

// Impression context
surfsideEvent.addImpression(
    id: "impression-101",
    name: "Product Listing",
    category: "Electronics",
    list: "search-results",
    position: 3,
    price: 29.99
)
```

### Event Tracking Methods

```swift
// Commerce action - sends event with all contexts
surfsideEvent.setCommerceAction(
    action: "purchase", // or "add_to_cart", "remove_from_cart", etc.
    trackerNamespaces: ["myApp"] // optional, defaults to all trackers
)

// Custom event with automatic context attachment
surfsideEvent.trackEvent(
    schema: "iglu:com.example/custom_event/jsonschema/1-0-0",
    payload: ["key": "value"],
    trackerNamespaces: ["myApp"] // optional
)
```


## Advanced Usage

### Multiple Trackers

```swift
// Create multiple trackers for different environments
let devResult = SurfsideHelper.createTracker(
    namespace: "dev",
    environment: .development,
    accountId: "dev-account",
    sourceId: "mobile-dev"
)

let prodResult = SurfsideHelper.createTracker(
    namespace: "prod",
    environment: .production,
    accountId: "prod-account",
    sourceId: "mobile-prod"
)

// Track to specific tracker
devResult.plugin.setCommerceAction(action: "test_purchase", trackerNamespaces: ["dev"])
prodResult.plugin.setCommerceAction(action: "purchase", trackerNamespaces: ["prod"])
```

### Context Lifecycle

```swift
// Set persistent contexts (attached to all events)
surfsideEvent.source(accountId: "account-123", sourceId: "mobile")
surfsideEvent.setLocation(id: "store-123", city: "New York")
surfsideEvent.segment(segmentId: "premium", segmentVal: "gold")

// Regular event includes persistent contexts
tracker.track(SelfDescribing(schema: "event1", payload: [:]))
// ^ This event includes: source + location + segment contexts

// Add temporary commerce contexts
surfsideEvent.addProduct(id: "product-1", name: "Widget")
surfsideEvent.addTransaction(id: "txn-123", revenue: NSNumber(value: 25.00))

// Commerce action includes ALL contexts
surfsideEvent.setCommerceAction(action: "purchase")
// ^ This event includes: source + location + segment + product + transaction contexts
// ^ Commerce contexts are cleared after this event

// This event only includes persistent contexts
tracker.track(SelfDescribing(schema: "event2", payload: [:]))
// ^ This event includes: source + location + segment contexts (no commerce contexts)
```

### Context Management

```swift
// Update contexts
surfsideEvent.segment(segmentId: "vip", segmentVal: "platinum") // replaces previous segment
surfsideEvent.setLocation(id: "store-456", city: "Los Angeles") // replaces previous location

// Remove contexts
surfsideEvent.removeSegment() // removes current segment
surfsideEvent.removeLocation() // removes current location

// Clear commerce contexts manually (usually automatic after commerce action)
surfsideEvent.clearCommerceContexts()
```


## Best Practices

### 1. Initialize Early
```swift
// In AppDelegate or SceneDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    var surfsideTracker: SurfsideTrackerResult?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        surfsideTracker = SurfsideHelper.createTracker(
            namespace: "myApp",
            environment: .production,
            accountId: "account-123",
            sourceId: "mobile-app"
        )
        
        return true
    }
}
```

### 2. Set Global Contexts Early
```swift
// Set persistent contexts once
surfsideEvent.source(accountId: "account-123", sourceId: "mobile")
surfsideEvent.identifyUser(userId: currentUser.id)
surfsideEvent.setLocation(id: currentStore.id, city: currentStore.city)
surfsideEvent.segment(segmentId: "premium", segmentVal: "gold")

// These will be attached to all subsequent events automatically
```

### 3. Commerce Event Pattern
```swift
// Build up commerce contexts
surfsideEvent.addProduct(id: "1", name: "Widget A", price: NSNumber(value: 10.00))
surfsideEvent.addProduct(id: "2", name: "Widget B", price: NSNumber(value: 15.00))
surfsideEvent.addTransaction(id: "txn-123", revenue: NSNumber(value: 25.00), currency: "USD")

// Send commerce action (contexts are automatically cleared after)
surfsideEvent.setCommerceAction(action: "purchase")

// Ready for next commerce event
```

### 4. Context Updates
```swift
// Update contexts when user state changes
func userChangedLocation(to newStore: Store) {
    surfsideEvent.setLocation(
        id: newStore.id,
        city: newStore.city,
        state: newStore.state
    )
}

func userChangedSegment(to newSegment: String, value: String) {
    surfsideEvent.segment(
        segmentId: newSegment,
        segmentVal: value
    )
}
```

## Troubleshooting

### Common Issues

**Events not appearing in collector:**
```swift
// Check network configuration
print("Endpoint: \(networkConfig.endpoint)")
print("Method: \(networkConfig.method)")

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

// Check if tracker is registered with SurfsideController
let registeredTracker = SurfsideController.shared.getTracker(namespace: "myApp")
if registeredTracker == nil {
    print("❌ Tracker not registered with SurfsideController")
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
🔧 Creating SurfsideEvent plugin for tracker with namespace: myApp
✅ SurfsideEvent plugin added to tracker
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


