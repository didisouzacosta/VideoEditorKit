//
//  UIImage+Ext.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import SwiftUI

extension UIImage {

    /// Resize image
    /// Return new UIImage with needed size and scale
    func resize(to size: CGSize, scale: CGFloat = 1.0) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }

}
