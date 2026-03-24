//
//  LineSlider.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct LineSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    let onEditingChanged: () -> Void
    var body: some View {

        GeometryReader { proxy in
            CustomSlider(
                value: $value,
                in: range,
                onChanged: {

                    onEditingChanged()

                },
                track: {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                },
                thumb: {
                    Capsule()
                        .foregroundStyle(Theme.accent)
                }, thumbSize: CGSize(width: 10, height: proxy.size.height))
        }
    }
}

struct TimeLineSlider_Previews: PreviewProvider {
    static var previews: some View {
        LineSlider(value: .constant(100), range: 14...100) {}
            .frame(width: 250, height: 60)
            .background(Color(uiColor: .secondarySystemBackground))
    }
}
