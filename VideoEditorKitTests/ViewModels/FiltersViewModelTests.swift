import Testing

@testable import VideoEditorKit

@MainActor
@Suite("FiltersViewModelTests")
struct FiltersViewModelTests {

    // MARK: - Public Methods

    @Test
    func loadFiltersCreatesPreviewImagesAndKeepsThemSortedByFilterName() {
        let viewModel = FiltersViewModel()
        let image = TestFixtures.makeSolidImage()

        viewModel.loadFilters(for: image)

        let filterNames = viewModel.images.map { $0.filter.name }

        #expect(viewModel.hasPreviewImage)
        #expect(viewModel.image != nil)
        #expect(viewModel.images.isEmpty == false)
        #expect(filterNames == filterNames.sorted())
    }

    @Test
    func loadFiltersIfNeededIgnoresNilImages() {
        let viewModel = FiltersViewModel()

        viewModel.loadFiltersIfNeeded(from: nil)

        #expect(viewModel.images.isEmpty)
        #expect(viewModel.hasPreviewImage == false)
    }

    @Test
    func selectFilterAndSyncReflectTheCurrentVideoState() {
        let viewModel = FiltersViewModel()
        var video = Video.mock
        video.filterName = "CIPhotoEffectNoir"
        video.colorCorrection = ColorCorrection(brightness: 0.1, contrast: 0.2, saturation: 0.3)

        viewModel.selectFilter("CIPhotoEffectChrome")
        viewModel.sync(with: video)

        #expect(viewModel.isSelected("CIPhotoEffectNoir"))
        #expect(viewModel.selectedFilterName == "CIPhotoEffectNoir")
        #expect(viewModel.colorCorrection == video.colorCorrection)
    }

}
