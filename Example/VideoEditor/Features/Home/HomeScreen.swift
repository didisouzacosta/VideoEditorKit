import PhotosUI
import SwiftUI

struct HomeScreen: View {

    // MARK: - Bindings

    @Binding private var selectedItem: PhotosPickerItem?

    // MARK: - Public Properties

    let projects: [EditedVideoProject]
    let usesCompactGridLayout: Bool
    let onOpenProject: (EditedVideoProject) -> Void
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
        onDeleteProject: @escaping (EditedVideoProject) -> Void
    ) {
        _selectedItem = selectedItem

        self.projects = projects
        self.usesCompactGridLayout = usesCompactGridLayout
        self.onOpenProject = onOpenProject
        self.onDeleteProject = onDeleteProject
    }

}

private struct HomeHeroSection: View {

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit, export, and revisit your clips.")
                .font(.largeTitle.bold())

            Text(
                "Choose a video from Photos, export it, and keep both the original media and the rendered output saved for future edits."
            )
            .font(.title3.weight(.semibold))

            Text(
                "The example app stays intentionally small: import a clip, edit it, and reopen the saved draft or exported video later."
            )
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
                    Text("Choose a Video")
                        .font(.headline)

                    Text("Import a clip from Photos and open it directly in the editor.")
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
    let onDeleteProject: (EditedVideoProject) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edited Videos")
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
                            onOpen: {
                                onOpenProject(project)
                            },
                            onEdit: {
                                onOpenProject(project)
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
            Text("No saved videos yet")
                .font(.headline)

            Text(
                "Choose a video, make your edits, and it will appear here with the latest saved configuration even before export."
            )
            .font(.subheadline)
            .foregroundStyle(Theme.secondary)
        }
        .padding(24)
        .card()
    }

}
