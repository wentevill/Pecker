import Foundation
import PeckerCore

struct RecognizedEventValidation: Equatable {
    let payload: ExternalEventTemplatePayload
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
}

struct RecognizedEventValidator {
    let calendar: Calendar

    func validate(
        _ payload: ExternalEventTemplatePayload
    ) throws -> RecognizedEventValidation {
        let missing = RecognitionKindSchema.schema(for: payload.kind)
            .missingFields(in: payload.fields)
        guard missing.isEmpty else {
            throw RecognitionPipelineFailure(
                stage: .validation,
                reason: "核对后仍缺少：\(missing.joined(separator: "、"))",
                technicalSummary: "最终结构化结果未满足 \(payload.kind.rawValue) 的最小成功条件",
                httpStatus: nil,
                serviceCode: nil,
                serviceMessage: nil,
                missingFields: missing,
                responseExcerpt: nil
            )
        }

        let eventDate = value(
            in: payload.fields,
            keys: ["eventDate", "event_date", "date"]
        )
        let startTime = value(
            in: payload.fields,
            keys: [
                "departureTime", "departure_time", "startTime", "start_time",
                "dueTime", "deadlineTime"
            ]
        )
        let explicitStartText = value(
            in: payload.fields,
            keys: [
                "startDateTime", "start_datetime", "departureDateTime",
                "dueDateTime", "deadlineDateTime"
            ]
        )
        let explicitStart = explicitStartText.flatMap(parseISO8601)
        let localStart = combine(date: eventDate, time: startTime)
        let dateOnlyStart = startTime == nil
            ? eventDate.flatMap(parseLocalDate)
            : nil

        guard let startDate = explicitStart ?? localStart ?? dateOnlyStart else {
            throw invalidTiming(
                reason: "无法解析事件日期或时间",
                fields: ["日期或时间"]
            )
        }
        let isAllDay = explicitStartText == nil
            && startTime == nil
            && eventDate != nil

        let explicitEndText = value(
            in: payload.fields,
            keys: ["endDateTime", "end_datetime", "arrivalDateTime"]
        )
        let arrivalDate = value(
            in: payload.fields,
            keys: ["arrivalDate", "arrival_date", "endDate"]
        )
        let endTime = value(
            in: payload.fields,
            keys: ["arrivalTime", "arrival_time", "endTime", "end_time"]
        )
        let explicitEnd = explicitEndText.flatMap(parseISO8601)
        var endDate = explicitEnd ?? combine(
            date: arrivalDate ?? eventDate,
            time: endTime
        )

        if explicitEndText == nil,
           arrivalDate == nil,
           let parsedEnd = endDate,
           parsedEnd < startDate
        {
            endDate = calendar.date(byAdding: .day, value: 1, to: parsedEnd)
        }

        if let endDate, endDate <= startDate {
            throw invalidTiming(
                reason: "结束时间必须晚于开始时间",
                fields: ["结束时间"]
            )
        }

        return RecognizedEventValidation(
            payload: payload,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay
        )
    }

    private func value(
        in fields: [String: String],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let match = fields.first(where: {
                $0.key.caseInsensitiveCompare(key) == .orderedSame
            })?.value.trimmingCharacters(in: .whitespacesAndNewlines),
               !match.isEmpty {
                return match
            }
        }
        return nil
    }

    private func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func parseLocalDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value).map(calendar.startOfDay(for:))
    }

    private func combine(date: String?, time: String?) -> Date? {
        guard let date, let time else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(date) \(time)")
    }

    private func invalidTiming(
        reason: String,
        fields: [String]
    ) -> RecognitionPipelineFailure {
        RecognitionPipelineFailure(
            stage: .validation,
            reason: reason,
            technicalSummary: "最终结构化结果中的时间字段无法形成有效事件区间",
            httpStatus: nil,
            serviceCode: nil,
            serviceMessage: nil,
            missingFields: fields,
            responseExcerpt: nil
        )
    }
}
