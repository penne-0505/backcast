import EventKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let eventStore = EKEventStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    registerCalendarExportChannel()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerCalendarExportChannel()
  }

  private func registerCalendarExportChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "ato/calendar_export",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "saveCalendarExport":
        self?.saveCalendarExport(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func saveCalendarExport(call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      let events = try parseEvents(arguments: call.arguments)
      let args = call.arguments as? [String: Any]
      let calendarId = args?["calendarId"] as? String

      let isWriteOnly: Bool
      let requestAccess: (@escaping (Bool, Error?) -> Void) -> Void
      if #available(iOS 17.0, *) {
        isWriteOnly = true
        requestAccess = { [weak self] completion in
          self?.eventStore.requestWriteOnlyAccessToEvents(completion: completion)
        }
      } else {
        isWriteOnly = false
        requestAccess = { [weak self] completion in
          self?.eventStore.requestAccess(to: .event, completion: completion)
        }
      }

      requestAccess { [weak self] granted, error in
        guard let self = self else {
          DispatchQueue.main.async {
            result(FlutterError(code: "app_unavailable", message: "Calendar export is unavailable.", details: nil))
          }
          return
        }

        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "permission_error", message: error.localizedDescription, details: nil))
            return
          }

          guard granted else {
            result(FlutterError(code: "permission_denied", message: "Calendar access was denied.", details: nil))
            return
          }

          do {
            let (savedCount, calendarName) = try self.save(events: events, calendarId: calendarId, writeOnly: isWriteOnly)
            result([
              "savedCount": savedCount,
              "calendarName": calendarName ?? NSNull(),
            ])
          } catch let saveError as NSError where saveError.domain == "Medo.CalendarExport" && saveError.code == 1 {
            result(FlutterError(code: "no_writable_calendar", message: saveError.localizedDescription, details: nil))
          } catch {
            result(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    } catch {
      result(FlutterError(code: "invalid_payload", message: error.localizedDescription, details: nil))
    }
  }

  private func save(events: [CalendarExportEventPayload], calendarId: String?, writeOnly: Bool) throws -> (Int, String?) {
    let calendar: EKCalendar
    if let calendarId = calendarId,
       let found = eventStore.calendars(for: .event).first(where: { $0.calendarIdentifier == calendarId }),
       found.allowsContentModifications {
      calendar = found
    } else if let defaultCalendar = eventStore.defaultCalendarForNewEvents,
              defaultCalendar.allowsContentModifications {
      calendar = defaultCalendar
    } else if let firstWritable = eventStore.calendars(for: .event).first(where: { $0.allowsContentModifications }) {
      calendar = firstWritable
    } else {
      throw NSError(
        domain: "Medo.CalendarExport",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "No writable calendar is available."]
      )
    }

    do {
      for eventPayload in events {
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = eventPayload.title
        event.startDate = Date(timeIntervalSince1970: TimeInterval(eventPayload.startAtMillis) / 1000.0)
        event.endDate = Date(timeIntervalSince1970: TimeInterval(eventPayload.endAtMillis) / 1000.0)
        event.timeZone = .current
        try eventStore.save(event, span: .thisEvent, commit: false)
      }

      try eventStore.commit()
      return (events.count, writeOnly ? nil : calendar.title)
    } catch {
      eventStore.reset()
      throw error
    }
  }

  private func parseEvents(arguments: Any?) throws -> [CalendarExportEventPayload] {
    guard let root = arguments as? [String: Any],
          let rawEvents = root["events"] as? [[String: Any]],
          !rawEvents.isEmpty else {
      throw NSError(
        domain: "Medo.CalendarExport",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Missing calendar export events."]
      )
    }

    return try rawEvents.enumerated().map { index, event in
      guard let title = event["title"] as? String,
            !title.isEmpty else {
        throw NSError(
          domain: "Medo.CalendarExport",
          code: 3,
          userInfo: [NSLocalizedDescriptionKey: "Missing title for event at index \(index)."]
        )
      }

      guard let startAtMillis = Self.numberValue(event["startAtMillis"]),
            let endAtMillis = Self.numberValue(event["endAtMillis"]) else {
        throw NSError(
          domain: "Medo.CalendarExport",
          code: 4,
          userInfo: [NSLocalizedDescriptionKey: "Missing time range for event at index \(index)."]
        )
      }

      return CalendarExportEventPayload(
        id: (event["id"] as? String) ?? "",
        title: title,
        startAtMillis: startAtMillis,
        endAtMillis: endAtMillis
      )
    }
  }

  private static func numberValue(_ value: Any?) -> Int64? {
    switch value {
    case let number as Int64:
      return number
    case let number as Int:
      return Int64(number)
    case let number as NSNumber:
      return number.int64Value
    default:
      return nil
    }
  }

  private struct CalendarExportEventPayload {
    let id: String
    let title: String
    let startAtMillis: Int64
    let endAtMillis: Int64
  }
}
