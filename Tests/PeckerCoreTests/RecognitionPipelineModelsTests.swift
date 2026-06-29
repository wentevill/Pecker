import Foundation
import Testing
@testable import PeckerCore

@Test func trainSchemaRequiresOnlyMinimumUsableFields() {
    let schema = RecognitionKindSchema.schema(for: .train)
    let fields = [
        "trainNumber": "G123",
        "departureStation": "上海虹桥站",
        "arrivalStation": "北京南站",
        "startDateTime": "2026-07-03T08:00:00+08:00"
    ]

    #expect(schema.missingFields(in: fields).isEmpty)
}

@Test func everyKindSchemaAcceptsItsMinimumFields() {
    let fixtures: [(TimelineKind, [String: String])] = [
        (.meeting, ["title": "设计评审", "startDateTime": "2026-07-03T10:00:00+08:00"]),
        (.task, ["title": "提交材料", "eventDate": "2026-07-03"]),
        (.flight, [
            "flightNumber": "MU5101",
            "departureAirportCode": "SHA",
            "arrivalAirportCode": "PEK",
            "startDateTime": "2026-07-03T09:00:00+08:00"
        ]),
        (.train, [
            "trainNumber": "G123",
            "departureStation": "上海虹桥站",
            "arrivalStation": "北京南站",
            "startDateTime": "2026-07-03T08:00:00+08:00"
        ]),
        (.travel, ["destination": "苏州", "eventDate": "2026-07-03"]),
        (.interview, ["title": "产品面试", "startDateTime": "2026-07-03T11:00:00+08:00"]),
        (.deadline, ["title": "报名截止", "eventDate": "2026-07-03"]),
        (.unknown, ["title": "社区活动", "eventDate": "2026-07-03"])
    ]

    for (kind, fields) in fixtures {
        #expect(
            RecognitionKindSchema.schema(for: kind)
                .missingFields(in: fields)
                .isEmpty,
            "Unexpected missing fields for \(kind)"
        )
    }
}

@Test func trainSchemaReportsOnlyMissingMinimumFields() {
    let missing = RecognitionKindSchema.schema(for: .train).missingFields(in: [
        "departureStation": "上海虹桥站",
        "arrivalStation": "北京南站",
        "eventDate": "2026-07-03",
        "departureTime": "08:00"
    ])

    #expect(missing == ["车次"])
}

@Test func failureTechnicalDetailsNeverExposeSecrets() {
    let failure = RecognitionPipelineFailure(
        stage: .verification,
        reason: "服务返回错误",
        technicalSummary: "Authorization: Bearer sk-secret",
        httpStatus: 401,
        serviceCode: "invalid_api_key",
        serviceMessage: "image=data:image/jpeg;base64,AAAA",
        missingFields: [],
        responseExcerpt: #"{"apiKey":"sk-another-secret"}"#
    )

    #expect(!failure.technicalDetails.contains("sk-secret"))
    #expect(!failure.technicalDetails.contains("sk-another-secret"))
    #expect(!failure.technicalDetails.contains("base64,AAAA"))
    #expect(failure.technicalDetails.contains("HTTP 401"))
    #expect(failure.technicalDetails.contains("invalid_api_key"))
}

@Test func failureBoundsLongResponseExcerpt() {
    let failure = RecognitionPipelineFailure(
        stage: .verification,
        reason: "响应格式异常",
        technicalSummary: nil,
        httpStatus: nil,
        serviceCode: nil,
        serviceMessage: nil,
        missingFields: [],
        responseExcerpt: String(repeating: "x", count: 2_000)
    )

    #expect(failure.technicalDetails.count < 1_000)
}
