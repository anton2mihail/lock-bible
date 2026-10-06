import SwiftUI
import UIKit

enum FeatureTimePickerStyle: Equatable {
    case spinner
    case compact
}

struct FeatureTimePicker: UIViewRepresentable {
    @Binding var date: Date
    let style: FeatureTimePickerStyle
    var minuteInterval = 1
    var accessibilityLabel: String

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = style == .spinner ? .wheels : .compact
        picker.minuteInterval = minuteInterval
        picker.accessibilityLabel = accessibilityLabel
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.parent = self
        picker.minuteInterval = minuteInterval
        picker.isEnabled = context.environment.isEnabled
        picker.accessibilityLabel = accessibilityLabel
        if abs(picker.date.timeIntervalSince(date)) > 1 {
            picker.setDate(date, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        fileprivate var parent: FeatureTimePicker
        init(_ parent: FeatureTimePicker) { self.parent = parent }
        @objc func changed(_ picker: UIDatePicker) { parent.date = picker.date }
    }
}

func featureTime(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.timeZone = .current
    components.year = 2024
    components.month = 1
    components.day = 1
    components.hour = hour
    components.minute = minute
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
}

func featureTimeParts(_ date: Date) -> (hour: Int, minute: Int) {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (components.hour ?? 8, components.minute ?? 0)
}
