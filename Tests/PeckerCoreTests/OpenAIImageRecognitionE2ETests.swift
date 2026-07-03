import Foundation
import Testing
@testable import PeckerCore

#if canImport(AppKit)
import AppKit
#endif

@Test(.enabled(if: ProcessInfo.processInfo.environment["PECKER_RUN_OPENAI_IMAGE_E2E"] == "1"))
func openAIProviderRecognizesChineseAndEuropeanCardImagesEndToEnd() async throws {
    let environment = ProcessInfo.processInfo.environment
    let host = try requireEnvironmentValue("PECKER_OPENAI_HOST", in: environment)
    let apiKey = try requireEnvironmentValue("PECKER_OPENAI_API_KEY", in: environment)
    let model = try requireEnvironmentValue("PECKER_OPENAI_MODEL", in: environment)
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let outputURL = rootURL
        .appendingPathComponent("docs")
        .appendingPathComponent("e2e-results")
        .appendingPathComponent(timestampForPath())
    let samplesURL = outputURL.appendingPathComponent("samples")
    let resultsURL = outputURL.appendingPathComponent("results")
    try FileManager.default.createDirectory(
        at: samplesURL,
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: resultsURL,
        withIntermediateDirectories: true
    )

    let provider = OpenAIRecognitionProvider(
        configuration: .init(host: host, apiKey: apiKey, model: model)
    )
    let referenceDate = ISO8601DateFormatter()
        .date(from: "2026-06-30T04:00:00Z")!
    let cases = imageE2ECases()
    var records: [ImageE2ERecord] = []

    for testCase in cases {
        let imageURL = samplesURL.appendingPathComponent("\(testCase.id).png")
        try renderCardImage(for: testCase, to: imageURL)
        let imageData = try Data(contentsOf: imageURL)

        let startedAt = Date()
        do {
            let result = try await provider.recognize(
                .importedImage(
                    id: testCase.id,
                    imageData: imageData,
                    filename: imageURL.lastPathComponent,
                    referenceDate: referenceDate,
                    timeZoneIdentifier: testCase.timeZoneIdentifier
                )
            )
            let missingFields = testCase.requiredFields.filter {
                result.payload.fields[$0]?.isEmpty != false
            }
            let unexpectedKind = result.payload.kind != testCase.expectedKind
            let passed = missingFields.isEmpty && !unexpectedKind
            let record = ImageE2ERecord(
                id: testCase.id,
                region: testCase.region,
                expectedKind: testCase.expectedKind.rawValue,
                actualKind: result.payload.kind.rawValue,
                passed: passed,
                durationSeconds: Date().timeIntervalSince(startedAt),
                imagePath: relativePath(imageURL, from: rootURL),
                resultPath: relativePath(
                    resultsURL.appendingPathComponent("\(testCase.id).json"),
                    from: rootURL
                ),
                requiredFields: testCase.requiredFields,
                missingFields: missingFields,
                fields: result.payload.fields,
                error: unexpectedKind
                    ? "Expected kind \(testCase.expectedKind.rawValue), got \(result.payload.kind.rawValue)"
                    : nil
            )
            try writeJSON(record, to: resultsURL.appendingPathComponent("\(testCase.id).json"))
            records.append(record)
        } catch {
            let record = ImageE2ERecord(
                id: testCase.id,
                region: testCase.region,
                expectedKind: testCase.expectedKind.rawValue,
                actualKind: nil,
                passed: false,
                durationSeconds: Date().timeIntervalSince(startedAt),
                imagePath: relativePath(imageURL, from: rootURL),
                resultPath: relativePath(
                    resultsURL.appendingPathComponent("\(testCase.id).json"),
                    from: rootURL
                ),
                requiredFields: testCase.requiredFields,
                missingFields: testCase.requiredFields,
                fields: [:],
                error: String(describing: error)
            )
            try writeJSON(record, to: resultsURL.appendingPathComponent("\(testCase.id).json"))
            records.append(record)
        }
    }

    try writeJSON(records, to: outputURL.appendingPathComponent("results.json"))
    try markdownSummary(for: records, model: model)
        .write(
            to: outputURL.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )

    let failed = records.filter { !$0.passed }
    #expect(failed.isEmpty, "E2E failures were recorded in \(outputURL.path)")
}

private struct ImageE2ECase {
    let id: String
    let region: String
    let expectedKind: TimelineKind
    let timeZoneIdentifier: String
    let title: String
    let subtitle: String
    let lines: [String]
    let footer: String
    let requiredFields: [String]
}

private struct ImageE2ERecord: Codable {
    let id: String
    let region: String
    let expectedKind: String
    let actualKind: String?
    let passed: Bool
    let durationSeconds: TimeInterval
    let imagePath: String
    let resultPath: String
    let requiredFields: [String]
    let missingFields: [String]
    let fields: [String: String]
    let error: String?
}

private func imageE2ECases() -> [ImageE2ECase] {
    [
        .init(
            id: "china-train",
            region: "China",
            expectedKind: .train,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "\u{4e2d}\u{56fd}\u{94c1}\u{8def}\u{7535}\u{5b50}\u{5ba2}\u{7968}",
            subtitle: "G123 \u{4e0a}\u{6d77}\u{8679}\u{6865}\u{7ad9} -> \u{5317}\u{4eac}\u{5357}\u{7ad9}",
            lines: [
                "\u{4e58}\u{8f66}\u{65e5}\u{671f}: 2026-07-03 08:00",
                "\u{5230}\u{8fbe}\u{65f6}\u{95f4}: 2026-07-03 12:28",
                "\u{8f66}\u{53a2}/\u{5ea7}\u{4f4d}: 08\u{8f66} 03A",
                "\u{68c0}\u{7968}\u{53e3}: B7  \u{7968}\u{4ef7}: ¥553.00"
            ],
            footer: "\u{4e58}\u{8f66}\u{4eba}: \u{738b}\u{5c0f}\u{660e}  \u{8ba2}\u{5355}\u{53f7}: E123456789",
            requiredFields: ["trainNumber", "departureStation", "arrivalStation", "departureDateTime"]
        ),
        .init(
            id: "china-flight",
            region: "China",
            expectedKind: .flight,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "\u{767b}\u{673a}\u{724c} BOARDING PASS",
            subtitle: "MU5101 \u{4e0a}\u{6d77}\u{8679}\u{6865} SHA -> \u{5317}\u{4eac}\u{9996}\u{90fd} PEK",
            lines: [
                "\u{65e5}\u{671f}: 2026-07-04  \u{8d77}\u{98de}: 09:30  \u{5230}\u{8fbe}: 11:45",
                "\u{822a}\u{7ad9}\u{697c}: T2  \u{767b}\u{673a}\u{53e3}: 28  \u{5ea7}\u{4f4d}: 12A",
                "\u{65c5}\u{5ba2}: \u{674e}\u{534e}  \u{8231}\u{4f4d}: \u{7ecf}\u{6d4e}\u{8231}"
            ],
            footer: "\u{8bf7}\u{4e8e} 08:50 \u{524d}\u{5b8c}\u{6210}\u{767b}\u{673a}",
            requiredFields: ["flightNumber", "departureAirportCode", "arrivalAirportCode", "departureDateTime"]
        ),
        .init(
            id: "china-meeting",
            region: "China",
            expectedKind: .meeting,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "\u{4f1a}\u{8bae}\u{9080}\u{8bf7}",
            subtitle: "\u{4ea7}\u{54c1}\u{8def}\u{7ebf}\u{56fe}\u{8bc4}\u{5ba1}",
            lines: [
                "\u{65f6}\u{95f4}: 2026-07-05 14:00-15:30",
                "\u{5730}\u{70b9}: \u{4e0a}\u{6d77}\u{529e}\u{516c}\u{5ba4} 12F \u{4f1a}\u{8bae}\u{5ba4} A",
                "\u{7ec4}\u{7ec7}\u{8005}: \u{9648}\u{96e8}",
                "\u{8bae}\u{7a0b}: Q3 \u{4f18}\u{5148}\u{7ea7}\u{4e0e}\u{53d1}\u{5e03}\u{8282}\u{594f}"
            ],
            footer: "\u{53c2}\u{4f1a}\u{4eba}: \u{4ea7}\u{54c1}、\u{8bbe}\u{8ba1}、\u{5de5}\u{7a0b}",
            requiredFields: ["title", "startDateTime"]
        ),
        .init(
            id: "china-task",
            region: "China",
            expectedKind: .task,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "\u{4efb}\u{52a1}\u{5361}",
            subtitle: "\u{5de1}\u{68c0}\u{4ed3}\u{5e93}\u{51b7}\u{94fe}\u{8bbe}\u{5907}",
            lines: [
                "\u{6267}\u{884c}\u{65f6}\u{95f4}: 2026-07-06 23:30",
                "\u{5730}\u{70b9}: \u{82cf}\u{5dde}\u{4e00}\u{53f7}\u{4ed3}\u{5e93}",
                "\u{8d1f}\u{8d23}\u{4eba}: \u{8d75}\u{78ca}",
                "\u{4f18}\u{5148}\u{7ea7}: \u{9ad8}"
            ],
            footer: "\u{8bb0}\u{5f55}\u{6e29}\u{5ea6}\u{5e76}\u{62cd}\u{7167}\u{4e0a}\u{4f20}",
            requiredFields: ["title", "dueDateTime"]
        ),
        .init(
            id: "china-travel",
            region: "China",
            expectedKind: .travel,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "\u{9152}\u{5e97}\u{9884}\u{8ba2}\u{786e}\u{8ba4}",
            subtitle: "\u{676d}\u{5dde}\u{897f}\u{6e56}\u{56fd}\u{5bbe}\u{9986}",
            lines: [
                "\u{5165}\u{4f4f}: 2026-07-08 15:00",
                "\u{9000}\u{623f}: 2026-07-10 12:00",
                "\u{5730}\u{5740}: \u{676d}\u{5dde}\u{5e02}\u{897f}\u{6e56}\u{533a}\u{6768}\u{516c}\u{5824}18\u{53f7}",
                "\u{9884}\u{8ba2}\u{53f7}: CNHZ8891"
            ],
            footer: "\u{623f}\u{578b}: \u{6e56}\u{666f}\u{5927}\u{5e8a}\u{623f}",
            requiredFields: ["title", "startDateTime"]
        ),
        .init(
            id: "china-interview",
            region: "China",
            expectedKind: .interview,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "\u{9762}\u{8bd5}\u{5b89}\u{6392}",
            subtitle: "\u{5b57}\u{8282}\u{8df3}\u{52a8} iOS \u{5de5}\u{7a0b}\u{5e08}",
            lines: [
                "\u{65f6}\u{95f4}: 2026-07-09 10:00-11:00",
                "\u{5730}\u{70b9}: \u{98de}\u{4e66}\u{4f1a}\u{8bae}",
                "\u{9762}\u{8bd5}\u{5b98}: \u{5218}\u{5a1c}",
                "\u{8054}\u{7cfb}\u{4eba}: hr-cn@example.com"
            ],
            footer: "\u{8bf7}\u{63d0}\u{524d} 5 \u{5206}\u{949f}\u{8fdb}\u{5165}\u{4f1a}\u{8bae}",
            requiredFields: ["title", "startDateTime"]
        ),
        .init(
            id: "china-deadline",
            region: "China",
            expectedKind: .deadline,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "\u{622a}\u{6b62}\u{63d0}\u{9192}",
            subtitle: "\u{63d0}\u{4ea4}\u{589e}\u{503c}\u{7a0e}\u{7533}\u{62a5}\u{6750}\u{6599}",
            lines: [
                "\u{622a}\u{6b62}\u{65f6}\u{95f4}: 2026-07-15 18:00",
                "\u{9879}\u{76ee}: \u{8d22}\u{52a1}\u{6708}\u{7ed3}",
                "\u{63d0}\u{4ea4}\u{6e20}\u{9053}: \u{7535}\u{5b50}\u{7a0e}\u{52a1}\u{5c40}",
                "\u{8d1f}\u{8d23}\u{4eba}: \u{8d22}\u{52a1}\u{90e8}"
            ],
            footer: "\u{903e}\u{671f}\u{4f1a}\u{5f71}\u{54cd}\u{672c}\u{6708}\u{7ed3}\u{8d26}",
            requiredFields: ["title", "deadlineDateTime"]
        ),
        .init(
            id: "china-unknown",
            region: "China",
            expectedKind: .unknown,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "\u{5496}\u{5561}\u{5e97}\u{4f1a}\u{5458}\u{5361}",
            subtitle: "\u{672c}\u{5361}\u{4ec5}\u{7528}\u{4e8e}\u{79ef}\u{5206}\u{4e0e}\u{6298}\u{6263}",
            lines: [
                "\u{4f1a}\u{5458}\u{53f7}: 8866 1024",
                "\u{4f59}\u{989d}: ¥120.00",
                "\u{7b49}\u{7ea7}: \u{91d1}\u{5361}",
                "\u{65e0}\u{9884}\u{7ea6}、\u{4efb}\u{52a1}\u{6216}\u{65e5}\u{671f}\u{5b89}\u{6392}"
            ],
            footer: "\u{670d}\u{52a1}\u{70ed}\u{7ebf}: 400-800-1234",
            requiredFields: []
        ),
        .init(
            id: "europe-train",
            region: "Europe",
            expectedKind: .train,
            timeZoneIdentifier: "Europe/Paris",
            title: "SNCF e-ticket",
            subtitle: "TGV 6173 Paris Gare de Lyon -> Lyon Part-Dieu",
            lines: [
                "Date: 2026-07-03  Departure: 08:42",
                "Arrival: 10:56",
                "Coach: 12  Seat: 45A",
                "Class: 2nd  Price: EUR 64.00"
            ],
            footer: "Passenger: Marie Dubois  Booking: FR78391",
            requiredFields: ["trainNumber", "departureStation", "arrivalStation", "departureDateTime"]
        ),
        .init(
            id: "europe-flight",
            region: "Europe",
            expectedKind: .flight,
            timeZoneIdentifier: "Europe/Berlin",
            title: "BOARDING PASS",
            subtitle: "LH2030 Munich MUC -> Berlin BER",
            lines: [
                "Date: 2026-07-04  Departure: 16:20  Arrival: 17:30",
                "Terminal: 2  Gate: G18  Seat: 21C",
                "Passenger: Anna Keller",
                "Booking reference: EU4F8K"
            ],
            footer: "Boarding closes at 16:00",
            requiredFields: ["flightNumber", "departureAirportCode", "arrivalAirportCode", "departureDateTime"]
        ),
        .init(
            id: "europe-meeting",
            region: "Europe",
            expectedKind: .meeting,
            timeZoneIdentifier: "Europe/London",
            title: "Calendar Invite",
            subtitle: "Design Critique",
            lines: [
                "When: 2026-07-05 09:30-10:30",
                "Where: London Studio, Room 3B",
                "Organizer: Olivia Smith",
                "Agenda: Prototype review and next steps"
            ],
            footer: "Guests: Product, Design, Engineering",
            requiredFields: ["title", "startDateTime"]
        ),
        .init(
            id: "europe-task",
            region: "Europe",
            expectedKind: .task,
            timeZoneIdentifier: "Europe/Rome",
            title: "Work Order",
            subtitle: "Inspect refrigeration unit",
            lines: [
                "Due: 2026-07-06 18:00",
                "Location: Milan Warehouse B",
                "Assignee: Marco Rossi",
                "Priority: High"
            ],
            footer: "Upload temperature log after inspection",
            requiredFields: ["title", "dueDateTime"]
        ),
        .init(
            id: "europe-travel",
            region: "Europe",
            expectedKind: .travel,
            timeZoneIdentifier: "Europe/Madrid",
            title: "Hotel Booking Confirmation",
            subtitle: "Hotel Atlantico Madrid",
            lines: [
                "Check-in: 2026-07-08 15:00",
                "Check-out: 2026-07-10 11:00",
                "Address: Gran Via 38, Madrid",
                "Reservation: ES-MAD-5512"
            ],
            footer: "Room: Superior double",
            requiredFields: ["title", "startDateTime"]
        ),
        .init(
            id: "europe-interview",
            region: "Europe",
            expectedKind: .interview,
            timeZoneIdentifier: "Europe/Amsterdam",
            title: "Interview Schedule",
            subtitle: "Booking.com iOS Engineer",
            lines: [
                "Time: 2026-07-09 13:00-14:00",
                "Location: Google Meet",
                "Interviewer: Sofia Janssen",
                "Contact: recruiting-eu@example.com"
            ],
            footer: "Please join 5 minutes early",
            requiredFields: ["title", "startDateTime"]
        ),
        .init(
            id: "europe-deadline",
            region: "Europe",
            expectedKind: .deadline,
            timeZoneIdentifier: "Europe/Paris",
            title: "Submission Deadline",
            subtitle: "EU grant progress report",
            lines: [
                "Deadline: 2026-07-15 17:00",
                "Project: Horizon Pilot",
                "Channel: Funding portal",
                "Owner: Research Office"
            ],
            footer: "Late submission is not accepted",
            requiredFields: ["title", "deadlineDateTime"]
        ),
        .init(
            id: "europe-unknown",
            region: "Europe",
            expectedKind: .unknown,
            timeZoneIdentifier: "Europe/Paris",
            title: "Museum Membership Card",
            subtitle: "Annual pass and shop discount",
            lines: [
                "Member: 4829 1130",
                "Level: Gold",
                "Balance: EUR 0.00",
                "No appointment, trip, task, or deadline"
            ],
            footer: "Customer service: +33 1 00 00 00 00",
            requiredFields: []
        )
    ]
}

private func requireEnvironmentValue(
    _ name: String,
    in environment: [String: String]
) throws -> String {
    guard let value = environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty
    else {
        throw E2EConfigurationError.missingEnvironmentValue(name)
    }
    return value
}

private enum E2EConfigurationError: Error, CustomStringConvertible {
    case missingEnvironmentValue(String)

    var description: String {
        switch self {
        case let .missingEnvironmentValue(name):
            "Missing required environment value: \(name)"
        }
    }
}

private func renderCardImage(for testCase: ImageE2ECase, to url: URL) throws {
#if canImport(AppKit)
    let size = NSSize(width: 960, height: 600)
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw E2EImageRenderingError.failedToEncodePNG
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    defer {
        NSGraphicsContext.restoreGraphicsState()
    }

    NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.95, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

    let accent = testCase.region == "China"
        ? NSColor(calibratedRed: 0.72, green: 0.12, blue: 0.12, alpha: 1)
        : NSColor(calibratedRed: 0.08, green: 0.23, blue: 0.55, alpha: 1)
    accent.setFill()
    NSBezierPath(
        roundedRect: NSRect(x: 52, y: 492, width: 856, height: 56),
        xRadius: 8,
        yRadius: 8
    ).fill()

    draw(testCase.title, x: 80, y: 505, size: 28, color: .white, weight: .semibold)
    draw(testCase.subtitle, x: 80, y: 432, size: 34, color: .black, weight: .bold)

    NSColor(calibratedWhite: 0.88, alpha: 1).setStroke()
    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: 80, y: 408))
    divider.line(to: NSPoint(x: 880, y: 408))
    divider.lineWidth = 2
    divider.stroke()

    for (index, line) in testCase.lines.enumerated() {
        draw(line, x: 90, y: 354 - CGFloat(index * 58), size: 24)
    }

    NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: NSRect(x: 70, y: 54, width: 820, height: 54),
        xRadius: 6,
        yRadius: 6
    ).fill()
    draw(testCase.footer, x: 92, y: 69, size: 20, color: .white)

    guard let pngData = representation.representation(using: .png, properties: [:])
    else {
        throw E2EImageRenderingError.failedToEncodePNG
    }
    try pngData.write(to: url, options: .atomic)
#else
    throw E2EImageRenderingError.appKitUnavailable
#endif
}

#if canImport(AppKit)
private func draw(
    _ text: String,
    x: CGFloat,
    y: CGFloat,
    size: CGFloat,
    color: NSColor = .black,
    weight: NSFont.Weight = .regular
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    text.draw(
        in: NSRect(x: x, y: y, width: 780, height: size + 12),
        withAttributes: attributes
    )
}
#endif

private enum E2EImageRenderingError: Error {
    case appKitUnavailable
    case failedToEncodePNG
}

private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(value).write(to: url, options: .atomic)
}

private func markdownSummary(for records: [ImageE2ERecord], model: String) -> String {
    var lines = [
        "# OpenAI Image Recognition E2E",
        "",
        "- Model: \(model)",
        "- Total: \(records.count)",
        "- Passed: \(records.filter(\.passed).count)",
        "- Failed: \(records.filter { !$0.passed }.count)",
        "",
        "| Case | Region | Expected | Actual | Result | Missing Fields |",
        "| --- | --- | --- | --- | --- | --- |"
    ]
    lines += records.map { record in
        [
            record.id,
            record.region,
            record.expectedKind,
            record.actualKind ?? "-",
            record.passed ? "PASS" : "FAIL",
            record.missingFields.isEmpty ? "-" : record.missingFields.joined(separator: ", ")
        ].joined(separator: " | ").wrappedAsMarkdownTableRow()
    }
    lines.append("")
    lines.append("Each sample image is in `samples/`; each per-case result is in `results/`.")
    return lines.joined(separator: "\n")
}

private extension String {
    func wrappedAsMarkdownTableRow() -> String {
        "| \(self) |"
    }
}

private func relativePath(_ url: URL, from rootURL: URL) -> String {
    let root = rootURL.standardizedFileURL.path
    let path = url.standardizedFileURL.path
    guard path.hasPrefix(root + "/") else {
        return path
    }
    return String(path.dropFirst(root.count + 1))
}

private func timestampForPath() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter.string(from: Date())
}
