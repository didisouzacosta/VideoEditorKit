//
//  CropperRatio.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import CoreGraphics
import Foundation

struct CropperRatio {
    let width: CGFloat
    let height: CGFloat

    static var square: Self {
        .init(width: 1, height: 1)
    }

    static var landscape3x2: Self {
        .init(width: 3, height: 2)
    }

    static var landscape4x3: Self {
        .init(width: 4, height: 3)
    }

    static var widescreen16x9: Self {
        .init(width: 16, height: 9)
    }

    static var cinematic18x6: Self {
        .init(width: 18, height: 6)
    }
}
