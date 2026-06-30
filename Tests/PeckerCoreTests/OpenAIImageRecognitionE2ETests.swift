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
            title: "中国铁路电子客票",
            subtitle: "G123 上海虹桥站 -> 北京南站",
            lines: [
                "乘车日期: 2026-07-03 08:00",
                "到达时间: 2026-07-03 12:28",
                "车厢/座位: 08车 03A",
                "检票口: B7  票价: ¥553.00"
            ],
            footer: "乘车人: 王小明  订单号: E123456789",
            requiredFields: ["trainNumber", "departureStation", "arrivalStation", "departureDateTime"]
        ),
        .init(
            id: "china-flight",
            region: "China",
            expectedKind: .flight,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "登机牌 BOARDING PASS",
            subtitle: "MU5101 上海虹桥 SHA -> 北京首都 PEK",
            lines: [
                "日期: 2026-07-04  起飞: 09:30  到达: 11:45",
                "航站楼: T2  登机口: 28  座位: 12A",
                "旅客: 李华  舱位: 经济舱"
            ],
            footer: "请于 08:50 前完成登机",
            requiredFields: ["flightNumber", "departureAirportCode", "arrivalAirportCode", "departureDateTime"]
        ),
        .init(
            id: "china-meeting",
            region: "China",
            expectedKind: .meeting,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "会议邀请",
            subtitle: "产品路线图评审",
            lines: [
                "时间: 2026-07-05 14:00-15:30",
                "地点: 上海办公室 12F 会议室 A",
                "组织者: 陈雨",
                "议程: Q3 优先级与发布节奏"
            ],
            footer: "参会人: 产品、设计、工程",
            requiredFields: ["title", "startDateTime"]
        ),
        .init(
            id: "china-task",
            region: "China",
            expectedKind: .task,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "任务卡",
            subtitle: "巡检仓库冷链设备",
            lines: [
                "执行时间: 2026-07-06 23:30",
                "地点: 苏州一号仓库",
                "负责人: 赵磊",
                "优先级: 高"
            ],
            footer: "记录温度并拍照上传",
            requiredFields: ["title", "dueDateTime"]
        ),
        .init(
            id: "china-travel",
            region: "China",
            expectedKind: .travel,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "酒店预订确认",
            subtitle: "杭州西湖国宾馆",
            lines: [
                "入住: 2026-07-08 15:00",
                "退房: 2026-07-10 12:00",
                "地址: 杭州市西湖区杨公堤18号",
                "预订号: CNHZ8891"
            ],
            footer: "房型: 湖景大床房",
            requiredFields: ["title", "startDateTime"]
        ),
        .init(
            id: "china-interview",
            region: "China",
            expectedKind: .interview,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "面试安排",
            subtitle: "字节跳动 iOS 工程师",
            lines: [
                "时间: 2026-07-09 10:00-11:00",
                "地点: 飞书会议",
                "面试官: 刘娜",
                "联系人: hr-cn@example.com"
            ],
            footer: "请提前 5 分钟进入会议",
            requiredFields: ["title", "startDateTime"]
        ),
        .init(
            id: "china-deadline",
            region: "China",
            expectedKind: .deadline,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "截止提醒",
            subtitle: "提交增值税申报材料",
            lines: [
                "截止时间: 2026-07-15 18:00",
                "项目: 财务月结",
                "提交渠道: 电子税务局",
                "负责人: 财务部"
            ],
            footer: "逾期会影响本月结账",
            requiredFields: ["title", "deadlineDateTime"]
        ),
        .init(
            id: "china-unknown",
            region: "China",
            expectedKind: .unknown,
            timeZoneIdentifier: "Asia/Shanghai",
            title: "咖啡店会员卡",
            subtitle: "本卡仅用于积分与折扣",
            lines: [
                "会员号: 8866 1024",
                "余额: ¥120.00",
                "等级: 金卡",
                "无预约、任务或日期安排"
            ],
            footer: "服务热线: 400-800-1234",
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
