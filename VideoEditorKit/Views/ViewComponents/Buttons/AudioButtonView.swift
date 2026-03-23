//
//  AudioButtonView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import AVKit

struct AudioButtonView: View {
    var video: Video
    @Binding var isSelectedTrack: Bool
    var recorderManager: AudioRecorderManager
    @State private var audioSimples = [Audio.AudioSimple]()
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                    }

                if let audio = video.audio{
                    audioButton(proxy, audio)
                }else if recorderManager.recordState == .recording{
                    recordRectangle(proxy)
                }
            }
            .clipShape(.rect(cornerRadius: 14))
        }
        .frame(height: 44)
    }
}

extension AudioButtonView{
    
    

    
    private func recordRectangle(_ proxy: GeometryProxy) -> some View{
        let width = getWidthFromDuration(allWight: proxy.size.width, currentDuration: recorderManager.currentRecordTime, totalDuration: video.totalDuration)
        return RoundedRectangle(cornerRadius: 8)
            .fill(IOS26Theme.accent.opacity(0.65))
            .frame(width: width)
            .hLeading()
            .animation(.easeIn, value: recorderManager.currentRecordTime)
    }
    
    private func audioButton(_ proxy: GeometryProxy, _ audio: Audio) -> some View{
        let width = getWidthFromDuration(allWight: proxy.size.width, currentDuration: audio.duration, totalDuration: video.totalDuration)
        return RoundedRectangle(cornerRadius: 8)
            .fill(IOS26Theme.accent.opacity(isSelectedTrack ? 0.48 : 0.70))
            .overlay {
                ZStack{
                    if !isSelectedTrack{
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white, lineWidth: 2)
                    }
                    HStack(spacing: 1){
                        ForEach(audioSimples) { simple in
                            Capsule()
                                .fill(.white)
                                .frame(width: 2, height: simple.size)
                        }
                    }
                }
            }
            .frame(width: width)
            .hLeading()
            .onAppear{
                audioSimples = audio.createSimples(width)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isSelectedTrack.toggle()
                }
            }
    }

    private func getWidthFromDuration(allWight: CGFloat, currentDuration: Double, totalDuration: Double) -> CGFloat{
        return (allWight / totalDuration) * currentDuration
    }
}

struct AudioButtonView_Previews: PreviewProvider {
    static var previews: some View {
        AudioButtonView(video: Video.mock, isSelectedTrack: .constant(false), recorderManager: AudioRecorderManager())
            .frame(height: 40)
            .padding()
    }
}
