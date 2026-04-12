import Foundation
import Speech

struct AppleSpeechAvailabilityResolver {

    struct Resolution: Equatable, Sendable {

        // MARK: - Public Properties

        let locale: Locale

        // MARK: - Initializer

        init(_ locale: Locale) {
            self.locale = locale
        }

    }

    struct Dependencies: Sendable {

        // MARK: - Public Properties

        let supportedLocales: @Sendable () async -> [Locale]
        let equivalentLocale: @Sendable (Locale) async -> Locale?

        // MARK: - Initializer

        init(
            supportedLocales: @escaping @Sendable () async -> [Locale] = {
                await SpeechTranscriber.supportedLocales
            },
            equivalentLocale: @escaping @Sendable (Locale) async -> Locale? = { locale in
                await SpeechTranscriber.supportedLocale(equivalentTo: locale)
            }
        ) {
            self.supportedLocales = supportedLocales
            self.equivalentLocale = equivalentLocale
        }

    }

    // MARK: - Private Properties

    private let dependencies: Dependencies

    // MARK: - Initializer

    init(_ dependencies: Dependencies = .init()) {
        self.dependencies = dependencies
    }

    // MARK: - Public Methods

    func resolve(
        preferredLocale: String?
    ) async -> Result<Resolution, TranscriptError> {
        let localeRequest = localeRequest(from: preferredLocale)
        let supportedLocales = await dependencies.supportedLocales()

        guard !supportedLocales.isEmpty else {
            return .failure(
                .unavailable(message: "Apple Speech transcription is not available on this device.")
            )
        }

        if let exactLocale = exactSupportedLocale(
            matching: localeRequest.locale,
            in: supportedLocales
        ) {
            return .success(Resolution(exactLocale))
        }

        if let equivalentLocale = await dependencies.equivalentLocale(localeRequest.locale) {
            return .success(Resolution(equivalentLocale))
        }

        guard localeRequest.isExplicit else {
            return .success(Resolution(supportedLocales[0]))
        }

        return .failure(
            .unavailable(
                message: "Apple Speech transcription is not available for \(localeRequest.displayIdentifier)."
            )
        )
    }

    func availabilityError(
        preferredLocale: String?
    ) async -> TranscriptError? {
        switch await resolve(preferredLocale: preferredLocale) {
        case .success:
            nil
        case .failure(let error):
            error
        }
    }

    // MARK: - Private Methods

    private func localeRequest(from preferredLocale: String?) -> LocaleRequest {
        let displayIdentifier = preferredLocale?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let displayIdentifier, !displayIdentifier.isEmpty else {
            return LocaleRequest(
                locale: .current,
                displayIdentifier: Locale.current.identifier,
                isExplicit: false
            )
        }

        return LocaleRequest(
            locale: Locale(identifier: displayIdentifier),
            displayIdentifier: displayIdentifier,
            isExplicit: true
        )
    }

    private func exactSupportedLocale(
        matching locale: Locale,
        in supportedLocales: [Locale]
    ) -> Locale? {
        supportedLocales.first { supportedLocale in
            normalizedIdentifier(supportedLocale.identifier) == normalizedIdentifier(locale.identifier)
        }
    }

    private func normalizedIdentifier(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
    }

}

private struct LocaleRequest {

    // MARK: - Public Properties

    let locale: Locale
    let displayIdentifier: String
    let isExplicit: Bool

}
