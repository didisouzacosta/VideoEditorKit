//
//  FiltersView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct FiltersView: View {

    // MARK: - States

    @State private var selectedFilterName: String? = nil

    // MARK: - Private Properties

    private let viewModel: FiltersViewModel
    private let onChangeFilter: (String?) -> Void

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .center, spacing: 10) {
                resetButton
                ForEach(viewModel.images) { filterImage in
                    Button {
                        selectedFilterName = filterImage.filter.name
                    } label: {
                        imageView(filterImage.image, isSelected: selectedFilterName == filterImage.filter.name)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 76)
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
        .onChange(of: selectedFilterName) { _, newValue in
            onChangeFilter(newValue)
        }
    }

    // MARK: - Initializer

    init(
        _ selectedFilterName: String? = nil,
        viewModel: FiltersViewModel,
        onChangeFilter: @escaping (String?) -> Void
    ) {
        _selectedFilterName = State(initialValue: selectedFilterName)

        self.viewModel = viewModel
        self.onChangeFilter = onChangeFilter
    }

}

extension FiltersView {

    // MARK: - Private Properties

    private var resetButton: some View {
        Group {
            if let image = viewModel.image {
                Button {
                    selectedFilterName = nil
                } label: {
                    imageView(image, isSelected: selectedFilterName == nil)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
            }
        }
    }

    // MARK: - Private Methods

    private func imageView(_ uiImage: UIImage, isSelected: Bool) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .clipped()
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
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

#Preview {
    FiltersView(nil, viewModel: makeFiltersPreviewViewModel(), onChangeFilter: { _ in })
        .padding()
}

@MainActor
private func makeFiltersPreviewViewModel() -> FiltersViewModel {
    let viewModel = FiltersViewModel()
    if let image = UIImage(named: "simpleImage") {
        viewModel.loadFilters(for: image)
    }
    return viewModel
}
