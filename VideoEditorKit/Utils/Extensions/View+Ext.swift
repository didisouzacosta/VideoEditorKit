//
//  View+Ext.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

extension View {
    func vBottom() -> some View {
        frame(maxHeight: .infinity, alignment: .bottom)
    }

    func hCenter() -> some View {
        frame(maxWidth: .infinity, alignment: .center)
    }

    func hLeading() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }

    func allFrame() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
