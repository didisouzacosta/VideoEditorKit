//
//  FramesToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct FramesToolView: View {
    @Binding var selectedColor: Color
    @Binding var scaleValue: Double
    let colors: [Color] = [.white, .black, .blue, .brown, .cyan, .green, .orange]
    let onChange: () -> Void
    var body: some View {
        VStack(spacing: 20){
            ScrollView(.horizontal){
                HStack{
                    ForEach(colors, id: \.self) { color in
                        color
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .onTapGesture {
                                selectedColor = color
                                onChange()
                            }
                    }
                }
            }
            Slider(value: $scaleValue, in: 0...0.5) { change in
                if !change{
                    onChange()
                }
            }
        }
    }
}

struct FramesToolView_Previews: PreviewProvider {
    static var previews: some View {
        FramesToolView(selectedColor: .constant(.white), scaleValue: .constant(0.3)){}
            .frame(height: 300)
    }
}
