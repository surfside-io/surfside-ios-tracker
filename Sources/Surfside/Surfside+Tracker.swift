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

/// Result type for tracker creation with the Surfside plugin.
public struct SurfsideTrackerResult {
    /// The tracker controller
    public let tracker: TrackerController
    /// The Surfside plugin attached to the tracker
    public let plugin: SurfsidePlugin
}

/// Surfside commerce-tracking convenience API.
///
/// These overloads live in a Surfside-owned file (not the vendored `Snowplow.swift`)
/// so the public entry point can be `Surfside.createTracker(...)` without adding any
/// merge-conflict surface against upstream Snowplow. Each overload builds a tracker via
/// the vendored `Surfside.createTracker(namespace:network:configurations:)`, attaches a
/// `SurfsidePlugin`, and fires the initial source context. The created tracker
/// self-registers in Snowplow's own tracker registry (`Surfside.tracker(namespace:)` /
/// `Surfside.instancedTrackerNamespaces`), so the plugin can reach it by namespace
/// without any separate registration step.
extension Surfside {

    /// Creates a tracker with the Surfside plugin configured using environment-based configuration.
    ///
    /// - Parameters:
    ///   - namespace: The namespace for the tracker
    ///   - environment: The Surfside environment (development or production)
    ///   - accountId: The Surfside account ID
    ///   - sourceId: The Surfside source ID
    ///   - appId: The application ID
    /// - Returns: A result containing both the tracker and the Surfside plugin
    public class func createTracker(
        namespace: String,
        environment: SurfsideEnvironment,
        accountId: String,
        sourceId: String,
        appId: String? = nil
    ) -> SurfsideTrackerResult {
        return createTracker(
            namespace: namespace,
            endpoint: environment.endpoint,
            method: .post,
            accountId: accountId,
            sourceId: sourceId,
            appId: appId
        )
    }

    /// Creates a tracker with the Surfside plugin configured using manual endpoint/method configuration.
    ///
    /// - Parameters:
    ///   - namespace: The namespace for the tracker
    ///   - endpoint: The collector endpoint URL
    ///   - method: The HTTP method to use (GET or POST)
    ///   - accountId: The Surfside account ID
    ///   - sourceId: The Surfside source ID
    ///   - appId: The application ID
    /// - Returns: A result containing both the tracker and the Surfside plugin
    public class func createTracker(
        namespace: String,
        endpoint: String,
        method: HttpMethodOptions,
        accountId: String,
        sourceId: String,
        appId: String? = nil
    ) -> SurfsideTrackerResult {
        // Build the network + tracker configuration.
        let networkConfig = NetworkConfiguration(endpoint: endpoint, method: method)
        let trackerConfig = TrackerConfiguration()
        if let appId = appId {
            trackerConfig.appId = appId
        }

        // Create the tracker via the vendored entry point.
        let tracker = createTracker(
            namespace: namespace,
            network: networkConfig,
            configurations: [trackerConfig]
        )

        // Layer on the Surfside plugin and fire the initial source context.
        let plugin = addSurfsidePlugin(to: tracker, accountId: accountId, sourceId: sourceId)

        return SurfsideTrackerResult(tracker: tracker, plugin: plugin)
    }

    /// Adds the Surfside plugin to an existing tracker and configures it.
    ///
    /// Use this when the tracker is built elsewhere (e.g. via remote configuration)
    /// and you just need to layer Surfside commerce tracking on top.
    ///
    /// - Parameters:
    ///   - tracker: The tracker to add the plugin to
    ///   - accountId: The Surfside account ID
    ///   - sourceId: The Surfside source ID
    /// - Returns: The configured Surfside plugin
    @discardableResult
    public class func addSurfsidePlugin(
        to tracker: TrackerController,
        accountId: String,
        sourceId: String
    ) -> SurfsidePlugin {
        let plugin = SurfsidePlugin()
        tracker.plugins.add(plugin: plugin)

        plugin.source(
            accountId: accountId,
            sourceId: sourceId,
            trackerNamespaces: [tracker.namespace]
        )

        return plugin
    }
}
