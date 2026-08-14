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

import XCTest
@testable import SurfsideTracker

/// Expected hashes are reference values from the UID2 specification, copied
/// from the two implementations this one must agree with byte for byte:
/// surf-id's `Uid2HasherTest.java` (server) and digital-sdk's
/// `test/hashing.test.ts` (web). A hash that is well-formed but normalized
/// differently is accepted downstream and then silently never matches, so
/// these vectors — not the code — are the contract.
class TestUid2: XCTestCase {

    // MARK: email

    func testHashesEmailPerSpecVectors() {
        let cases: [(String, String, String)] = [
            ("lowercases", "USER@example.com", "tMmiiTI7IaAcPpQPFQ65uMVCWH8av9jw4cwf/F5HVRQ="),
            ("uppercase local part", "MYEMAIL@example.com", "FsGNM28LJQ8OLZB0Us65ZYp07NrovJSGTCMSKnLMJ6U="),
            ("keeps dots for non-gmail", "My.Email@example.com", "4itTvG+HEnTzpiqzejyu1yFPwU1nYhWpaiQvz62hyB8="),
            ("mixed case, no dots", "JaneSaoirse@example.com", "1mcOepIAfxtf94Xx/IHlOqbT170GvfXEc83HKGwoS20="),
            ("keeps dots for non-gmail (2)", "Jane.Saoirse@example.com", "sZZDLHuYmiypHIN5mVfFFdpT5sE6vyC3j+qU8RfpC/g="),
            ("keeps +suffix for non-gmail", "JaneSaoirse+Work@example.com", "KKruSBUjDNO069iMUVImVQZm6RrAGZKeOtrD9mwogYA="),
            ("strips dots for gmail", "JANE.SAOIRSE@gmail.com", "ku4mBX7Z3qJTXWyLFB1INzkyR2WZGW4ANSJUiW21iI8="),
            ("strips +suffix for gmail", "JaneSaoirse+Work@gmail.com", "ku4mBX7Z3qJTXWyLFB1INzkyR2WZGW4ANSJUiW21iI8="),
            ("trims surrounding whitespace", "  USER@example.com  ", "tMmiiTI7IaAcPpQPFQ65uMVCWH8av9jw4cwf/F5HVRQ=")
        ]

        for (description, raw, expected) in cases {
            XCTAssertEqual(Uid2.hashEmail(raw), expected, "email \(description): \(raw)")
        }
    }

    func testDropsUnusableEmailRatherThanHashingIt() {
        for raw in ["not-an-email", "@example.com", "user@", "+@gmail.com"] {
            XCTAssertNil(Uid2.hashEmail(raw), "should drop unusable email: \(raw)")
        }
    }

    // MARK: phone

    func testHashesPhonePerSpecVectors() {
        // Every reading of the same NANP number lands on the same vector.
        let cases: [(String, String, String)] = [
            ("E.164 already normalized", "+12345678901", "EObwtHBUqDNZR33LNSMdtt5cafsYFuGmuY4ZLenlue4="),
            ("strips spaces/parens/hyphens", "+1 (234) 567-8901", "EObwtHBUqDNZR33LNSMdtt5cafsYFuGmuY4ZLenlue4="),
            ("keeps a leading 1 as the country code", "1 (234) 567-8901", "EObwtHBUqDNZR33LNSMdtt5cafsYFuGmuY4ZLenlue4="),
            ("completes a bare NANP number with +1", "2345678901", "EObwtHBUqDNZR33LNSMdtt5cafsYFuGmuY4ZLenlue4="),
            ("completes a formatted bare NANP number", "(234) 567-8901", "EObwtHBUqDNZR33LNSMdtt5cafsYFuGmuY4ZLenlue4="),
            ("completes a dot-separated bare NANP number", "234.567.8901", "EObwtHBUqDNZR33LNSMdtt5cafsYFuGmuY4ZLenlue4=")
        ]

        for (description, raw, expected) in cases {
            XCTAssertEqual(Uid2.hashPhone(raw), expected, "phone \(description): \(raw)")
        }
    }

    /// The defect this guards: a bare national number used to become E.164 by
    /// prefixing only `+`, so 4155551234 hashed as +4155551234 — country code
    /// 41, Switzerland. UID2's identity map is deterministic, not a membership
    /// test, so that returns a confident advertising id for the wrong person.
    func testCompletesBareNanpWithPlusOneNotBarePlus() {
        let withCountryCode = Uid2.hashPhone("+14155551234")
        let swiss = Uid2.hashPhone("+4155551234")

        XCTAssertEqual(Uid2.hashPhone("4155551234"), withCountryCode)
        XCTAssertNotEqual(Uid2.hashPhone("4155551234"), swiss)
    }

    func testDropsPhoneItCannotReadAsE164() {
        for raw in ["555-1234", "12345", "+", "not-a-phone", "+1234567890123456"] {
            XCTAssertNil(Uid2.hashPhone(raw), "should drop unusable phone: \(raw)")
        }
    }

    /// A bare number that is not NANP-shaped carries no country code we can
    /// justify inventing, so it is dropped rather than assigned +1.
    func testDropsBareNumberThatIsNotNanpShaped() {
        let cases = [
            "0234567890",     // area code may not start with 0
            "1234567890",     // area code may not start with 1
            "2340567890",     // exchange may not start with 0
            "2341567890",     // exchange may not start with 1
            "442071234567",   // UK national number, 12 digits
            "00442071234567", // '00' is not a country code
            "20712345678"     // 11 digits that do not start with 1
        ]
        for raw in cases {
            XCTAssertNil(Uid2.hashPhone(raw), "should drop non-NANP bare number: \(raw)")
        }
    }

    // MARK: nil handling

    func testNilInputsHashToNil() {
        XCTAssertNil(Uid2.hashEmail(nil))
        XCTAssertNil(Uid2.hashPhone(nil))
    }
}
