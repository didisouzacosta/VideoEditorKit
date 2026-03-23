//
//  SheetView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct SheetView<Content: View>: View {
    @Binding var isPresented: Bool
    @State private var showSheet: Bool = false
    @State private var slideGesture: CGSize
    var bgOpacity: CGFloat
    let content: Content
    init(isPresented: Binding<Bool>, bgOpacity: CGFloat = 0.01, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.bgOpacity = bgOpacity
        self._slideGesture = State(initialValue: CGSize.zero)
        self.content = content()

    }
    var body: some View {
        ZStack(alignment: .bottom) {
            IOS26Theme.scrim.opacity(max(bgOpacity * 2, 0.15))
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
}

extension SheetView {
    private var sheetLayer: some View {
        VStack(spacing: 0) {
            HStack {
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(width: 56, height: 5)
                Spacer()
                Button {
                    closeSheet()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .ios26CircleControl()
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
        .ios26Card(cornerRadius: 32, prominent: true, tint: IOS26Theme.accentSecondary)
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

    private func closeSheet() {
        withAnimation(.easeIn(duration: 0.2)) {
            showSheet = false
        }
    }
}

struct CustomCorners: Shape {

    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect, byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
