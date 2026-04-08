//
//  AppleSpeechTranscriptionService.swift
//  VideoEditorKit
//
//  Created by Codex on 08.04.2026.
//

import AVFAudio
import CoreMedia
import Foundation
import Speech

struct AppleSpeechTranscriptionService {

    enum ServiceError: Error, LocalizedError, Sendable {
        case invalidAudioSource
        case transcriptionUnavailable
        case unsupportedLocale(String?)
        case assetPreparationFailed(String)
        case unableToReadAudioFile(String)
        case emptyResult

        // MARK: - Public Properties

        var errorDescription: String? {
            switch self {
            case .invalidAudioSource:
                return "The transcription source must be a local audio file."
            case .transcriptionUnavailable:
                return "Local speech transcription is not available on this device."
            case .unsupportedLocale(let identifier):
                if let identifier, identifier.isEmpty == false {
                    return "The locale \(identifier) is not supported for local speech transcription."
                }

                return "The requested locale is not supported for local speech transcription."
            case .assetPreparationFailed(let message):
                return message
            case .unableToReadAudioFile(let message):
                return message
            case .emptyResult:
                return "The local speech transcriber returned no timed segments."
            }
        }
    }

    // MARK: - Private Properties

    private let mapper: AppleSpeechTranscriptionResultMapper

    // MARK: - Initializer

    init(
        mapper: AppleSpeechTranscriptionResultMapper = .init()
    ) {
        self.mapper = mapper
    }

    // MARK: - Public Methods

    func transcribeAudio(
        at audioURL: URL,
        preferredLocaleIdentifier: String?
    ) async throws -> VideoTranscriptionResult {
        guard audioURL.isFileURL else {
            throw ServiceError.invalidAudioSource
        }

        guard SpeechTranscriber.isAvailable else {
            throw ServiceError.transcriptionUnavailable
        }

        let locale = try await resolvedLocale(
            preferredLocaleIdentifier: preferredLocaleIdentifier
        )
        let transcriber = makeTranscriber(for: locale)

        try await prepareAssetsIfNeeded(for: transcriber)

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: audioURL)
        } catch {
            throw ServiceError.unableToReadAudioFile(error.localizedDescription)
        }

        let analyzer = try await SpeechAnalyzer(
            inputAudioFile: audioFile,
            modules: [transcriber],
            options: .init(
                priority: .userInitiated,
                modelRetention: .whileInUse
            ),
            finishAfterFile: true
        )

        do {
            var units = [AppleSpeechTranscriptionUnit]()

            for try await result in transcriber.results {
                units.append(
                    AppleSpeechTranscriptionUnit(
                        startTime: result.range.start.seconds,
                        endTime: CMTimeRangeGetEnd(result.range).seconds,
                        transcription: result.text
                    )
                )
            }

            withExtendedLifetime(analyzer) {}

            let transcriptionResult = mapper.map(units)
            guard transcriptionResult.segments.isEmpty == false else {
                throw ServiceError.emptyResult
            }

            return transcriptionResult
        } catch is CancellationError {
            await analyzer.cancelAndFinishNow()
            throw CancellationError()
        }
    }

    // MARK: - Private Methods

    func validateAvailability(
        preferredLocaleIdentifier: String?
    ) async throws {
        guard SpeechTranscriber.isAvailable else {
            throw ServiceError.transcriptionUnavailable
        }

        let locale = try await resolvedLocale(
            preferredLocaleIdentifier: preferredLocaleIdentifier
        )
        let transcriber = makeTranscriber(for: locale)
        let status = await AssetInventory.status(forModules: [transcriber])

        if status == .unsupported {
            throw ServiceError.unsupportedLocale(
                transcriber.selectedLocales.first?.identifier
            )
        }
    }

    private func resolvedLocale(
        preferredLocaleIdentifier: String?
    ) async throws -> Locale {
        let preferredLocale =
            preferredLocaleIdentifier.map(Locale.init(identifier:))
            ?? .autoupdatingCurrent

        if let supportedLocale = await SpeechTranscriber.supportedLocale(
            equivalentTo: preferredLocale
        ) {
            return supportedLocale
        }

        throw ServiceError.unsupportedLocale(preferredLocaleIdentifier)
    }

    private func makeTranscriber(
        for locale: Locale
    ) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )
    }

    private func prepareAssetsIfNeeded(
        for transcriber: SpeechTranscriber
    ) async throws {
        let modules: [any SpeechModule] = [transcriber]
        let status = await AssetInventory.status(forModules: modules)

        switch status {
        case .installed:
            return
        case .unsupported:
            throw ServiceError.unsupportedLocale(
                transcriber.selectedLocales.first?.identifier
            )
        case .supported, .downloading:
            if let installationRequest = try await AssetInventory.assetInstallationRequest(
                supporting: modules
            ) {
                try await installationRequest.downloadAndInstall()
            }

            let finalStatus = await AssetInventory.status(forModules: modules)
            guard finalStatus == .installed else {
                throw ServiceError.assetPreparationFailed(
                    "Speech assets for locale \(transcriber.selectedLocales.first?.identifier ?? "unknown") are not installed yet."
                )
            }
        @unknown default:
            throw ServiceError.assetPreparationFailed(
                "The speech asset inventory returned an unknown state."
            )
        }
    }

}
