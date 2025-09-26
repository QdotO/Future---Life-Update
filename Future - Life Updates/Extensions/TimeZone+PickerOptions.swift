import Foundation

extension TimeZone {
    static let pickerOptions: [TimeZone] = {
        let identifiers = knownTimeZoneIdentifiers.sorted()
        return identifiers.compactMap { TimeZone(identifier: $0) }
    }()

    func localizedDisplayName(locale: Locale = .current) -> String {
        if let name = localizedName(for: .shortGeneric, locale: locale) {
            return name
        }
        if let name = localizedName(for: .standard, locale: locale) {
            return name
        }
        return identifier
    }
}
