//
//  FiltersView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct FiltersView: View {
    @State var selectedFilterName: String? = nil
    var viewModel: FiltersViewModel
    let onChangeFilter: (String?) -> Void
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
        .onChange(of: selectedFilterName) { _, newValue in
            onChangeFilter(newValue)
        }
        .padding(.horizontal, -16)
    }
}

extension FiltersView{
    private func imageView(_ uiImage: UIImage, isSelected: Bool) -> some View{
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .clipped()
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? .white : .white.opacity(0.10), lineWidth: isSelected ? 2 : 1)
            }
            .padding(4)
            .ios26Card(cornerRadius: 22, prominent: isSelected, tint: isSelected ? IOS26Theme.accent : IOS26Theme.accentSecondary)
    }
    
    
    
    private var resetButton: some View{
        Group{
            if let image = viewModel.image{
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
}

struct FiltersView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = FiltersViewModel()
        if let image = UIImage(named: "simpleImage") {
            viewModel.loadFilters(for: image)
        }

        return FiltersView(selectedFilterName: nil, viewModel: viewModel, onChangeFilter: { _ in })
            .padding()
    }
}
