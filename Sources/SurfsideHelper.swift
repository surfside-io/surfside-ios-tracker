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

/// Surfside environment configuration
public enum SurfsideEnvironment {
    case development
    case production
    
    /// The collector endpoint URL for this environment
    public var endpoint: String {
        switch self {
        case .development:
            return "https://c-dev.surfside.io"
        case .production:
            return "https://col.surfside.io"
        }
    }
}

/// Result type for tracker creation with Surfside plugin
public struct SurfsideTrackerResult {
    /// The tracker controller
    public let tracker: TrackerController
    /// The Surfside plugin
    public let plugin: SurfsideEvent
}

/// Helper class for setting up Snowplow with the Surfside plugin
public class SurfsideHelper {
    
    /// Creates a tracker with the Surfside plugin configured using environment-based configuration
    ///
    /// - Parameters:
    ///   - namespace: The namespace for the tracker
    ///   - environment: The Surfside environment (development or production)
    ///   - accountId: The Surfside account ID
    ///   - sourceId: The Surfside source ID
    ///   - appId: The application ID
    /// - Returns: A result containing both the tracker and the Surfside plugin
    public static func createTracker(
        namespace: String,
        environment: SurfsideEnvironment,
        accountId: String,
        sourceId: String,
        appId: String? = nil
    ) -> SurfsideTrackerResult {
        // Create network configuration with environment-specific endpoint and POST method
        let networkConfig = NetworkConfiguration(endpoint: environment.endpoint, method: .post)
        
        // Create tracker configuration
        let trackerConfig = TrackerConfiguration()
        if let appId = appId {
            trackerConfig.appId = appId
        }
        
        // Create the tracker
        let tracker = Surfside.createTracker(
            namespace: namespace,
            network: networkConfig,
            configurations: [trackerConfig]
        )
        
        // Create and configure the Surfside plugin
        let surfsideEvent = SurfsideEvent()
        tracker.plugins.add(plugin: surfsideEvent)
        
        // Register the tracker with SurfsideController
        SurfsideController.shared.registerTracker(tracker)
        
        // Set the source context
        surfsideEvent.source(
            accountId: accountId,
            sourceId: sourceId,
            trackerNamespaces: [namespace]
        )
        
        return SurfsideTrackerResult(tracker: tracker, plugin: surfsideEvent)
    }
    
    /// Creates a tracker with the Surfside plugin configured using manual endpoint/method configuration
    ///
    /// - Parameters:
    ///   - namespace: The namespace for the tracker
    ///   - endpoint: The collector endpoint URL
    ///   - method: The HTTP method to use (GET or POST)
    ///   - accountId: The Surfside account ID
    ///   - sourceId: The Surfside source ID
    ///   - appId: The application ID
    /// - Returns: A result containing both the tracker and the Surfside plugin
    public static func createTracker(
        namespace: String,
        endpoint: String,
        method: HttpMethodOptions,
        accountId: String,
        sourceId: String,
        appId: String? = nil
    ) -> SurfsideTrackerResult {
        // Create network configuration
        let networkConfig = NetworkConfiguration(endpoint: endpoint, method: method)
        
        // Create tracker configuration
        let trackerConfig = TrackerConfiguration()
        if let appId = appId {
            trackerConfig.appId = appId
        }
        
        // Create the tracker
        let tracker = Surfside.createTracker(
            namespace: namespace,
            network: networkConfig,
            configurations: [trackerConfig]
        )
        
        // Create and configure the Surfside plugin
        let surfsideEvent = SurfsideEvent()
        tracker.plugins.add(plugin: surfsideEvent)
        
        // Register the tracker with SurfsideController
        SurfsideController.shared.registerTracker(tracker)
        
        // Set the source context
        surfsideEvent.source(
            accountId: accountId,
            sourceId: sourceId,
            trackerNamespaces: [namespace]
        )
        
        return SurfsideTrackerResult(tracker: tracker, plugin: surfsideEvent)
    }
    
    /// Adds the Surfside plugin to an existing tracker and configures it
    ///
    /// - Parameters:
    ///   - tracker: The tracker to add the plugin to
    ///   - accountId: The Surfside account ID
    ///   - sourceId: The Surfside source ID
    /// - Returns: The configured Surfside plugin
    public static func addSurfsidePlugin(
        to tracker: TrackerController,
        accountId: String,
        sourceId: String
    ) -> SurfsideEvent {
        let surfsideEvent = SurfsideEvent()
        tracker.plugins.add(plugin: surfsideEvent)
        
        surfsideEvent.source(
            accountId: accountId,
            sourceId: sourceId,
            trackerNamespaces: [tracker.namespace]
        )
        
        return surfsideEvent
    }
}
