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
                reason: "\u{6838}\u{5bf9}\u{540e}\u{4ecd}\u{7f3a}\u{5c11}：\(missing.joined(separator: "、"))",
                technicalSummary: "\u{6700}\u{7ec8}\u{7ed3}\u{6784}\u{5316}\u{7ed3}\u{679c}\u{672a}\u{6ee1}\u{8db3} \(payload.kind.rawValue) \u{7684}\u{6700}\u{5c0f}\u{6210}\u{529f}\u{6761}\u{4ef6}",
                httpStatus: nil,
                serviceCode: nil,
                serviceMessage: nil,
                missingFields: missing,
                responseExcerpt: nil,
                code: .validationMissingContent
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
                "dueDateTime", "executionDateTime", "deadlineDateTime"
            ]
        )
        let explicitStart = explicitStartText.flatMap(parseISO8601)
        let localStart = combine(date: eventDate, time: startTime)
        let dateOnlyStart = startTime == nil
            ? eventDate.flatMap(parseLocalDate)
            : nil

        guard let startDate = explicitStart ?? localStart ?? dateOnlyStart else {
            throw invalidTiming(
                reason: "\u{65e0}\u{6cd5}\u{89e3}\u{6790}\u{4e8b}\u{4ef6}\u{65e5}\u{671f}\u{6216}\u{65f6}\u{95f4}",
                fields: ["\u{65e5}\u{671f}\u{6216}\u{65f6}\u{95f4}"]
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
                reason: "\u{7ed3}\u{675f}\u{65f6}\u{95f4}\u{5fc5}\u{987b}\u{665a}\u{4e8e}\u{5f00}\u{59cb}\u{65f6}\u{95f4}",
                fields: ["\u{7ed3}\u{675f}\u{65f6}\u{95f4}"]
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
            technicalSummary: "\u{6700}\u{7ec8}\u{7ed3}\u{6784}\u{5316}\u{7ed3}\u{679c}\u{4e2d}\u{7684}\u{65f6}\u{95f4}\u{5b57}\u{6bb5}\u{65e0}\u{6cd5}\u{5f62}\u{6210}\u{6709}\u{6548}\u{4e8b}\u{4ef6}\u{533a}\u{95f4}",
            httpStatus: nil,
            serviceCode: nil,
            serviceMessage: nil,
            missingFields: fields,
            responseExcerpt: nil,
            code: .validationMissingContent
        )
    }
}
