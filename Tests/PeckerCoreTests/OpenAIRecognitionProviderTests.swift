import Foundation
import Testing
@testable import PeckerCore

@Test func openAIProviderBuildsResponsesRequestWithCustomHostModelAndKey() throws {
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://proxy.example.com/base/",
            apiKey: "sk-test",
            model: "gpt-test"
        )
    )

    let request = try provider.makeRequest(
        for: .calendar(
            sourceIdentifier: "calendar-1",
            title: "G123 上海虹桥 → 北京南",
            location: "检票口 B7",
            notes: "08车 03A"
        )
    )

    #expect(request.url?.absoluteString == "https://proxy.example.com/base/v1/responses")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

    let body = try #require(request.httpBody)
    let json = try #require(
        JSONSerialization.jsonObject(with: body) as? [String: Any]
    )
    #expect(json["model"] as? String == "gpt-test")
    #expect(json["store"] as? Bool == false)
    #expect(String(data: body, encoding: .utf8)?.contains("G123 上海虹桥") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("json_schema") == true)
}

@Test func openAIProviderIncludesImageInputsAsDataURLs() throws {
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.openai.com",
            apiKey: "sk-test",
            model: "gpt-test"
        )
    )

    let request = try provider.makeRequest(
        for: .importedImage(
            id: "image-1",
            imageData: Data([0xFF, 0xD8, 0xFF]),
            filename: "ticket.jpg"
        )
    )

    let body = try #require(request.httpBody)
    let text = try #require(String(data: body, encoding: .utf8))
    #expect(text.contains("input_image"))
    #expect(text.contains("data:image/jpeg;base64,/9j/"))
}
