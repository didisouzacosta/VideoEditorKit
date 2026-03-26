//
//  SheetView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct SheetView<Content: View>: View {

    // MARK: - Bindings

    @Binding var isPresented: Bool

    // MARK: - States

    @State private var showSheet: Bool = false
    @State private var slideGesture: CGSize

    // MARK: - Public Properties

    var bgOpacity: CGFloat
    let content: Content

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    closeSheet()
                }
                .onAppear {
                    withAnimation(.spring().delay(0.1)) {
                        showSheet = true
                    }
                }
            if showSheet {
                sheetLayer
                    .transition(.move(edge: .bottom))
                    .onDisappear {
                        withAnimation(.easeIn(duration: 0.1)) {
                            isPresented = false
                        }
                    }
            }
        }
    }

    // MARK: - Initializer

    init(isPresented: Binding<Bool>, bgOpacity: CGFloat = 0.01, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.bgOpacity = bgOpacity
        self._slideGesture = State(initialValue: CGSize.zero)
        self.content = content()

    }

}

extension SheetView {

    // MARK: - Private Properties

    private var sheetLayer: some View {
        VStack(spacing: 0) {
            HStack {
                Capsule()
                    .fill(Theme.outline)
                    .frame(width: 56, height: 5)
                Spacer()
                Button {
                    closeSheet()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(Theme.primary)
                        .circleControl()
                }
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)
            content
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .card(cornerRadius: 32, prominent: true, tint: Theme.secondary)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .offset(y: max(slideGesture.height, 0))
        .gesture(
            DragGesture().onChanged { value in
                self.slideGesture = value.translation
            }
            .onEnded { value in
                if self.slideGesture.height > 90 {
                    closeSheet()
                }
                self.slideGesture = .zero
            })
    }

    // MARK: - Private Methods

    private func closeSheet() {
        withAnimation(.easeIn(duration: 0.2)) {
            showSheet = false
        }
    }

}

struct CustomCorners: Shape {

    // MARK: - Public Properties

    var corners: UIRectCorner
    var radius: CGFloat

    // MARK: - Public Methods

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect, byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }

}
