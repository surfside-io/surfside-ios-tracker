/*
 * Copyright (c) 2022-2025 Surfside Solutions Inc, Snowplow Analytics Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

// Import SurfsideTracker module for base tracker functionality

/// SurfsideEvent is a plugin for the Snowplow iOS tracker that adds Surfside-specific functionality.
/// It provides methods for tracking commerce events and adding commerce contexts.
///
/// SurfsideEvent supports two types of contexts:
/// - Global contexts: Persistent contexts that are automatically attached to all events (e.g., source, segment, location)
/// - Commerce contexts: Temporary contexts that are cleared after being used in a commerce action event (e.g., products)
///
/// Methods like `source()`, `segment()`, and `setLocation()` add global contexts that persist across all events.
/// Methods like `addProduct()` add commerce contexts that are cleared after a `setCommerceAction()` call.
/// This class implements all methods from the JavaScript SDK plugin in Swift.
@objc(SPSurfsideEvent)
public class SurfsideEvent: NSObject, PluginIdentifiable, ConfigurationProtocol {
    public static let identifierStatic = "Surfside"
    public var identifier: String { SurfsideEvent.identifierStatic }

    /// This plugin requires the tracker to be registered with SurfsideController
    /// - Parameter tracker: The tracker to register
    public func registerTracker(_ tracker: TrackerController) {
        SurfsideController.shared.registerTracker(tracker)
    }

    // MARK: - Commerce Events
    
    /// Track a Commerce Action Event with all stored commerce contexts
    /// - Parameters:
    ///   - action: The commerce action
    ///   - trackerNamespaces: The tracker namespaces to track with (defaults to all registered trackers)
    @objc
    public func setCommerceAction(
        action: String?,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        if namespaces.isEmpty { return }
        
        for namespace in namespaces {
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // Create commerce action entity with explicit type and fully qualified name
            let entity = CommerceActionEntity(action: action)
            
            // Create self-describing event using the entity's schema
            let event = SelfDescribing(schema: CommerceActionEntity.schema, payload: entity.data)
            
            // Track the event - trackEventWithContexts will automatically add:
            // 1. Commerce contexts (from SurfsideController.shared.commerceContexts)
            // 2. Global contexts (via Snowplow's native tracker.globalContexts system)
            SurfsideController.shared.trackEventWithContexts(
                event,
                contexts: nil,
                trackerNamespaces: [namespace],
                clearCommerceContexts: true
            )
            
            // Force flush events to ensure they're sent immediately
            tracker.emitter?.flush()
            print("Commerce action tracked for namespace: \(namespace)")
        }
    }
    
    /// Add a Commerce Transaction Context to an Action
    /// - Parameters:
    ///   - id: The transaction id
    ///   - affiliation: The store of affiliation from which this transaction occurred
    ///   - revenue: The total revenue of the transaction
    ///   - tax: The total tax of the transaction
    ///   - shipping: The shipping cost of the transaction
    ///   - coupon: The coupon code used for the transaction
    ///   - list: The list the transaction belongs to
    ///   - step: The step in the checkout process
    ///   - option: The option for the checkout step
    ///   - currency: The currency used for the transaction
    ///   - trackerNamespaces: The tracker namespaces to add the context to (defaults to all registered trackers)
    @objc
    public func addTransaction(
        id: String? = nil,
        affiliation: String? = nil,
        revenue: NSNumber? = nil,
        tax: NSNumber? = nil,
        shipping: NSNumber? = nil,
        coupon: String? = nil,
        list: String? = nil,
        step: NSNumber? = nil,
        option: String? = nil,
        currency: String? = nil,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()

        // Create transaction entity as context
        let transactionEntity = CommerceTransactionEntity(
            id: id,
            affiliation: affiliation,
            revenue: revenue?.stringValue,
            tax: tax,
            shipping: shipping,
            coupon: coupon,
            list: list,
            step: step,
            option: option,
            currency: currency
        )

        // Add transaction context to each tracker namespace (commerce context, cleared after use)
        for namespace in namespaces {
            SurfsideController.shared.addCommerceContext(entity: transactionEntity, trackerNamespace: namespace)
        }
    }
    
    /// Add a Commerce Impression Context to an Action
    /// - Parameters:
    ///   - id: The impression id
    ///   - name: The name of the impression
    ///   - list: The list the impression belongs to
    ///   - brand: The brand associated with the impression
    ///   - category: The category the impression belongs to
    ///   - variant: The variant of the impression
    ///   - position: The position of the impression in a list or collection
    ///   - price: The price associated with the impression
    ///   - currency: The currency used for the impression price
    ///   - trackerNamespaces: The tracker namespaces to add the context to (defaults to all registered trackers)
    @objc
    public func addImpression(
        id: String? = nil,
        name: String? = nil,
        list: String? = nil,
        brand: String? = nil,
        category: String? = nil,
        variant: String? = nil,
        position: NSNumber? = nil,
        price: NSNumber? = nil,
        currency: String? = nil,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()

        // Create impression entity as context
        let impressionEntity = CommerceImpressionEntity(
            id: id,
            name: name,
            list: list,
            brand: brand,
            category: category,
            variant: variant,
            position: position,
            price: price?.stringValue,
            currency: currency
        )

        // Add impression context to each tracker namespace (commerce context, cleared after use)
        for namespace in namespaces {
            SurfsideController.shared.addCommerceContext(entity: impressionEntity, trackerNamespace: namespace)
        }
    }
    
    /// Add a Commerce Product Context to an Action
    /// - Parameters:
    ///   - id: The product id
    ///   - name: The name of the product
    ///   - list: The list the product belongs to
    ///   - brand: The brand of the product
    ///   - category: The category the product belongs to
    ///   - variant: The variant of the product
    ///   - price: The price of the product
    ///   - quantity: The quantity of the product
    ///   - coupon: The coupon associated with the product
    ///   - position: The position of the product in a list or collection
    ///   - currency: The currency used for the product price
    ///   - trackerNamespaces: The tracker namespaces to add the context to (defaults to all registered trackers)
    @objc
    public func addProduct(
        id: String? = nil,
        name: String? = nil,
        list: String? = nil,
        brand: String? = nil,
        category: String? = nil,
        variant: String? = nil,
        price: NSNumber? = nil,
        quantity: NSNumber? = nil,
        coupon: String? = nil,
        position: NSNumber? = nil,
        currency: String? = nil,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        // Create product entity as context
        let productEntity = CommerceProductEntity(
            id: id,
            name: name,
            list: list,
            brand: brand,
            category: category,
            variant: variant,
            price: price,
            quantity: quantity,
            coupon: coupon,
            position: position,
            currency: currency
        )
        
        // Add product context to each tracker namespace (commerce context, cleared after use)
        for namespace in namespaces {
            SurfsideController.shared.addCommerceContext(entity: productEntity, trackerNamespace: namespace)
        }
    }
    
    /// Add a Commerce Promotion Context to an Action
    /// - Parameters:
    ///   - id: The promotion id
    ///   - name: The name of the promotion
    ///   - creative: The creative content of the promotion
    ///   - position: The position of the promotion
    ///   - currency: The currency used for the promotion
    ///   - trackerNamespaces: The tracker namespaces to add the context to (defaults to all registered trackers)
    @objc
    public func addPromotion(
        id: String? = nil,
        name: String? = nil,
        creative: String? = nil,
        position: String? = nil,
        currency: String? = nil,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        let context = CommercePromotionEntity(
            id: id,
            name: name,
            creative: creative,
            position: position,
            currency: currency
        )
        
        // Entity is already a SelfDescribingJson
        let promotionContext = context
        
        for namespace in namespaces {
            // Add the promotion context to the tracker's contexts
            SurfsideController.shared.addCommerceContext(entity: promotionContext, trackerNamespace: namespace)
        }
    }
    
    // MARK: - Context Methods

    /// Replace a persistent global context on a tracker: remove any existing context with the tag, then add the new one.
    /// Snowplow's `add(tag:)` returns false if the tag already exists, so the remove-first is required for re-set semantics.
    private func setGlobalContext(_ entity: SelfDescribingJson, tag: String, label: String, on tracker: TrackerController, namespace: String) {
        let globalContext = GlobalContext(staticContexts: [entity])
        _ = tracker.globalContexts?.remove(tag: tag)
        let success = tracker.globalContexts?.add(tag: tag, contextGenerator: globalContext) ?? false

        if success {
            print("✅ \(label) context added to Snowplow globalContexts for namespace: \(namespace)")
        } else {
            print("❌ Failed to add \(label) context to globalContexts for namespace: \(namespace)")
        }
    }

    /// Sets a Surfside Source Context using Snowplow's built-in global context system
    /// - Parameters:
    ///   - accountId: The account ID
    ///   - sourceId: The source ID
    ///   - trackerNamespaces: The tracker namespaces to add the context to (defaults to all registered trackers)
    @objc
    public func source(
        accountId: String? = nil,
        sourceId: String? = nil,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        // Create source entity
        let entity = SourceEntity(accountId: accountId, sourceId: sourceId)
        
        for namespace in namespaces {
            // Get tracker for this namespace
            guard let tracker = SurfsideController.shared.trackers[namespace] else { 
                print("❌ No tracker found for namespace: \(namespace)")
                continue 
            }
            
            print("📡 Adding source context to Snowplow globalContexts for namespace: \(namespace)")
            print("📡 AccountId: \(String(describing: accountId)), SourceId: \(String(describing: sourceId))")
            
            // Store source data in controller for reference
            SurfsideController.shared.currentSource[namespace] = [
                "accountId": accountId as Any,
                "sourceId": sourceId as Any
            ]
            
            setGlobalContext(entity, tag: "surfside-source", label: "Source", on: tracker, namespace: namespace)
        }
    }
    
    /// Sets a Surfside Segment Context using Snowplow's built-in global context system
    /// - Parameters:
    ///   - segmentId: The segment ID
    ///   - trackerNamespaces: The tracker namespaces to add the segment to (defaults to all registered trackers)
    @objc
    public func segment(
        segmentId: String,
        segmentVal: String,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        for namespace in namespaces {
            // Get tracker for this namespace
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            print("📡 Adding segment context to Snowplow globalContexts for namespace: \(namespace)")
            print("📡 SegmentId: \(segmentId), SegmentVal: \(segmentVal)")
            
            // Store segment data in controller for reference
            SurfsideController.shared.currentSegment[namespace] = [
                "segmentId": segmentId,
                "segmentVal": segmentVal
            ]
            
            // Create segment entity with both segmentId and segmentVal
            let entity = SegmentEntity(segmentId: segmentId, segmentVal: segmentVal)
            
            setGlobalContext(entity, tag: "surfside-segment", label: "Segment", on: tracker, namespace: namespace)
        }
    }
    
    /// Remove a segment context from the tracker using Snowplow's built-in global context system
    /// - Parameters:
    ///   - segmentId: The segment ID to remove (if nil, removes all segments)
    ///   - trackerNamespaces: The tracker namespaces to remove the segment from (defaults to all registered trackers)
    @objc
    public func removeSegment(
        segmentId: String? = nil,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        for namespace in namespaces {
            // Get tracker for this namespace
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // If segmentId is provided, only remove if it matches the current one
            if let segmentId = segmentId,
               let currentSegment = SurfsideController.shared.currentSegment[namespace],
               let currentSegmentId = currentSegment["segmentId"] as? String,
               currentSegmentId != segmentId {
                continue
            }
            
            print("📡 Removing segment context from Snowplow globalContexts for namespace: \(namespace)")
            
            // Remove segment data from controller
            SurfsideController.shared.currentSegment.removeValue(forKey: namespace)
            
            // Remove the segment context from Snowplow's global context system
            let removedContext = tracker.globalContexts?.remove(tag: "surfside-segment")
            
            if removedContext != nil {
                print("✅ Segment context removed from Snowplow globalContexts for namespace: \(namespace)")
            } else {
                print("⚠️ No segment context found to remove for namespace: \(namespace)")
            }
        }
    }
    
    /// Set a location context for the tracker using Snowplow's built-in global context system
    /// - Parameters:
    ///   - id: The unique identifier for the location
    ///   - latitude: The latitude coordinate
    ///   - longitude: The longitude coordinate
    ///   - country_code: The ISO country code (e.g., "US", "CA")
    ///   - zip: The postal/zip code
    ///   - state_label: The full state name (e.g., "California")
    ///   - state: The state abbreviation (e.g., "CA")
    ///   - city: The city name
    ///   - street: The street address
    ///   - name: The location name or business name
    ///   - parent: The parent location identifier
    ///   - type: The type of location (e.g., "store", "warehouse")
    ///   - category: The category of location (e.g., "retail", "office")
    ///   - trackerNamespaces: The tracker namespaces to set the location for (defaults to all registered trackers)
    @objc
    public func setLocation(
        id: String? = nil,
        latitude: String? = nil,
        longitude: String? = nil,
        country_code: String? = nil,
        zip: String? = nil,
        state_label: String? = nil,
        state: String? = nil,
        city: String? = nil,
        street: String? = nil,
        name: String? = nil,
        parent: String? = nil,
        type: String? = nil,
        category: String? = nil,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        // Create location entity with the provided parameters
        let entity = LocationEntity(
            id: id,
            latitude: latitude,
            longitude: longitude,
            country_code: country_code,
            zip: zip,
            state_label: state_label,
            state: state,
            city: city,
            street: street,
            name: name,
            parent: parent,
            type: type,
            category: category
        )
        
        for namespace in namespaces {
            // Get tracker for this namespace
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            print("📡 Adding location context to Snowplow globalContexts for namespace: \(namespace)")
            if let latitude = latitude, let longitude = longitude {
                print("📡 Latitude: \(latitude), Longitude: \(longitude)")
            }
            if let city = city, let state = state {
                print("📡 City: \(city), State: \(state)")
            }
            
            // Store location data in controller for reference
            var locationData: [String: Any] = [:]
            if let id = id { locationData["id"] = id }
            if let latitude = latitude { locationData["latitude"] = latitude }
            if let longitude = longitude { locationData["longitude"] = longitude }
            if let country_code = country_code { locationData["country_code"] = country_code }
            if let zip = zip { locationData["zip"] = zip }
            if let state_label = state_label { locationData["state_label"] = state_label }
            if let state = state { locationData["state"] = state }
            if let city = city { locationData["city"] = city }
            if let street = street { locationData["street"] = street }
            if let name = name { locationData["name"] = name }
            if let parent = parent { locationData["parent"] = parent }
            if let type = type { locationData["type"] = type }
            if let category = category { locationData["category"] = category }
            
            SurfsideController.shared.currentLocation[namespace] = locationData
            
            setGlobalContext(entity, tag: "surfside-location", label: "Location", on: tracker, namespace: namespace)
        }
    }
    
    /// Remove the location context from the tracker using Snowplow's built-in global context system
    /// - Parameter trackerNamespaces: The tracker namespaces to remove the location from (defaults to all registered trackers)
    @objc
    public func removeLocation(
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        for namespace in namespaces {
            // Get tracker for this namespace
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            print("📡 Removing location context from Snowplow globalContexts for namespace: \(namespace)")
            
            // Remove location data from controller
            SurfsideController.shared.currentLocation.removeValue(forKey: namespace)
            
            // Remove the location context from Snowplow's global context system
            let removedContext = tracker.globalContexts?.remove(tag: "surfside-location")
            
            if removedContext != nil {
                print("✅ Location context removed from Snowplow globalContexts for namespace: \(namespace)")
            } else {
                print("⚠️ No location context found to remove for namespace: \(namespace)")
            }
        }
    }
    
    /// Set a user context for the tracker. `email` and `phone` are hashed on the
    /// device (see `Uid2`) so raw directly-identifying information never leaves it.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - email: The user's email (hashed to `hashed_email`, never emitted raw)
    ///   - phone: The user's phone number (hashed to `hashed_phone`, never emitted raw)
    ///   - trackerNamespaces: The tracker namespaces to set the user for (defaults to all registered trackers)
    @objc
    public func setUser(
        userId: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()

        let entity = UserEntity(
            userId: userId,
            email: email,
            phone: phone
        )

        for namespace in namespaces {
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }

            SurfsideController.shared.currentUser[namespace] = [
                "userId": userId as Any,
                "email": email as Any,
                "phone": phone as Any
            ]

            setGlobalContext(entity, tag: "surfside-user", label: "User", on: tracker, namespace: namespace)
        }
    }
    
    /// Set the resolved UID context for the tracker. The `surfId` value is the
    /// UID2 advertising token; it is emitted as the platform's `uid_context`,
    /// aligning iOS with the web SDK's identity resolution (replaces the legacy
    /// `io.surfside/surfId` context).
    /// - Parameters:
    ///   - surfId: The UID2 advertising token
    ///   - trackerNamespaces: The tracker namespaces to set the UID for (defaults to all registered trackers)
    @objc
    public func setSurfId(
        surfId: String,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()

        let entity = UidContextEntity(uid2: surfId)

        for namespace in namespaces {
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }

            SurfsideController.shared.currentUid2[namespace] = surfId

            setGlobalContext(entity, tag: "surfside-surfId", label: "UidContext", on: tracker, namespace: namespace)
        }
    }

    /// Read back the resolved identity the tracker currently holds for a
    /// namespace:
    /// - `uid2` — the UID2 advertising token set via `setSurfId`.
    /// - `userId` — the app-supplied user id set via `setUser`.
    /// - `domainUserId` — the stable per-install device id (the Snowplow session
    ///   `userId`): a UUID persisted across launches that changes only on
    ///   reinstall. This is the iOS analog of the web tracker's `domainUserId`
    ///   cookie value, and the id the web ad path keys off.
    ///
    /// Exposed so a host app can broker this identity to other Surfside SDKs
    /// without those SDKs depending on the tracker — e.g. SurfsideAdsKit seeds
    /// `domainUserId` into its ad WebView so ad requests attribute to the same
    /// tracked user (JJRC-259). Returns only the keys that are set;
    /// `domainUserId` is absent if session tracking is disabled.
    /// - Parameter trackerNamespace: the namespace to read (defaults to the first
    ///   registered tracker).
    @objc
    public func getResolvedIdentity(trackerNamespace: String? = nil) -> [String: String] {
        guard let namespace = trackerNamespace ?? SurfsideController.shared.getTrackerNamespaces().first else {
            return [:]
        }

        var identity: [String: String] = [:]
        if let uid2 = SurfsideController.shared.currentUid2[namespace] {
            identity["uid2"] = uid2
        }
        if let userId = SurfsideController.shared.currentUser[namespace]?["userId"] as? String {
            identity["userId"] = userId
        }
        if let domainUserId = SurfsideController.shared.trackers[namespace]?.session?.userId {
            identity["domainUserId"] = domainUserId
        }
        return identity
    }
    
    /// Identify a user with the tracker
    /// - Parameters:
    ///   - userId: The user ID
    ///   - email: The user's email
    ///   - trackerNamespaces: The tracker namespaces to identify the user with (defaults to all registered trackers)
    @objc
    public func identifyUser(
        userId: String? = nil,
        email: String? = nil,
        trackerNamespaces: [String]? = nil
    ) {
        // Set the user context
        setUser(userId: userId, email: email, trackerNamespaces: trackerNamespaces)
        
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        for namespace in namespaces {
            // Get tracker for this namespace
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // Create identify event data
            var eventData: [String: Any] = [:]
            
            if let userId = userId {
                eventData["userId"] = userId
            }
            
            if let email = email {
                eventData["email"] = email
            }
            
            // Create self-describing event
            let event = SelfDescribing(schema: "iglu:io.surfside/identify/jsonschema/1-0-0", payload: eventData)
            
            // Get contexts for this tracker
            let contexts = SurfsideController.shared.commerceContexts[namespace] ?? []
            
            // Add contexts to the event
            _ = event.entities(contexts)
            
            // Track the event
            _ = tracker.track(event)
            
            // Force flush events to ensure they're sent immediately
            tracker.emitter?.flush()
        }
    }
    
    // MARK: - Advertising Events
    
    /// Tracks an auction initialization event
    /// - Parameters:
    ///   - auctionId: The auction ID
    ///   - timestamp: The timestamp (defaults to current time)
    ///   - trackerNamespaces: The tracker namespaces to track with (defaults to all registered trackers)
    @objc
    public func auctionInit(
        auctionId: String,
        timestamp: NSNumber?,
        trackerNamespaces: [String]?
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        for namespace in namespaces {
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // Get contexts for this tracker
            let contexts = SurfsideController.shared.commerceContexts[namespace] ?? []
            
            // Create auction entity
            let entity = AuctionEntity(auctionId: auctionId)
            
            // Create self-describing event
            let event = SelfDescribing(schema: "iglu:io.surfside.auction/init/jsonschema/1-0-0", payload: entity.data)
            
            // Add contexts to the event
            _ = event.entities(contexts)
            
            // Track the event
            _ = tracker.track(event)
            
            // Force flush events to ensure they're sent immediately
            tracker.emitter?.flush()
        }
    }
    
    /// Tracks a bid requested event
    /// - Parameters:
    ///   - auctionId: The auction ID
    ///   - bidder: The bidder
    ///   - timestamp: The timestamp (defaults to current time)
    ///   - trackerNamespaces: The tracker namespaces to track with (defaults to all registered trackers)
    @objc
    public func bidRequested(
        auctionId: String,
        bidder: String,
        timestamp: NSNumber?,
        trackerNamespaces: [String]?
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        for namespace in namespaces {
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // Get contexts for this tracker
            let contexts = SurfsideController.shared.commerceContexts[namespace] ?? []
            
            // Create event data
            let eventData: [String: Any] = [
                "auctionId": auctionId,
                "bidder": bidder
            ]
            
            // Create self-describing event
            let event = SelfDescribing(schema: "iglu:io.surfside.auction/bid_requested/jsonschema/1-0-0", payload: eventData)
            
            // Add contexts to the event
            _ = event.entities(contexts)
            
            // Track the event
            _ = tracker.track(event)
        }
    }
    
    /// Tracks a bid response event
    /// - Parameters:
    ///   - auctionId: The auction ID
    ///   - bidder: The bidder
    ///   - cpm: The CPM (cost per mille)
    ///   - currency: The currency
    ///   - timestamp: The timestamp (defaults to current time)
    ///   - trackerNamespaces: The tracker namespaces to track with (defaults to all registered trackers)
    @objc
    public func bidResponse(
        auctionId: String,
        bidder: String,
        cpm: NSNumber,
        currency: String?,
        timestamp: NSNumber?,
        trackerNamespaces: [String]?
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        for namespace in namespaces {
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // Get contexts for this tracker
            let contexts = SurfsideController.shared.commerceContexts[namespace] ?? []
            
            // Create event data
            var eventData: [String: Any] = [
                "auctionId": auctionId,
                "bidder": bidder,
                "cpm": cpm.doubleValue
            ]
            
            if let currency = currency {
                eventData["currency"] = currency
            }
            
            // Create self-describing event
            let event = SelfDescribing(schema: "iglu:io.surfside.auction/bid_response/jsonschema/1-0-0", payload: eventData)
            
            // Add contexts to the event
            _ = event.entities(contexts)
            
            // Track the event
            _ = tracker.track(event)
        }
    }
    
    /// Tracks a bidder done event
    /// - Parameters:
    ///   - auctionId: The auction ID
    ///   - bidder: The bidder
    ///   - timestamp: The timestamp (defaults to current time)
    ///   - trackerNamespaces: The tracker namespaces to track with (defaults to all registered trackers)
    @objc
    public func bidderDone(
        auctionId: String,
        bidder: String,
        timestamp: NSNumber?,
        trackerNamespaces: [String]?
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        for namespace in namespaces {
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // Get contexts for this tracker
            let contexts = SurfsideController.shared.commerceContexts[namespace] ?? []
            
            // Create event data
            let eventData: [String: Any] = [
                "auctionId": auctionId,
                "bidder": bidder
            ]
            
            // Create self-describing event
            let event = SelfDescribing(schema: "iglu:io.surfside.auction/bidder_done/jsonschema/1-0-0", payload: eventData)
            
            // Add contexts to the event
            _ = event.entities(contexts)
            
            // Track the event
            _ = tracker.track(event)
        }
    }
    
    /// Tracks a bidder error event
    /// - Parameters:
    ///   - auctionId: The auction ID
    ///   - bidder: The bidder
    ///   - error: The error
    ///   - timestamp: The timestamp (defaults to current time)
    ///   - trackerNamespaces: The tracker namespaces to track with (defaults to all registered trackers)
    @objc
    public func bidderError(
        auctionId: String,
        bidder: String,
        error: String,
        timestamp: NSNumber?,
        trackerNamespaces: [String]?
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        for namespace in namespaces {
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // Get contexts for this tracker
            let contexts = SurfsideController.shared.commerceContexts[namespace] ?? []
            
            // Create event data
            let eventData: [String: Any] = [
                "auctionId": auctionId,
                "bidder": bidder,
                "error": error
            ]
            
            // Create self-describing event
            let event = SelfDescribing(schema: "iglu:io.surfside.auction/bidder_error/jsonschema/1-0-0", payload: eventData)
            
            // Add contexts to the event
            _ = event.entities(contexts)
            
            // Track the event
            _ = tracker.track(event)
        }
    }
    
    /// Tracks a no bid event
    /// - Parameters:
    ///   - auctionId: The auction ID
    ///   - bidder: The bidder
    ///   - timestamp: The timestamp (defaults to current time)
    ///   - trackerNamespaces: The tracker namespaces to track with (defaults to all registered trackers)
    @objc
    public func noBid(
        auctionId: String,
        bidder: String,
        timestamp: NSNumber?,
        trackerNamespaces: [String]?
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        for namespace in namespaces {
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // Get contexts for this tracker
            let contexts = SurfsideController.shared.commerceContexts[namespace] ?? []
            
            // Create event data
            let eventData: [String: Any] = [
                "auctionId": auctionId,
                "bidder": bidder
            ]
            
            // Create self-describing event
            let event = SelfDescribing(schema: "iglu:io.surfside.auction/no_bid/jsonschema/1-0-0", payload: eventData)
            
            // Add contexts to the event
            _ = event.entities(contexts)
            
            // Track the event
            _ = tracker.track(event)
        }
    }
}