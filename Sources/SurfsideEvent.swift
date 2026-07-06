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
public class SurfsideEvent: NSObject, PluginIdentifiable, PluginEntitiesCallable, PluginNamespaceAware, ConfigurationProtocol {
    public static let identifierStatic = "Surfside"
    public var identifier: String { SurfsideEvent.identifierStatic }
    
    /// The tracker namespace this plugin instance is associated with
    private var trackerNamespace: String?
    
    /// Configuration for automatically adding global contexts to all events
    /// This property is accessed each time an event is tracked, ensuring dynamic context attachment
    public var entitiesConfiguration: PluginEntitiesConfiguration? {
        // Create the configuration once but ensure the closure always accesses current context state
        if _entitiesConfiguration == nil {
            _entitiesConfiguration = PluginEntitiesConfiguration { [weak self] event in
                guard let self = self else {
                    print("❌ SurfsideEvent plugin deallocated")
                    return []
                }
                
                print("🔍 SurfsideEvent.entitiesConfiguration called for event: \(type(of: event))")
                print("🔍 Event schema: \(event.schema ?? "unknown")")
                print("🔍 Plugin namespace: \(String(describing: self.trackerNamespace))")
                print("🔍 Plugin identifier: \(self.identifier)")
                
                // Only attach global contexts for this specific tracker namespace
                guard let namespace = self.trackerNamespace else {
                    print("❌ No tracker namespace set for SurfsideEvent plugin")
                    return []
                }
                
                // Always access the current state of global contexts
                let availableNamespaces = Array(SurfsideController.shared.globalContexts.keys)
                print("🔍 Available namespaces in globalContexts: \(availableNamespaces)")
                
                let globalContexts = SurfsideController.shared.globalContexts[namespace] ?? []
                print("🔍 Found \(globalContexts.count) global contexts for namespace: \(namespace)")
                
                if globalContexts.isEmpty {
                    print("⚠️ No global contexts found for namespace: \(namespace)")
                    print("🔍 globalContexts dictionary: \(SurfsideController.shared.globalContexts)")
                } else {
                    print("✅ Attaching \(globalContexts.count) global contexts for namespace: \(namespace)")
                    for (index, context) in globalContexts.enumerated() {
                        print("   Context \(index): \(context.schema)")
                    }
                }
                
                return globalContexts
            }
        }
        return _entitiesConfiguration
    }
    
    /// Private storage for the entities configuration to ensure it's created only once
    private var _entitiesConfiguration: PluginEntitiesConfiguration?
    /// Initialize the Surfside plugin
    /// - Parameter trackerNamespace: The namespace of the tracker this plugin will be associated with
    @objc public init(trackerNamespace: String? = nil) {
        print("🔧 SurfsideEvent plugin initializing with trackerNamespace: \(String(describing: trackerNamespace))")
        self.trackerNamespace = trackerNamespace
        super.init()
        print("✅ SurfsideEvent plugin initialized with identifier: \(self.identifier)")
    }
    
    /// Set the tracker namespace for this plugin instance
    @objc
    public func setTrackerNamespace(_ namespace: String) {
        self.trackerNamespace = namespace
    }
    
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
            // 2. Global contexts (via SurfsideEvent plugin's entitiesConfiguration)
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
        
        // Create data dictionary manually to avoid ambiguity
        var data: [String: Any] = [:]
        
        if let id = id { data["id"] = id }
        if let affiliation = affiliation { data["affiliation"] = affiliation }
        if let revenueStr = revenue?.stringValue { data["revenue"] = revenueStr }
        if let taxStr = tax?.stringValue { data["tax"] = taxStr }
        if let shippingStr = shipping?.stringValue { data["shipping"] = shippingStr }
        if let coupon = coupon { data["coupon"] = coupon }
        if let list = list { data["list"] = list }
        if let stepStr = step?.stringValue { data["step"] = stepStr }
        if let option = option { data["option"] = option }
        if let currency = currency { data["currency"] = currency }
        
        // Create context with explicit schema and data
        let context = SelfDescribingJson(schema: CommerceTransactionEntity.schema, andData: data)
        
        for namespace in namespaces {
            // Get tracker for this namespace
            if let tracker = SurfsideController.shared.trackers[namespace] {
                // Create a self-describing event
                let event = SelfDescribing(
                    schema: "iglu:io.surfside/commerce_transaction/jsonschema/1-0-0",
                    payload: context.data
                )
                
                // Get contexts for this tracker
                let contexts = SurfsideController.shared.commerceContexts[namespace] ?? []
                
                // Add contexts to the event
                _ = event.entities(contexts)
                
                // Track the event directly with the tracker
                _ = tracker.track(event)
                
                // Force flush events to ensure they're sent immediately
                tracker.emitter?.flush()
            }
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
        
        let context = CommerceImpressionEntity(
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
        
        for namespace in namespaces {
            // Get tracker for this namespace
            if let tracker = SurfsideController.shared.trackers[namespace] {
                // Create a self-describing event
                let event = SelfDescribing(
                    schema: "iglu:io.surfside/commerce_impression/jsonschema/1-0-0",
                    payload: context.data
                )
                
                // Get contexts for this tracker
                let contexts = SurfsideController.shared.commerceContexts[namespace] ?? []
                
                // Add contexts to the event
                _ = event.entities(contexts)
                
                // Track the event directly with the tracker
                _ = tracker.track(event)
                
                // Force flush events to ensure they're sent immediately
                tracker.emitter?.flush()
            }
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
            
            // Create a GlobalContext with the source entity and add it to Snowplow's global context system
            let globalContext = GlobalContext(staticContexts: [entity])
            
            // Remove any existing source context first, then add the new one
            _ = tracker.globalContexts?.remove(tag: "surfside-source")
            let success = tracker.globalContexts?.add(tag: "surfside-source", contextGenerator: globalContext) ?? false
            
            if success {
                print("✅ Source context added to Snowplow globalContexts for namespace: \(namespace)")
            } else {
                print("❌ Failed to add source context to globalContexts for namespace: \(namespace)")
            }
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
            
            // Create a GlobalContext with the segment entity and add it to Snowplow's global context system
            let globalContext = GlobalContext(staticContexts: [entity])
            
            // Remove any existing segment context first, then add the new one
            _ = tracker.globalContexts?.remove(tag: "surfside-segment")
            let success = tracker.globalContexts?.add(tag: "surfside-segment", contextGenerator: globalContext) ?? false
            
            if success {
                print("✅ Segment context added to Snowplow globalContexts for namespace: \(namespace)")
            } else {
                print("❌ Failed to add segment context to globalContexts for namespace: \(namespace)")
            }
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
            
            // Create a GlobalContext with the location entity and add it to Snowplow's global context system
            let globalContext = GlobalContext(staticContexts: [entity])
            
            // Remove any existing location context first, then add the new one
            _ = tracker.globalContexts?.remove(tag: "surfside-location")
            let success = tracker.globalContexts?.add(tag: "surfside-location", contextGenerator: globalContext) ?? false
            
            if success {
                print("✅ Location context added to Snowplow globalContexts for namespace: \(namespace)")
            } else {
                print("❌ Failed to add location context to globalContexts for namespace: \(namespace)")
            }
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
    
    /// Set a user context for the tracker
    /// - Parameters:
    ///   - userId: The user ID
    ///   - email: The user's email
    ///   - trackerNamespaces: The tracker namespaces to set the user for (defaults to all registered trackers)
    @objc
    public func setUser(
        userId: String? = nil,
        email: String? = nil,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        // Create user entity
        let entity = UserEntity(
            userId: userId,
            email: email
        )
        
        // Entity is already a SelfDescribingJson
        let userContext = entity
        
        for namespace in namespaces {
            // Get tracker for this namespace
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // Store user data in controller
            SurfsideController.shared.currentUser[namespace] = [
                "userId": userId as Any,
                "email": email as Any
            ]
            
            // Add the user context to the tracker's global contexts (persistent)
            SurfsideController.shared.addGlobalContext(entity: userContext, trackerNamespace: namespace, identifier: "user")
        }
    }
    
    /// Set a SurfId context for the tracker
    /// - Parameters:
    ///   - surfId: The SurfId
    ///   - trackerNamespaces: The tracker namespaces to set the SurfId for (defaults to all registered trackers)
    @objc
    public func setSurfId(
        surfId: String,
        trackerNamespaces: [String]? = nil
    ) {
        let namespaces = trackerNamespaces ?? SurfsideController.shared.getTrackerNamespaces()
        
        // Create SurfId entity
        let entity = SurfIdEntity(surfId: surfId)
        
        // Entity is already a SelfDescribingJson
        let surfIdContext = entity
        
        for namespace in namespaces {
            // Get tracker for this namespace
            guard let tracker = SurfsideController.shared.trackers[namespace] else { continue }
            
            // Add the surfId context to the tracker's global contexts (persistent)
            SurfsideController.shared.addGlobalContext(entity: surfIdContext, trackerNamespace: namespace, identifier: "surfId")
        }
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