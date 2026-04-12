import Foundation
import Testing

@testable import VideoEditorKit

@Suite("AppleSpeechAvailabilityResolverTests")
struct AppleSpeechAvailabilityResolverTests {

    // MARK: - Public Methods

    @Test
    func resolveUsesPreferredLocaleWhenItIsSupported() async throws {
        let resolver = AppleSpeechAvailabilityResolver(
            .init(
                supportedLocales: {
                    [Locale(identifier: "pt_BR")]
                },
                equivalentLocale: { _ in
                    nil
                }
            )
        )

        let resolution = try await requireSuccess(
            resolver.resolve(preferredLocale: "pt-BR")
        )

        #expect(resolution.locale.identifier == "pt_BR")
        #expect(await resolver.availabilityError(preferredLocale: "pt-BR") == nil)
    }

    @Test
    func resolveUsesEquivalentLocaleWhenPreferredLocaleIsNotAnExactMatch() async throws {
        let resolver = AppleSpeechAvailabilityResolver(
            .init(
                supportedLocales: {
                    [Locale(identifier: "en_US")]
                },
                equivalentLocale: { locale in
                    locale.identifier == "en" ? Locale(identifier: "en_US") : nil
                }
            )
        )

        let resolution = try await requireSuccess(
            resolver.resolve(preferredLocale: "en")
        )

        #expect(resolution.locale.identifier == "en_US")
        #expect(await resolver.availabilityError(preferredLocale: "en") == nil)
    }

    @Test
    func resolveFallsBackToFirstSupportedLocaleWhenNoPreferredLocaleIsProvided() async throws {
        let resolver = AppleSpeechAvailabilityResolver(
            .init(
                supportedLocales: {
                    [
                        Locale(identifier: "fr_FR"),
                        Locale(identifier: "en_US"),
                    ]
                },
                equivalentLocale: { _ in
                    nil
                }
            )
        )

        let resolution = try await requireSuccess(
            resolver.resolve(preferredLocale: nil)
        )

        #expect(resolution.locale.identifier == "fr_FR")
    }

    @Test
    func resolveReturnsUnavailableWhenPreferredLocaleIsUnsupported() async throws {
        let resolver = AppleSpeechAvailabilityResolver(
            .init(
                supportedLocales: {
                    [Locale(identifier: "fr_FR")]
                },
                equivalentLocale: { _ in
                    nil
                }
            )
        )

        let error = try await requireFailure(
            resolver.resolve(preferredLocale: "pt-BR")
        )

        #expect(
            error
                == .unavailable(
                    message: "Apple Speech transcription is not available for pt-BR."
                )
        )
        #expect(await resolver.availabilityError(preferredLocale: "pt-BR") == error)
    }

    @Test
    func resolveReturnsUnavailableWhenTheDeviceReportsNoSupportedLocales() async throws {
        let resolver = AppleSpeechAvailabilityResolver(
            .init(
                supportedLocales: {
                    []
                },
                equivalentLocale: { _ in
                    nil
                }
            )
        )

        let error = try await requireFailure(
            resolver.resolve(preferredLocale: nil)
        )

        #expect(
            error
                == .unavailable(
                    message: "Apple Speech transcription is not available on this device."
                )
        )
    }

    // MARK: - Private Methods

    private func requireSuccess<Value>(
        _ result: Result<Value, TranscriptError>
    ) throws -> Value {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            Issue.record("Expected success, received \(error).")
            throw error
        }
    }

    private func requireFailure<Value>(
        _ result: Result<Value, TranscriptError>
    ) throws -> TranscriptError {
        switch result {
        case .success(let value):
            Issue.record("Expected failure, received \(value).")
            throw TranscriptError.emptyResult
        case .failure(let error):
            return error
        }
    }

}
