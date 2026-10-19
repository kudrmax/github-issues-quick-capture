/// Converts text typed in the Russian ЙЦУКЕН layout into what the same keys
/// produce in QWERTY, so "фтлш" still finds "anki".
public struct KeyboardLayoutConverter: Sendable {
    private static let russian = Array("ёйцукенгшщзхъфывапролджэячсмитьбю")
    private static let qwerty = Array("`qwertyuiop[]asdfghjkl;'zxcvbnm,.")
    private static let mapping = Dictionary(uniqueKeysWithValues: zip(russian, qwerty))

    public init() {}

    public func qwertyEquivalent(of text: String) -> String? {
        let lowercased = text.lowercased()
        guard lowercased.contains(where: { Self.mapping[$0] != nil }) else { return nil }
        return String(lowercased.map { Self.mapping[$0] ?? $0 })
    }
}
