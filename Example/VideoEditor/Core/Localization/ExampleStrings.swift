import Foundation
import VideoEditorKit

enum ExampleStrings {

    // MARK: - Public Properties

    static var ok: String {
        localized("common.ok", defaultValue: "OK")
    }

    static var close: String {
        localized("common.close", defaultValue: "Close")
    }

    static var editorTitle: String {
        localized("example.editor.title", defaultValue: "Editor")
    }

    static var persistenceErrorTitle: String {
        localized("example.error.persistence.title", defaultValue: "Unable to Save Project")
    }

    static var missingProjectOriginalVideo: String {
        localized(
            "example.error.persistence.project-missing-original-video",
            defaultValue: "The original video for this project is no longer available."
        )
    }

    static var missingSessionOriginalVideo: String {
        localized(
            "example.error.persistence.session-missing-original-video",
            defaultValue: "The original video for this editing session could not be resolved."
        )
    }

    static var missingStoredOriginalVideo: String {
        localized(
            "example.error.persistence.stored-original-video-missing",
            defaultValue: "The original video could not be found for this project."
        )
    }

    static var missingSavedVideo: String {
        localized(
            "example.error.persistence.saved-video-missing",
            defaultValue: "The saved video for this project is no longer available."
        )
    }

    static var unableToLoadSelectedVideo: String {
        localized(
            "example.import.error.unable-to-load-selected-video",
            defaultValue: "The selected video could not be loaded."
        )
    }

    static var projectEdit: String {
        localized("example.project.action.edit", defaultValue: "Edit")
    }

    static var projectPreview: String {
        localized("example.project.action.preview", defaultValue: "Preview")
    }

    static var projectOpen: String {
        localized("example.project.action.open", defaultValue: "Open")
    }

    static var projectShare: String {
        localized("example.project.action.share", defaultValue: "Share")
    }

    static var projectDelete: String {
        localized("example.project.action.delete", defaultValue: "Delete")
    }

    static var homeHeroTitle: String {
        localized(
            "example.home.hero.title",
            defaultValue: "Edit, export, and revisit your clips."
        )
    }

    static var homeHeroMessage: String {
        localized(
            "example.home.hero.message",
            defaultValue:
                "Choose a video from Photos, export it, and keep both the original media and the rendered output saved for future edits."
        )
    }

    static var homeHeroFootnote: String {
        localized(
            "example.home.hero.footnote",
            defaultValue:
                "The example app stays intentionally small: import a clip, edit it, and reopen the saved video later."
        )
    }

    static var homeImportTitle: String {
        localized("example.home.import.title", defaultValue: "Choose a Video")
    }

    static var homeImportMessage: String {
        localized(
            "example.home.import.message",
            defaultValue: "Import a clip from Photos and open it directly in the editor."
        )
    }

    static var homeProjectsTitle: String {
        localized("example.home.projects.title", defaultValue: "Edited Videos")
    }

    static var homeEmptyTitle: String {
        localized("example.home.empty.title", defaultValue: "No saved videos yet")
    }

    static var homeEmptyMessage: String {
        localized(
            "example.home.empty.message",
            defaultValue:
                "Choose a video, make your edits, and it will appear here with the latest saved configuration even before export."
        )
    }

    static var hostDurationLimitEmptyDetail: String {
        localized(
            "example.host-video-duration.detail.empty",
            defaultValue:
                "Leave the field empty to keep the editor without a trim limit. Example: enter 300 to cap trim and export at 5 minutes."
        )
    }

    // MARK: - Public Methods

    static func hostDurationLimitDetail(
        maximumDurationInSeconds: Int
    ) -> String {
        String.localizedStringWithFormat(
            hostDurationLimitMaximumFormat,
            maximumDurationInSeconds
        )
    }

    // MARK: - Private Properties

    private static var hostDurationLimitMaximumFormat: String {
        localized(
            "example.host-video-duration.detail.maximum-format",
            defaultValue:
                "The host is limiting trim and export to %lld seconds. The user can still move the selected window anywhere in the source video, but the trim selection itself cannot exceed that duration."
        )
    }

    // MARK: - Private Methods

    private static func localized(
        _ key: StaticString,
        defaultValue: String.LocalizationValue
    ) -> String {
        VideoEditorLocalization.string(
            key,
            defaultValue: defaultValue
        )
    }

}
