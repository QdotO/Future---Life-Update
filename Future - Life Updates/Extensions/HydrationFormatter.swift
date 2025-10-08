import Foundation

enum HydrationFormatter {
    private static let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.unitOptions = [.providedUnit]
        formatter.unitStyle = .medium
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()

    static func ouncesString(_ value: Double) -> String {
        let measurement = Measurement(value: value, unit: UnitVolume.fluidOunces)
        return measurementFormatter.string(from: measurement)
    }

    static func signedDelta(_ delta: Double) -> String {
        guard delta != 0 else { return "±0" }
        let sign = delta >= 0 ? "+" : "−"
        return "\(sign)\(ouncesString(abs(delta)))"
    }
}
