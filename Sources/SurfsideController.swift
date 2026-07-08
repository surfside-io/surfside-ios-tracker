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

/// SurfsideController manages trackers and contexts for the Surfside plugin.
/// It provides a centralized way to manage trackers and their associated contexts.
///
/// There are two types of contexts managed by SurfsideController:
/// - Global contexts: Persistent contexts that are automatically attached to all events (e.g., source, segment, location)
/// - Commerce contexts: Temporary contexts that are cleared after being used in a commerce action event (e.g., products)
@objc(SPSurfsideController)
public class SurfsideController: NSObject {
    /// Shared instance of the SurfsideController
    @objc public static let shared = SurfsideController()
    
    /// Dictionary of trackers by namespace
    internal var trackers: [String: TrackerController] = [:]
    
    /// Dictionary of commerce contexts by tracker namespace (used for commerce events, cleared after use)
    internal var commerceContexts: [String: [SelfDescribingJson]] = [:]

    /// Dictionary of segment data keyed by tracker namespace
    @objc public var currentSegment: [String: [String: Any]] = [:]
    
    /// Dictionary of location data keyed by tracker namespace
    @objc public var currentLocation: [String: [String: Any]] = [:]
    
    /// Dictionary of user data keyed by tracker namespace
    @objc public var currentUser: [String: [String: Any]] = [:]
    
    /// Dictionary of source data keyed by tracker namespace
    @objc public var currentSource: [String: [String: Any]] = [:]
    
    /// Private initializer to enforce singleton pattern
    private override init() {
        super.init()
    }
    
    /// Register a tracker with the SurfsideController
    /// - Parameter tracker: The tracker to register
    @objc public func registerTracker(_ tracker: TrackerController) {
        trackers[tracker.namespace] = tracker
        commerceContexts[tracker.namespace] = []
    }
    
    /// Get a tracker by namespace
    /// - Parameter namespace: The namespace of the tracker
    /// - Returns: The tracker with the specified namespace, or nil if not found
    @objc public func getTracker(namespace: String) -> TrackerController? {
        return trackers[namespace]
    }
    
    /// Get all registered tracker namespaces
    /// - Returns: An array of tracker namespaces
    @objc public func getTrackerNamespaces() -> [String] {
        return Array(trackers.keys)
    }
    
    /// Add a commerce context to a tracker (used for commerce events, cleared after use)
    /// - Parameters:
    ///   - entity: The context entity to add
    ///   - trackerNamespace: The namespace of the tracker to add the context to
    @objc public func addCommerceContext(entity: SelfDescribingJson, trackerNamespace: String) {
        if var trackerContexts = commerceContexts[trackerNamespace] {
            trackerContexts.append(entity)
            commerceContexts[trackerNamespace] = trackerContexts
        } else {
            commerceContexts[trackerNamespace] = [entity]
        }
    }
    
    /// For backward compatibility
    @objc public func addContext(entity: SelfDescribingJson, trackerNamespace: String) {
        addCommerceContext(entity: entity, trackerNamespace: trackerNamespace)
    }
    
    /// Clear all commerce contexts for a tracker (used for commerce events)
    /// - Parameter trackerNamespace: The namespace of the tracker to clear contexts for
    @objc public func clearCommerceContexts(for trackerNamespace: String) {
        commerceContexts[trackerNamespace] = []
    }
    
    /// For backward compatibility
    @objc public func clearContexts(for trackerNamespace: String) {
        clearCommerceContexts(for: trackerNamespace)
    }
    
    /// Flush events for a tracker
    /// - Parameter trackerNamespace: The namespace of the tracker to flush events for
    @objc public func flushEvents(for trackerNamespace: String) {
        guard let tracker = trackers[trackerNamespace] else { return }
        tracker.emitter?.flush()
    }
    
    /// Track an event with contexts for specified trackers
    /// - Parameters:
    ///   - event: The self-describing event to track
    ///   - contexts: Additional contexts to add to the event
    ///   - trackerNamespaces: The tracker namespaces to track with (defaults to all registered trackers)
    ///   - clearCommerceContexts: Whether to clear commerce contexts after tracking (default: false)
    @objc public func trackEventWithContexts(
        _ event: SelfDescribing,
        contexts: [SelfDescribingJson]?,
        trackerNamespaces: [String]?,
        clearCommerceContexts: Bool = false
    ) {
        let namespaces = trackerNamespaces ?? getTrackerNamespaces()
        
        for namespace in namespaces {
            guard let tracker = trackers[namespace] else { continue }
            
            // Get stored commerce contexts for this tracker
            var allContexts = self.commerceContexts[namespace] ?? []
            
            // NOTE: Global contexts (source/segment/location/user/surfId) are attached automatically
            // by Snowplow's native tracker.globalContexts system. Do NOT add them here to avoid duplication.
            
            // Add additional contexts if provided
            if let additionalContexts = contexts {
                allContexts.append(contentsOf: additionalContexts)
            }
            
            // Add contexts to the event
            _ = event.entities(allContexts)
            
            // No timestamp handling needed
            
            // Track the event
            print("📡 Tracking event with schema: \(event.schema) for namespace: \(namespace)")
            print("📦 Event contexts count: \(allContexts.count)")
            let trackResult = tracker.track(event)
            print("✅ Event tracked, result: \(trackResult)")
            
            // Force flush to ensure immediate emission
            print("🚀 Forcing emitter flush for namespace: \(namespace)")
            tracker.emitter?.flush()
            print("📤 Emitter flush completed for namespace: \(namespace)")
            
            // Clear commerce contexts if requested
            if clearCommerceContexts {
                self.clearCommerceContexts(for: namespace)
                print("🧹 Commerce contexts cleared for namespace: \(namespace)")
            }
        }
    }
    
    /// Track an event with specified trackers
    /// - Parameters:
    ///   - event: The event to track
    ///   - trackerNamespaces: The namespaces of the trackers to use (defaults to all registered trackers)
    @objc public func trackEvent(_ event: SelfDescribing, trackerNamespaces: [String]? = nil) {
        let namespaces = trackerNamespaces ?? getTrackerNamespaces()
        print("🎯 trackEvent called with schema: \(event.schema), namespaces: \(namespaces)")
        for namespace in namespaces {
            if let tracker = trackers[namespace] {
                print("📡 Tracking event for namespace: \(namespace)")
                let result = tracker.track(event)
                print("✅ Event tracked, result: \(result)")
                
                // Force flush to ensure immediate emission
                print("🚀 Forcing emitter flush for namespace: \(namespace)")
                tracker.emitter?.flush()
                print("📤 Emitter flush completed for namespace: \(namespace)")
            } else {
                print("⚠️ No tracker found for namespace: \(namespace)")
            }
        }
    }
    
    // This method is intentionally removed as it's a duplicate of the one above
    
    /// Flush events for specified trackers
    /// - Parameter trackerNamespaces: The namespaces of the trackers to flush (defaults to all registered trackers)
    @objc public func flushEvents(trackerNamespaces: [String]? = nil) {
        let namespaces = trackerNamespaces ?? getTrackerNamespaces()
        for namespace in namespaces {
            trackers[namespace]?.emitter?.flush()
        }
    }
}