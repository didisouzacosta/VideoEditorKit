import AVFoundation
import Foundation
import Testing

@testable import VideoEditorKit

@Suite("AVFoundationMediaExtractorTests")
struct AVFoundationMediaExtractorTests {

    // MARK: - Public Methods

    @Test
    func extractorReturnsTheOriginalAudioURLForAudioInputs() async throws {
        let workingDirectory = try TranscriptionKitTestMediaFactory.makeWorkingDirectory()
        let audioURL = try TranscriptionKitTestMediaFactory.makeAudioFile(
            in: workingDirectory
        )
        let extractor = AVFoundationMediaExtractor(
            rootDirectoryURL: workingDirectory
        )

        let extractedAudio = try await extractor.extractAudioIfNeeded(
            from: .audioFile(audioURL)
        )

        #expect(extractedAudio.audioURL == audioURL)
        #expect(extractedAudio.wasExtractedFromVideo == false)
        #expect(extractedAudio.duration != nil)
    }

    @Test
    func extractorExportsAudioWhenTheInputIsAVideo() async throws {
        let workingDirectory = try TranscriptionKitTestMediaFactory.makeWorkingDirectory()
        let videoURL = try await TranscriptionKitTestMediaFactory.makeVideoFileWithAudio(
            in: workingDirectory
        )
        let extractor = AVFoundationMediaExtractor(
            rootDirectoryURL: workingDirectory
        )

        let extractedAudio = try await extractor.extractAudioIfNeeded(
            from: .videoFile(videoURL)
        )
        let asset = AVURLAsset(
            url: extractedAudio.audioURL
        )

        #expect(extractedAudio.audioURL != videoURL)
        #expect(extractedAudio.audioURL.pathExtension == "m4a")
        #expect(extractedAudio.wasExtractedFromVideo)
        #expect(FileManager.default.fileExists(atPath: extractedAudio.audioURL.path()))
        #expect(!(try await asset.loadTracks(withMediaType: .audio)).isEmpty)
    }

    @Test
    func extractorRejectsMissingLocalFiles() async {
        let extractor = AVFoundationMediaExtractor()
        let missingURL = URL(fileURLWithPath: "/tmp/transcription-kit-missing-\(UUID().uuidString).mov")

        await #expect(throws: TranscriptionError.self) {
            try await extractor.extractAudioIfNeeded(
                from: .videoFile(missingURL)
            )
        }
    }

}
