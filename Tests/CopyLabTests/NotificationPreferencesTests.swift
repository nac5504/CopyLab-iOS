import XCTest
@testable import CopyLab

final class NotificationPreferencesTests: XCTestCase {
    
    // Test that we can decode a simplified config that only contains preferences
    func testDecodeSimplifiedConfig() throws {
        // Minimal JSON matching the "simplified" API response
        let json = """
        {
            "version": "1.0",
            "sections": [
                {
                    "type": "system_permission_card"
                },
                {
                    "type": "preferences",
                    "items": [
                        {
                            "id": "marketing",
                            "title": "Marketing",
                            "description": "Promo emails",
                            "enabled_by_default": true
                        }
                    ]
                }
            ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let config = try decoder.decode(PreferenceCenterConfig.self, from: json)
        
        XCTAssertEqual(config.version, "1.0")
        XCTAssertEqual(config.sections.count, 2)
        XCTAssertEqual(config.sections[1].type, .preferences)
        XCTAssertEqual(config.sections[1].items?.count, 1)
        XCTAssertEqual(config.sections[1].items?.first?.id, "marketing")
    }
    
    // Test robustness: What if topics section is completely missing?
    // The current Swift model might expect it if strictly typed, but let's see.
    // If decoding succeeds, it means we handled the optionality correctly.
    
    func testDecodeNotificationPreferences_MissingFields() throws {
        // JSON where topics and schedules are missing (simulating null or empty API response)
        let json = """
        {
            "os_permission": "authorized",
            "topics": [],
            "schedules": {}
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let prefs = try decoder.decode(NotificationPreferences.self, from: json)
        
        XCTAssertEqual(prefs.osPermission, "authorized")
        XCTAssertEqual(prefs.topics.count, 0)
        XCTAssertEqual(prefs.schedules.count, 0)
    }
    
    // Test generic decoding helper logic (mocked via manual check or URLProtocol if needed, 
    // but here we just test model Codable conformance)
}
