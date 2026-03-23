import AppIntents

// This marker adds the explicit AppIntents dependency Xcode expects
// when it runs metadata extraction for the test bundle target.
struct VideoEditorKitTestsAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        []
    }
}
