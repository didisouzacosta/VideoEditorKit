import PhotosUI
import SwiftUI

struct HomeScreen: View {

    // MARK: - Bindings

    @Binding private var selectedItem: PhotosPickerItem?

    // MARK: - Public Properties

    let projects: [EditedVideoProject]
    let usesCompactGridLayout: Bool
    let onOpenProject: (EditedVideoProject) -> Void
    let onShareSavedVideo: (EditedVideoProject) -> Void
    let onDeleteProject: (EditedVideoProject) -> Void

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.rootBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HomeHeroSection()
                    ImportVideoCard(selectedItem: $selectedItem)
                    ProjectsGridSection(
                        projects: projects,
                        columns: gridColumns,
                        spacing: gridSpacing,
                        onOpenProject: onOpenProject,
                        onShareSavedVideo: onShareSavedVideo,
                        onDeleteProject: onDeleteProject
                    )
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(16)
        }
    }

    // MARK: - Private Properties

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: gridSpacing),
            count: usesCompactGridLayout ? 3 : 4
        )
    }

    private var gridSpacing: CGFloat {
        12
    }

    // MARK: - Initializer

    init(
        selectedItem: Binding<PhotosPickerItem?>,
        projects: [EditedVideoProject],
        usesCompactGridLayout: Bool,
        onOpenProject: @escaping (EditedVideoProject) -> Void,
        onShareSavedVideo: @escaping (EditedVideoProject) -> Void,
        onDeleteProject: @escaping (EditedVideoProject) -> Void
    ) {
        _selectedItem = selectedItem

        self.projects = projects
        self.usesCompactGridLayout = usesCompactGridLayout
        self.onOpenProject = onOpenProject
        self.onShareSavedVideo = onShareSavedVideo
        self.onDeleteProject = onDeleteProject
    }

}

private struct HomeHeroSection: View {

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(ExampleStrings.homeHeroTitle)
                .font(.largeTitle.bold())

            Text(ExampleStrings.homeHeroMessage)
                .font(.title3.weight(.semibold))

            Text(ExampleStrings.homeHeroFootnote)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
        }
        .padding(32)
        .card()
    }

}

private struct ImportVideoCard: View {

    // MARK: - Bindings

    @Binding private var selectedItem: PhotosPickerItem?

    // MARK: - Body

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .videos) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .circleControl(prominent: true, tint: Theme.accent)

                VStack(alignment: .leading, spacing: 6) {
                    Text(ExampleStrings.homeImportTitle)
                        .font(.headline)

                    Text(ExampleStrings.homeImportMessage)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(32)
            .card(prominent: true, tint: Theme.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Initializer

    init(selectedItem: Binding<PhotosPickerItem?>) {
        _selectedItem = selectedItem
    }

}

private struct ProjectsGridSection: View {

    // MARK: - Public Properties

    let projects: [EditedVideoProject]
    let columns: [GridItem]
    let spacing: CGFloat
    let onOpenProject: (EditedVideoProject) -> Void
    let onShareSavedVideo: (EditedVideoProject) -> Void
    let onDeleteProject: (EditedVideoProject) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(ExampleStrings.homeProjectsTitle)
                .font(.headline)
                .padding(.horizontal)

            if projects.isEmpty {
                EmptyProjectsCard()
            } else {
                LazyVGrid(
                    columns: columns,
                    alignment: .leading,
                    spacing: spacing
                ) {
                    ForEach(projects) { project in
                        EditedVideoProjectCard(
                            project: project,
                            onOpenProject: {
                                onOpenProject(project)
                            },
                            onShareSavedVideo: {
                                onShareSavedVideo(project)
                            },
                            onDelete: {
                                onDeleteProject(project)
                            }
                        )
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

}

private struct EmptyProjectsCard: View {

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ExampleStrings.homeEmptyTitle)
                .font(.headline)

            Text(ExampleStrings.homeEmptyMessage)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
        }
        .padding(24)
        .card()
    }

}
