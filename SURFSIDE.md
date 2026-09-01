# Surfside Commerce Tracking Reference

Companion to [README.md](README.md), which covers installation and setup. This document is the
commerce detail: a recipe per commerce moment, and the exact entity each call puts on the wire.

Applies to **2.1.0**. Import the module as `SurfsideTracker`; the plugin type is `SurfsideEvent`
(the value `SurfsideHelper.createTracker` returns as `.plugin`).

---

## The model in one paragraph

A commerce event is one **commerce action** event carrying **entities** that describe the moment.
`addProduct` and `addTransaction` do not send anything on their own; they buffer an entity per
tracker namespace. `setCommerceAction(action:)` sends one event with everything buffered, plus your
persistent contexts (source, segment, location), then clears the commerce buffer. So the shape is
always: **add (one or more) → act**.

```swift
surfside.addProduct(id: "sku-1", name: "Widget", price: NSNumber(value: 29.99), currency: "USD")
surfside.setCommerceAction(action: "detail")
```

`setCommerceAction` flushes the emitter, so the event leaves the device immediately.

## Schemas emitted

| Call | Emitted as | Schema |
| --- | --- | --- |
| `setCommerceAction` | event | `iglu:io.surfside.commerce/action/jsonschema/1-0-0` |
| `addProduct` | entity | `iglu:io.surfside.commerce/product/jsonschema/1-0-0` |
| `addTransaction` | entity | `iglu:io.surfside.commerce/transaction/jsonschema/1-0-0` |
| `source` | persistent entity | `iglu:io.surfside/context/jsonschema/1-0-0` |
| `segment` | persistent entity | `iglu:io.surfside/segment/jsonschema/1-0-0` |
| `setLocation` | persistent entity | `iglu:io.surfside.local-business/location/jsonschema/1-0-0` |

Identity (`setUser`) is deliberately omitted from this commerce reference; it is a supported
surface as of 2.1.0 and documented in [Identity in the README](README.md#identity).

## Field types on the wire

Every field is optional and omitted entirely when you pass `nil`, so partial data is fine. Swift
numeric arguments are `NSNumber` because the API is `@objc`-exposed; what lands in the JSON is listed
below. Monetary and count fields serialize as JSON numbers, matching the web SDK.

**product**: `iglu:io.surfside.commerce/product/jsonschema/1-0-0`

| Argument | JSON type |
| --- | --- |
| `id`, `name`, `list`, `brand`, `category`, `variant`, `coupon`, `currency` | string |
| `price` | number (double) |
| `quantity`, `position` | number (integer) |

**transaction**: `iglu:io.surfside.commerce/transaction/jsonschema/1-0-0`

| Argument | JSON type |
| --- | --- |
| `id`, `affiliation`, `coupon`, `list`, `option`, `currency` | string |
| `revenue` | number (double) |
| `tax`, `shipping` | number (double) |
| `step` | number (integer) |

**action**: `iglu:io.surfside.commerce/action/jsonschema/1-0-0`: a single `action` string.

## Commerce action values

`action` is a free-form `String`. The standard flow is five moments: `detail`, `add`, `remove`,
`checkout`, and `purchase`. `detail`, `add`, and `remove` carry a single product entity; `checkout`
and `purchase` carry the whole cart plus a transaction. The canonical set your reporting keys off is
defined by the Surfside platform, not by this SDK. Confirm the values for your account with your
Surfside contact before shipping.

---

## Recipes

The five standard moments. `detail`, `add`, and `remove` send one product entity and the action;
`checkout` and `purchase` send the whole cart plus a transaction.

### Product detail view

```swift
surfside.addProduct(
    id: product.sku,
    name: product.name,
    brand: product.brand,
    category: product.category,
    variant: product.variant,
    price: NSNumber(value: product.price),
    currency: "USD"
)
surfside.setCommerceAction(action: "detail")
```

### Add to cart

Send the quantity added, not the resulting cart total.

```swift
surfside.addProduct(
    id: product.sku,
    name: product.name,
    brand: product.brand,
    category: product.category,
    price: NSNumber(value: product.price),
    quantity: NSNumber(value: quantityAdded),
    currency: "USD"
)
surfside.setCommerceAction(action: "add")
```

### Remove from cart

The mirror of add: send the quantity removed.

```swift
surfside.addProduct(
    id: product.sku,
    name: product.name,
    price: NSNumber(value: product.price),
    quantity: NSNumber(value: quantityRemoved),
    currency: "USD"
)
surfside.setCommerceAction(action: "remove")
```

### Checkout

```swift
surfside.addTransaction(
    id: cart.id,
    revenue: NSNumber(value: cart.subtotal),
    list: "checkout",
    step: NSNumber(value: 2),
    option: "Standard Shipping",
    currency: "USD"
)
for line in cart.lines {
    surfside.addProduct(
        id: line.sku,
        name: line.name,
        price: NSNumber(value: line.unitPrice),
        quantity: NSNumber(value: line.quantity),
        currency: "USD"
    )
}
surfside.setCommerceAction(action: "checkout")   // confirm this value for your account
```

### Purchase

The one that matters for transaction-linked measurement. Send the transaction **and** every line
item, then one action.

```swift
surfside.addTransaction(
    id: order.id,                                   // your order identifier: must be stable
    affiliation: "iOS App",
    revenue: NSNumber(value: order.grandTotal),     // grand total, including tax and shipping
    tax: NSNumber(value: order.tax),
    shipping: NSNumber(value: order.shipping),
    coupon: order.couponCode,
    currency: order.currency
)

for line in order.lines {
    surfside.addProduct(
        id: line.sku,
        name: line.name,
        brand: line.brand,
        category: line.category,
        variant: line.variant,
        price: NSNumber(value: line.unitPrice),      // unit price, not extended
        quantity: NSNumber(value: line.quantity),
        coupon: line.couponCode,
        currency: order.currency
    )
}

surfside.setCommerceAction(action: "purchase")
```

Fire this **once**, on confirmed order success. A retry loop that re-fires on a failed network
attempt double-counts revenue; the SDK's emitter already retries delivery on your behalf.

### Abandoning a staged moment

If you staged entities and the moment did not happen, discard them so they do not attach to the next
action:

```swift
SurfsideController.shared.clearCommerceContexts(for: "myApp")
```

---

## Verifying the payload

Run a local collector and read the decoded events:

```bash
docker run --rm -p 9090:9090 snowplow/snowplow-micro:latest
# good: http://localhost:9090/micro/good   bad: http://localhost:9090/micro/bad
```

Point a debug build at `http://localhost:9090` with the manual `createTracker` overload, then confirm
for each commerce action that the event schema is `io.surfside.commerce/action`, the entity list holds
the products/transaction you expect, and source, segment, and location ride along.
