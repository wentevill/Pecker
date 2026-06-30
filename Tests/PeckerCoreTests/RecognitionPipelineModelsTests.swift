import Foundation
import Testing
@testable import PeckerCore

@Test func trainSchemaRequiresOnlyMinimumUsableFields() {
    let schema = RecognitionKindSchema.schema(for: .train)
    let fields = [
        "trainNumber": "G123",
        "departureStation": "\u{4e0a}\u{6d77}\u{8679}\u{6865}\u{7ad9}",
        "arrivalStation": "\u{5317}\u{4eac}\u{5357}\u{7ad9}",
        "startDateTime": "2026-07-03T08:00:00+08:00"
    ]

    #expect(schema.missingFields(in: fields).isEmpty)
}

@Test func everyKindSchemaAcceptsItsMinimumFields() {
    let fixtures: [(TimelineKind, [String: String])] = [
        (.meeting, ["title": "\u{8bbe}\u{8ba1}\u{8bc4}\u{5ba1}", "startDateTime": "2026-07-03T10:00:00+08:00"]),
        (.task, ["title": "\u{63d0}\u{4ea4}\u{6750}\u{6599}", "eventDate": "2026-07-03"]),
        (.flight, [
            "flightNumber": "MU5101",
            "departureAirportCode": "SHA",
            "arrivalAirportCode": "PEK",
            "startDateTime": "2026-07-03T09:00:00+08:00"
        ]),
        (.train, [
            "trainNumber": "G123",
            "departureStation": "\u{4e0a}\u{6d77}\u{8679}\u{6865}\u{7ad9}",
            "arrivalStation": "\u{5317}\u{4eac}\u{5357}\u{7ad9}",
            "startDateTime": "2026-07-03T08:00:00+08:00"
        ]),
        (.travel, ["destination": "\u{82cf}\u{5dde}", "eventDate": "2026-07-03"]),
        (.interview, ["title": "\u{4ea7}\u{54c1}\u{9762}\u{8bd5}", "startDateTime": "2026-07-03T11:00:00+08:00"]),
        (.deadline, ["title": "\u{62a5}\u{540d}\u{622a}\u{6b62}", "eventDate": "2026-07-03"]),
        (.unknown, ["title": "\u{793e}\u{533a}\u{6d3b}\u{52a8}", "eventDate": "2026-07-03"])
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
        "departureStation": "\u{4e0a}\u{6d77}\u{8679}\u{6865}\u{7ad9}",
        "arrivalStation": "\u{5317}\u{4eac}\u{5357}\u{7ad9}",
        "eventDate": "2026-07-03",
        "departureTime": "08:00"
    ])

    #expect(missing == ["\u{8f66}\u{6b21}"])
}

@Test func taskSchemaAcceptsCanonicalDueDateTime() {
    let missing = RecognitionKindSchema.schema(for: .task).missingFields(in: [
        "title": "\u{5de1}\u{903b}\u{4ed3}\u{5e93}",
        "dueDateTime": "2026-06-29T23:30:00+08:00"
    ])

    #expect(missing.isEmpty)
}

@Test func deadlineSchemaAcceptsCanonicalDeadlineDateTime() {
    let missing = RecognitionKindSchema.schema(for: .deadline)
        .missingFields(in: [
            "title": "\u{63d0}\u{4ea4}\u{62a5}\u{544a}",
            "deadlineDateTime": "2026-06-30T18:00:00+08:00"
        ])

    #expect(missing.isEmpty)
}

@Test func failureTechnicalDetailsNeverExposeSecrets() {
    let failure = RecognitionPipelineFailure(
        stage: .verification,
        reason: "\u{670d}\u{52a1}\u{8fd4}\u{56de}\u{9519}\u{8bef}",
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
        reason: "\u{54cd}\u{5e94}\u{683c}\u{5f0f}\u{5f02}\u{5e38}",
        technicalSummary: nil,
        httpStatus: nil,
        serviceCode: nil,
        serviceMessage: nil,
        missingFields: [],
        responseExcerpt: String(repeating: "x", count: 2_000)
    )

    #expect(failure.technicalDetails.count < 1_000)
}
