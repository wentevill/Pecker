import Foundation
import Testing
@testable import PeckerCore

@Test func classificationContractUsesStrictKindEnum() throws {
    let contract = RecognitionFunctionContract.classifyEvent
    #expect(contract.name == "classify_event")
    #expect(contract.kind == nil)
    #expect(contract.requiredProperties == ["kind"])

    let function = try functionDefinition(contract)
    #expect(function["strict"] as? Bool == true)
    let parameters = try #require(function["parameters"] as? [String: Any])
    #expect(parameters["additionalProperties"] as? Bool == false)
    let properties = try #require(
        parameters["properties"] as? [String: [String: Any]]
    )
    let kind = try #require(properties["kind"])
    #expect(kind["type"] as? String == "string")
    #expect(kind["enum"] as? [String] == TimelineKind.allCases.map(\.rawValue))
}

@Test(arguments: TimelineKind.allCases)
func everyKindHasDedicatedStrictFieldFunction(_ kind: TimelineKind) throws {
    let contract = RecognitionFunctionContract.fieldContract(for: kind)
    #expect(contract.kind == kind)
    #expect(contract.name.hasPrefix("fill_"))
    #expect(contract.requiredProperties == contract.properties.map(\.name))

    let function = try functionDefinition(contract)
    #expect(function["strict"] as? Bool == true)
    let parameters = try #require(function["parameters"] as? [String: Any])
    #expect(parameters["additionalProperties"] as? Bool == false)
    #expect(
        parameters["required"] as? [String] == contract.properties.map(\.name)
    )

    let properties = try #require(
        parameters["properties"] as? [String: [String: Any]]
    )
    for property in contract.properties {
        let definition = try #require(properties[property.name])
        #expect(definition["type"] as? [String] == ["string", "null"])
    }
}

@Test func eventFunctionsUseCanonicalDateTimeFields() {
    #expect(
        RecognitionFunctionContract.fieldContract(for: .train)
            .properties.map(\.name)
            .contains("departureDateTime")
    )
    #expect(
        RecognitionFunctionContract.fieldContract(for: .task)
            .properties.map(\.name)
            .contains("dueDateTime")
    )
    #expect(
        RecognitionFunctionContract.fieldContract(for: .deadline)
            .properties.map(\.name)
            .contains("deadlineDateTime")
    )
}

@Test func fieldContractsCoverEveryTimelineKindExactlyOnce() {
    #expect(
        RecognitionFunctionContract.fieldContracts.compactMap(\.kind)
            == TimelineKind.allCases
    )
}

private func functionDefinition(
    _ contract: RecognitionFunctionContract
) throws -> [String: Any] {
    let tool = contract.toolDefinition
    #expect(tool["type"] as? String == "function")
    return try #require(tool["function"] as? [String: Any])
}
