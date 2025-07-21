# Surfside Plugin for iOS Tracker

The Surfside Plugin provides commerce tracking capabilities for the Surfside iOS Tracker. This plugin allows you to track commerce events with rich contextual information about products, transactions, impressions, and promotions.

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/surfside/surfside-ios-tracker.git", from: "1.0.0")
]
```

## Quick Start

### 1. Initialize the Surfside Tracker

```swift
import Surfside

// Create a tracker configuration
let networkConfig = NetworkConfiguration(endpoint: "https://col.surfside.io")
let trackerConfig = TrackerConfiguration()
    .appId("swift-ios-tracker")
    .sessionContext(true)
    .platformContext(true)
    .lifecycleAutotracking(true)
    
// Create the tracker
let namespace = "surf"
let tracker = Surfside.createTracker(
    namespace: namespace,
    network: networkConfig,
    configurations: [trackerConfig]
)
```

### 2. Register the Tracker with Surfside Controller

```swift
import Surfside

// Register the tracker with the SurfsideController
SurfsideController.shared.registerTracker(tracker)
```

### 3. Use the Surfside Plugin

```swift
import Surfside

// Create a Surfside plugin instance
let surfsidePlugin = SurfsidePlugin()

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

The Surfside plugin supports multiple trackers. You can specify which tracker to use when adding contexts or tracking events:

```swift
// Register multiple trackers
SurfsideController.shared.registerTracker(tracker1, namespace: "tracker1")
SurfsideController.shared.registerTracker(tracker2, namespace: "tracker2")

// Add product context to specific trackers
surfsidePlugin.addProduct(
    id: "product123",
    name: "Example Product",
    trackerNamespaces: ["tracker1"]
)

// Track the commerce action with specific trackers
surfsidePlugin.setCommerceAction(
    action: "view",
    trackerNamespaces: ["tracker1"]
)
```