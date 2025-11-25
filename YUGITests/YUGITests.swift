//
//  YUGITests.swift
//  YUGITests
//
//  Created by EVA PARMAR on 29/05/2025.
//

import Testing
@testable import YUGI

struct YUGITests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func classCategory_decodes_caseInsensitively_and_encodes_capitalized() throws {
        let jsonStrings = ["\"Baby\"", "\"baby\"", "\"BABY\""]
        for json in jsonStrings {
            let data = Data(json.utf8)
            let decoded = try JSONDecoder().decode(ClassCategory.self, from: data)
            #expect(decoded == .baby)
            let encoded = try JSONEncoder().encode(decoded)
            let encodedString = String(data: encoded, encoding: .utf8)
            #expect(encodedString == "\"Baby\"")
        }
    }
}
