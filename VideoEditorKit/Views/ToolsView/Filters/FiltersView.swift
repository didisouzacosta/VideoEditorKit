//
//  FiltersView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct FiltersView: View {

    // MARK: - Private Properties

    private let viewModel: FiltersViewModel
    private let onChangeFilter: (String?) -> Void

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .center, spacing: 10) {
                ForEach(viewModel.images) { filterImage in
                    Button {
                        viewModel.selectFilter(filterImage.filter.name)
                    } label: {
                        imageView(filterImage.image, isSelected: viewModel.isSelected(filterImage.filter.name))
                    }
                    .buttonStyle(.plain)
                }
            }
            .safeAreaPadding()
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
        .onChange(of: viewModel.selectedFilterName) { _, newValue in
            onChangeFilter(newValue)
        }
    }

    // MARK: - Initializer

    init(
        _ selectedFilterName: String? = nil,
        viewModel: FiltersViewModel,
        onChangeFilter: @escaping (String?) -> Void
    ) {
        viewModel.selectFilter(selectedFilterName)

        self.viewModel = viewModel
        self.onChangeFilter = onChangeFilter
    }

}

fileprivate extension FiltersView {

    func imageView(_ uiImage: UIImage, isSelected: Bool) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .clipped()
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Theme.primary : Theme.outline,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .padding(4)
            .card(
                cornerRadius: 22, prominent: isSelected,
                tint: isSelected ? Theme.accent : Theme.secondary)
    }

}

@MainActor
fileprivate func makeFiltersPreviewViewModel() -> FiltersViewModel {
    let viewModel = FiltersViewModel()
    if let image = UIImage(named: "simpleImage") {
        viewModel.loadFilters(for: image)
    }
    return viewModel
}

#Preview {
    FiltersView(nil, viewModel: makeFiltersPreviewViewModel(), onChangeFilter: { _ in })
}
