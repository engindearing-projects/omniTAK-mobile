//
//  CoTMessageParserTests.swift
//  OmniTAKMobileTests
//
//  Regression tests for CoT (Cursor on Target) message parsing.
//  Ensures message handling doesn't break with future changes.
//
//  These tests cover:
//  - Valid CoT message parsing
//  - Message validation
//  - Fragment handling
//  - Edge cases and malformed input
//

import XCTest
@testable import OmniTAKMobile

class CoTMessageParserTests: XCTestCase {

    // MARK: - Valid Message Parsing Tests

    func testParseValidPositionUpdate() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event uid="ANDROID-abc123" type="a-f-G-U-C" time="2024-01-01T12:00:00Z" start="2024-01-01T12:00:00Z" stale="2024-01-01T12:05:00Z">
            <point lat="39.8283" lon="-98.5795" hae="1000" ce="10" le="10"/>
            <detail>
                <contact callsign="TestUser"/>
                <__group name="Blue" role="Team Member"/>
            </detail>
        </event>
        """

        let result = CoTMessageParser.parse(xml: xml)
        XCTAssertNotNil(result, "Should parse valid position update")

        if case .positionUpdate(let event) = result {
            XCTAssertEqual(event.uid, "ANDROID-abc123")
            XCTAssertEqual(event.type, "a-f-G-U-C")
            XCTAssertEqual(event.point.lat, 39.8283, accuracy: 0.0001)
            XCTAssertEqual(event.point.lon, -98.5795, accuracy: 0.0001)
            XCTAssertEqual(event.detail.callsign, "TestUser")
        } else {
            XCTFail("Should be position update event")
        }
    }

    func testParseChatMessage() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event uid="GeoChat.ANDROID-123.All Chat Rooms.abc" type="b-t-f" time="2024-01-01T12:00:00Z">
            <point lat="0" lon="0" hae="0" ce="9999999" le="9999999"/>
            <detail>
                <__chat parent="RootContactGroup" chatroom="All Chat Rooms" senderCallsign="TestUser">
                    <chatgrp uid0="ANDROID-123" uid1="All Chat Rooms"/>
                </__chat>
                <remarks>Hello World</remarks>
            </detail>
        </event>
        """

        let result = CoTMessageParser.parse(xml: xml)
        XCTAssertNotNil(result, "Should parse chat message")

        if case .chatMessage(let msg) = result {
            XCTAssertEqual(msg.senderCallsign, "TestUser")
            XCTAssertEqual(msg.messageText, "Hello World")
        } else {
            XCTFail("Should be chat message event")
        }
    }

    func testParseWaypoint() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event uid="waypoint-123" type="b-m-p-w" time="2024-01-01T12:00:00Z">
            <point lat="40.7128" lon="-74.0060" hae="0" ce="10" le="10"/>
            <detail>
                <contact callsign="Rally Point Alpha"/>
                <remarks>Meet here at 0800</remarks>
            </detail>
        </event>
        """

        let result = CoTMessageParser.parse(xml: xml)
        XCTAssertNotNil(result, "Should parse waypoint")

        if case .waypoint(let event) = result {
            XCTAssertEqual(event.detail.callsign, "Rally Point Alpha")
            XCTAssertEqual(event.point.lat, 40.7128, accuracy: 0.0001)
        } else {
            XCTFail("Should be waypoint event")
        }
    }

    // MARK: - Message Validation Tests

    func testIsValidCoTMessage_ValidMessage() {
        let validXml = """
        <event uid="test" type="a-f-G">
            <point lat="0" lon="0" hae="0" ce="10" le="10"/>
        </event>
        """

        XCTAssertTrue(CoTMessageParser.isValidCoTMessage(validXml))
    }

    func testIsValidCoTMessage_MissingEventTag() {
        let invalidXml = """
        <message uid="test">
            <point lat="0" lon="0"/>
        </message>
        """

        XCTAssertFalse(CoTMessageParser.isValidCoTMessage(invalidXml))
    }

    func testIsValidCoTMessage_MissingClosingTag() {
        let invalidXml = """
        <event uid="test" type="a-f-G">
            <point lat="0" lon="0"/>
        """

        XCTAssertFalse(CoTMessageParser.isValidCoTMessage(invalidXml))
    }

    func testIsValidCoTMessage_EmptyString() {
        XCTAssertFalse(CoTMessageParser.isValidCoTMessage(""))
    }

    func testIsValidCoTMessage_WhitespaceOnly() {
        XCTAssertFalse(CoTMessageParser.isValidCoTMessage("   \n\t  "))
    }

    // MARK: - Fragment Extraction Tests

    func testExtractCompleteMessages_SingleMessage() {
        let buffer = """
        <event uid="test1" type="a-f-G"><point lat="0" lon="0"/></event>
        """

        let (messages, remaining) = CoTMessageParser.extractCompleteMessages(from: buffer)

        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testExtractCompleteMessages_MultipleMessages() {
        let buffer = """
        <event uid="test1" type="a-f-G"><point lat="0" lon="0"/></event>
        <event uid="test2" type="a-f-G"><point lat="1" lon="1"/></event>
        """

        let (messages, remaining) = CoTMessageParser.extractCompleteMessages(from: buffer)

        XCTAssertEqual(messages.count, 2)
        XCTAssertTrue(remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testExtractCompleteMessages_IncompleteMessage() {
        let buffer = """
        <event uid="test1" type="a-f-G"><point lat="0" lon="0"/></event>
        <event uid="test2" type="a-f-G"><point lat="1"
        """

        let (messages, remaining) = CoTMessageParser.extractCompleteMessages(from: buffer)

        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(remaining.contains("test2"))
    }

    func testExtractCompleteMessages_EmptyBuffer() {
        let (messages, remaining) = CoTMessageParser.extractCompleteMessages(from: "")

        XCTAssertTrue(messages.isEmpty)
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - Type Detection Tests

    func testDetectFriendlyGround() {
        let xml = """
        <event uid="test" type="a-f-G-U-C"><point lat="0" lon="0" hae="0" ce="10" le="10"/></event>
        """

        if let result = CoTMessageParser.parse(xml: xml),
           case .positionUpdate(let event) = result {
            XCTAssertTrue(event.type.hasPrefix("a-f-G"), "Should detect friendly ground unit")
        } else {
            XCTFail("Should parse as position update")
        }
    }

    func testDetectHostile() {
        let xml = """
        <event uid="test" type="a-h-G"><point lat="0" lon="0" hae="0" ce="10" le="10"/></event>
        """

        if let result = CoTMessageParser.parse(xml: xml),
           case .positionUpdate(let event) = result {
            XCTAssertTrue(event.type.hasPrefix("a-h"), "Should detect hostile unit")
        }
    }

    // MARK: - Edge Cases

    func testParseWithExtraWhitespace() {
        let xml = """

            <event uid="test" type="a-f-G">
                <point lat="0" lon="0" hae="0" ce="10" le="10"/>
            </event>

        """

        let result = CoTMessageParser.parse(xml: xml)
        XCTAssertNotNil(result)
    }

    func testParseWithXMLDeclaration() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event uid="test" type="a-f-G">
            <point lat="0" lon="0" hae="0" ce="10" le="10"/>
        </event>
        """

        let result = CoTMessageParser.parse(xml: xml)
        XCTAssertNotNil(result)
    }

    func testParseWithNestedElements() {
        let xml = """
        <event uid="test" type="a-f-G">
            <point lat="0" lon="0" hae="0" ce="10" le="10"/>
            <detail>
                <contact callsign="Nested"/>
                <__group name="Blue"/>
                <status battery="85"/>
                <takv device="iPhone" platform="iOS" version="2.7.0"/>
            </detail>
        </event>
        """

        let result = CoTMessageParser.parse(xml: xml)
        XCTAssertNotNil(result)
    }

    func testParseMalformedXML() {
        let malformedXml = "<event uid='test'><point lat=0 lon=0/></event>"

        // Should either return nil or handle gracefully
        let result = CoTMessageParser.parse(xml: malformedXml)
        // This test verifies we don't crash on malformed input
        // Result may be nil or a parsed event depending on parser tolerance
    }

    func testParseWithSpecialCharacters() {
        let xml = """
        <event uid="test&amp;123" type="a-f-G">
            <point lat="0" lon="0" hae="0" ce="10" le="10"/>
            <detail>
                <contact callsign="Test &amp; User"/>
                <remarks>Message with &lt;special&gt; chars</remarks>
            </detail>
        </event>
        """

        // Should handle XML entities
        let result = CoTMessageParser.parse(xml: xml)
        // Verify no crash
    }

    // MARK: - Performance Tests

    func testParsePerformance() {
        let xml = """
        <event uid="perf-test" type="a-f-G-U-C">
            <point lat="39.8283" lon="-98.5795" hae="1000" ce="10" le="10"/>
            <detail>
                <contact callsign="PerfTest"/>
            </detail>
        </event>
        """

        measure {
            for _ in 0..<1000 {
                _ = CoTMessageParser.parse(xml: xml)
            }
        }
    }

    func testExtractPerformance() {
        var buffer = ""
        for i in 0..<100 {
            buffer += """
            <event uid="test-\(i)" type="a-f-G"><point lat="0" lon="0" hae="0" ce="10" le="10"/></event>
            """
        }

        measure {
            _ = CoTMessageParser.extractCompleteMessages(from: buffer)
        }
    }
}

// MARK: - Unit Affiliation Tests

class UnitAffiliationTests: XCTestCase {

    func testFriendlyAffiliation() {
        let affiliation = UnitAffiliation.from(cotType: "a-f-G-U-C")
        XCTAssertEqual(affiliation, .friend)
    }

    func testHostileAffiliation() {
        let affiliation = UnitAffiliation.from(cotType: "a-h-G")
        XCTAssertEqual(affiliation, .hostile)
    }

    func testUnknownAffiliation() {
        let affiliation = UnitAffiliation.from(cotType: "a-u-G")
        XCTAssertEqual(affiliation, .unknown)
    }

    func testNeutralAffiliation() {
        let affiliation = UnitAffiliation.from(cotType: "a-n-G")
        XCTAssertEqual(affiliation, .neutral)
    }

    func testPendingAffiliation() {
        let affiliation = UnitAffiliation.from(cotType: "a-p-G")
        XCTAssertEqual(affiliation, .pending)
    }
}

// MARK: - Unit Type Tests

class UnitTypeTests: XCTestCase {

    func testGroundUnitType() {
        let unitType = UnitType.from(cotType: "a-f-G-U-C")
        XCTAssertEqual(unitType, .ground)
    }

    func testAirUnitType() {
        let unitType = UnitType.from(cotType: "a-f-A-M-F")
        XCTAssertEqual(unitType, .air)
    }

    func testSeaUnitType() {
        let unitType = UnitType.from(cotType: "a-f-S")
        XCTAssertEqual(unitType, .sea)
    }
}
