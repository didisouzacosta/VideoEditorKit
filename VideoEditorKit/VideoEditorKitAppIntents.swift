import AppIntents

// This marker adds the explicit AppIntents dependency Xcode expects
// when it runs metadata extraction for the app target.
struct VideoEditorKitAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        []
    }
}
