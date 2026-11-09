import Foundation
import Intents

func senderImage(intent: INSendMessageIntent, image: INImage) -> INImage? {
    intent.setImage(image, forParameterNamed: \.sender)
    return intent.image(forParameterNamed: \.sender)
}

func parameter() -> INParameter? {
    return INParameter(keyPath: \INSendMessageIntent.sender)
}

func missedCall(identifier: String, date: Date, caller: INPerson, duration: Int32?, unseen: Bool) -> (INCallRecord, Double?, Bool?) {
    let record = INCallRecord(identifier: identifier, dateCreated: date, caller: caller, callRecordType: .missed, callCapability: .audioCall, callDuration: duration.flatMap(Double.init), unseen: unseen)
    return (record, record.callDuration, record.unseen)
}

func countedCall(identifier: String) -> Int? {
    return INCallRecord(identifier: identifier, callRecordType: .received, callCapability: .videoCall, numberOfCalls: 3).numberOfCalls
}

func searchCalls(recipient: INPerson?) -> (INSearchCallHistoryIntent, Bool?) {
    let intent = INSearchCallHistoryIntent(recipient: recipient, callCapabilities: [.audioCall, .videoCall], callTypes: [.missed, .received], unseen: true)
    return (intent, intent.unseen)
}

func callHistoryResponse(calls: [INCallRecord], activity: NSUserActivity) -> INSearchCallHistoryIntentResponse {
    let response = INSearchCallHistoryIntentResponse(code: .success, userActivity: activity)
    response.callRecords = calls
    return response
}

func scope(for intent: INSearchForMessagesIntent) -> [String] {
    var scope: [String] = []
    switch intent.notificationIdentifiersOperator {
    case .none:
        scope.append("none")
    case .all, .any:
        scope.append(contentsOf: intent.notificationIdentifiers ?? [])
    @unknown default:
        break
    }
    return scope + (intent.identifiers ?? [])
}

func messagesResponse(messages: [INMessage], activity: NSUserActivity) -> INSearchForMessagesIntentResponse {
    let response = INSearchForMessagesIntentResponse(code: .success, userActivity: activity)
    response.messages = messages
    return response
}

func attributes() -> INMessageAttributeOptionsResolutionResult {
    return .success(with: .unread)
}

func attribute(for intent: INSetMessageAttributeIntent) -> INMessageAttributeResolutionResult {
    let supported: [INMessageAttribute] = [.read, .unread]
    var attribute = intent.attribute
    if attribute == .flagged {
        attribute = .unread
    }
    if supported.contains(attribute) {
        return .success(with: attribute)
    }
    return .confirmationRequired(with: intent.attribute)
}

func setAttributeResponse(code: INSetMessageAttributeIntentResponseCode, activity: NSUserActivity) -> INSetMessageAttributeIntentResponse {
    return INSetMessageAttributeIntentResponse(code: code, userActivity: activity)
}

func persons(persons: [INPerson]) -> [INPersonResolutionResult] {
    return [.success(with: persons[0]), .disambiguation(with: persons), .needsValue(), .unsupported(), .notRequired()]
}

func recipients(person: INPerson) -> [INSendMessageRecipientResolutionResult] {
    return [.success(with: person), .unsupported(forReason: .messagingServiceNotEnabledForRecipient), .unsupported(forReason: .noAccount), .notRequired()]
}

func contacts(person: INPerson) -> [INStartCallContactResolutionResult] {
    return [.success(with: person), .disambiguation(with: [person]), .unsupported(), .notRequired()]
}

func content(text: String) -> INStringResolutionResult {
    return text.isEmpty ? .needsValue() : .success(with: text)
}

func destination() -> INCallDestinationTypeResolutionResult {
    return .success(with: .normal)
}

func sendResponse(activity: NSUserActivity) -> [INSendMessageIntentResponse] {
    return [INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: activity), INSendMessageIntentResponse(code: .ready, userActivity: activity), INSendMessageIntentResponse(code: .success, userActivity: activity)]
}

func startCallResponse(activity: NSUserActivity) -> [INStartCallIntentResponse] {
    return [INStartCallIntentResponse(code: .continueInApp, userActivity: activity), INStartCallIntentResponse(code: .failureRequiringAppLaunch, userActivity: activity)]
}
