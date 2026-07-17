# Surfside Plugin for iOS Tracker

The Surfside Plugin provides commerce tracking capabilities for the Surfside iOS Tracker. This plugin allows you to track commerce events with rich contextual information about products, transactions, impressions, and promotions.

> **Stateful vs. discrete API.** This document covers the **stateful** plugin
> (accumulate contexts, then fire them with `setCommerceAction(...)`). There is
> also a **discrete event** API — one-call events like `SurfsidePurchaseEvent`
> that emit the same wire payload without accumulator state. See the README's
> "Discrete Events" section.

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(path: "./surfside-ios-tracker")
]
```

## Quick Start

### 1. Create a Tracker with the Surfside Plugin

`Surfside.createTracker(...)` builds the tracker, attaches the Surfside plugin,
and fires the initial source context. It returns both objects — keep them:

```swift
import SurfsideTracker

let result = Surfside.createTracker(
    namespace: "surf",
    environment: .production, // or .development
    accountId: "your-account-id",
    sourceId: "your-source-id",
    appId: "com.yourcompany.yourapp" // optional
)

let tracker = result.tracker          // TrackerController — track events on this
let surfsidePlugin = result.plugin    // SurfsidePlugin — already attached to the tracker
```

The plugin is attached during `createTracker`, so there is no separate
registration step. If you build a tracker elsewhere (e.g. via remote
configuration), attach the plugin with
`Surfside.addSurfsidePlugin(to:accountId:sourceId:)` instead.

### 2. Use the Surfside Plugin

```swift
// Add product context
surfsidePlugin.addProduct(
    id: "product123",
    name: "Example Product",
    list: "Featured Products",
    brand: "Example Brand",
    category: "Electronics",
    variant: "Black",
    price: NSNumber(value: 99.99),
    position: NSNumber(value: 1),
    currency: "USD"
)

// Track the commerce action
surfsidePlugin.setCommerceAction(action: "view")
```

## Tracking Commerce Events

### Product Views

```swift
// Add product context
surfsidePlugin.addProduct(
    id: "product123",
    name: "Example Product",
    list: "Featured Products",
    brand: "Example Brand",
    category: "Electronics",
    variant: "Black",
    price: NSNumber(value: 99.99),
    position: NSNumber(value: 1),
    currency: "USD"
)

// Track the commerce action
surfsidePlugin.setCommerceAction(action: "view")
```

### Checkout

```swift
// Add transaction context
surfsidePlugin.addTransaction(
    id: "order123",
    affiliation: "Example Store",
    revenue: "99.99",
    tax: NSNumber(value: 8.99),
    shipping: NSNumber(value: 5.99),
    coupon: "SUMMER10",
    step: NSNumber(value: 1),
    option: "Standard Shipping",
    currency: "USD"
)

// Add product context
surfsidePlugin.addProduct(
    id: "product123",
    name: "Example Product",
    brand: "Example Brand",
    category: "Electronics",
    variant: "Black",
    price: NSNumber(value: 99.99),
    quantity: NSNumber(value: 1),
    currency: "USD"
)

// Track the commerce action
surfsidePlugin.setCommerceAction(action: "checkout")
```

### Purchase

```swift
// Add transaction context
surfsidePlugin.addTransaction(
    id: "order123",
    affiliation: "Example Store",
    revenue: "99.99",
    tax: NSNumber(value: 8.99),
    shipping: NSNumber(value: 5.99),
    coupon: "SUMMER10",
    currency: "USD"
)

// Add product context
surfsidePlugin.addProduct(
    id: "product123",
    name: "Example Product",
    brand: "Example Brand",
    category: "Electronics",
    variant: "Black",
    price: NSNumber(value: 99.99),
    quantity: NSNumber(value: 1),
    coupon: "PRODUCT10",
    currency: "USD"
)

// Track the commerce action
surfsidePlugin.setCommerceAction(action: "purchase")
```

### Impressions

```swift
// Add impression context
surfsidePlugin.addImpression(
    id: "product123",
    name: "Example Product",
    list: "Featured Products",
    brand: "Example Brand",
    category: "Electronics",
    variant: "Black",
    position: NSNumber(value: 1),
    price: "99.99",
    currency: "USD"
)

// Track the commerce action
surfsidePlugin.setCommerceAction(action: "impression")
```

### Promotions

```swift
// Add promotion context
surfsidePlugin.addPromotion(
    id: "promo123",
    name: "Summer Sale",
    creative: "summer_banner_1",
    position: "home_top",
    currency: "USD"
)

// Track the commerce action
surfsidePlugin.setCommerceAction(action: "promotion_view")
```

## Multiple Trackers

The Surfside plugin supports multiple trackers. Create one per namespace; each
tracker self-registers in Snowplow's tracker registry. By default the plugin
methods fan out to all trackers — pass `trackerNamespaces` to target specific
ones:

```swift
// Create multiple trackers
let t1 = Surfside.createTracker(namespace: "tracker1", environment: .production,
                                accountId: "acct", sourceId: "src")
let t2 = Surfside.createTracker(namespace: "tracker2", environment: .production,
                                accountId: "acct", sourceId: "src")

// Add product context to specific trackers
surfsidePlugin.addProduct(
    id: "product123",
    name: "Example Product",
    trackerNamespaces: ["tracker1"]
)

// Track the commerce action against specific trackers
surfsidePlugin.setCommerceAction(
    action: "view",
    trackerNamespaces: ["tracker1"]
)
```