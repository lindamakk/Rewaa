//
//  RewaaTests.swift
//  RewaaTests
//
//  Created by Linda on 17/04/2026.
//

import Testing
@testable import Rewaa

struct RewaaTests {
    @Test func routineMetadataIsAvailable() async throws {
        #expect(RoutineCategory.skin.icon == "🧴")
        #expect(RoutineCategory.hair.title == "Hair")
        #expect(RoutineFrequency.allCases.count == 4)
    }
}
