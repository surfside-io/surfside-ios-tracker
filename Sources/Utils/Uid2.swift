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
import CommonCrypto

/// Normalizes and hashes email/phone per the UID2 spec so raw PII never leaves
/// the device.
///
/// Normalization must stay in lockstep with surf-id's `Uid2Hasher` (server) and
/// digital-sdk's `helpers/uid2.ts` (web), or a hash will be well-formed yet
/// never match — the resolve call silently returns nothing rather than failing.
/// `Tests/Utils/TestUid2.swift` locks this to the same spec reference vectors
/// those two implementations assert against.
///
/// CommonCrypto rather than CryptoKit: this package's deployment floor is
/// iOS 11 / macOS 10.13, below CryptoKit's iOS 13 / macOS 10.15.
enum Uid2 {
    /// Shortest national number we will assume already carries a country code.
    /// Below this a bare number is ambiguous, so it is dropped rather than
    /// guessed at.
    private static let minDigitsForCountryCode = 10

    /// Lowercases, strips all whitespace, and applies Gmail's local-part rules
    /// (drop `+suffix`, drop dots). Returns `nil` when the value cannot be read
    /// as an address — an unusable value is dropped, never hashed.
    static func normalizeEmail(_ email: String) -> String? {
        let address = email.components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .lowercased()

        guard let at = address.lastIndex(of: "@") else { return nil }
        var local = String(address[address.startIndex..<at])
        let domain = String(address[address.index(after: at)...])
        if local.isEmpty || domain.isEmpty { return nil }

        if domain == "gmail.com" {
            local = local.components(separatedBy: "+")[0].replacingOccurrences(of: ".", with: "")
            if local.isEmpty { return nil }
        }

        return "\(local)@\(domain)"
    }

    /// Strips formatting characters and validates E.164, assuming a country
    /// code is already present when the number is long enough. Returns `nil`
    /// for anything that does not end up as a valid E.164 number.
    static func normalizePhone(_ phone: String) -> String? {
        var number = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        number = number.components(separatedBy: CharacterSet(charactersIn: " \t\n()-.")).joined()

        if !number.hasPrefix("+") {
            if number.count < minDigitsForCountryCode { return nil }
            number = "+\(number)"
        }

        return isE164(number) ? number : nil
    }

    /// `^\+[1-9]\d{6,14}$` — hand-rolled rather than NSRegularExpression to keep
    /// this hot path allocation-free and the rule readable next to the spec.
    private static func isE164(_ number: String) -> Bool {
        guard number.hasPrefix("+") else { return false }
        let digits = number.dropFirst()
        guard let first = digits.first, first != "0" else { return false }
        guard digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
        return (7...15).contains(digits.count)
    }

    /// Base64 of the raw SHA-256 digest bytes — *not* of the hex string.
    static func base64Sha256(_ value: String) -> String {
        let bytes = Array(value.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(bytes, CC_LONG(bytes.count), &digest)
        return Data(digest).base64EncodedString()
    }

    /// `Base64(SHA-256(normalized email))`, or `nil` when the value is unusable.
    static func hashEmail(_ email: String?) -> String? {
        guard let email = email, let normalized = normalizeEmail(email) else { return nil }
        return base64Sha256(normalized)
    }

    /// `Base64(SHA-256(normalized phone))`, or `nil` when the value is unusable.
    static func hashPhone(_ phone: String?) -> String? {
        guard let phone = phone, let normalized = normalizePhone(phone) else { return nil }
        return base64Sha256(normalized)
    }
}
