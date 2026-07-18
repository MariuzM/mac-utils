import XCTest
@testable import MacOSUtility

final class KeyMappingMigrationTests: XCTestCase {
    func testDecodesLegacyNestedKeyFormat() throws {
        let json = """
        [{"source":{"name":"F5","usage":30064771134},
          "destination":{"name":"Brightness Down","usage":51539607664},
          "id":"34BBD1DE-0910-4A09-B89A-EE971F71BD3C"}]
        """
        let decoded = try JSONDecoder().decode([KeyMapping].self, from: Data(json.utf8))
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].source.name, "F5")
        XCTAssertEqual(decoded[0].destination.name, "Brightness Down")
    }

    func testRenamingAKeyLabelDoesNotOrphanSavedMappings() throws {
        let f5 = Keys.sources.first { $0.name == "F5" }!
        let json = """
        [{"source":{"name":"OLD NAME","usage":\(f5.usage)},
          "destination":{"name":"ALSO OLD","usage":\(Keys.destinations[0].usage)},
          "id":"34BBD1DE-0910-4A09-B89A-EE971F71BD3C"}]
        """
        let decoded = try JSONDecoder().decode([KeyMapping].self, from: Data(json.utf8))
        XCTAssertEqual(decoded[0].source.name, "F5")
        XCTAssertEqual(decoded[0].destination, Keys.destinations[0])
    }

    func testNewFormatEncodesUsageOnlyAndRoundTrips() throws {
        let original = KeyMapping(source: Keys.sources[0], destination: Keys.destinations[0])
        let data = try JSONEncoder().encode([original])
        let text = String(data: data, encoding: .utf8)!
        XCTAssertFalse(text.contains("\"name\""))

        let decoded = try JSONDecoder().decode([KeyMapping].self, from: data)
        XCTAssertEqual(decoded[0].source, original.source)
        XCTAssertEqual(decoded[0].destination, original.destination)
    }

    func testUnknownUsageIsRejectedRatherThanSilentlyMisResolved() {
        let json = #"[{"source":999999,"destination":999998,"id":"34BBD1DE-0910-4A09-B89A-EE971F71BD3C"}]"#
        XCTAssertThrowsError(try JSONDecoder().decode([KeyMapping].self, from: Data(json.utf8)))
    }
}

final class HidutilPlistTests: XCTestCase {
    func testDaemonPlistIsValidAndCarriesThePayload() throws {
        let mappings = [KeyMapping(source: Keys.sources[0], destination: Keys.destinations[0])]
        let data = try Hidutil.launchDaemonPlist(for: mappings, label: "test.label")
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]

        XCTAssertEqual(plist["Label"] as? String, "test.label")
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        let arguments = plist["ProgramArguments"] as! [String]
        XCTAssertEqual(arguments.first, "/usr/bin/hidutil")
        XCTAssertEqual(arguments.last, Hidutil.payload(for: mappings))
    }

    func testPayloadSurvivesPlistRoundTripUnmangled() throws {
        let mappings = Keys.sources.prefix(4).map {
            KeyMapping(source: $0, destination: Keys.destinations[0])
        }
        let expected = Hidutil.payload(for: mappings)
        let data = try Hidutil.launchDaemonPlist(for: mappings, label: "x")
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
        XCTAssertEqual((plist["ProgramArguments"] as! [String]).last, expected)
    }
}
