//
//  Spinning.swift
//  EmojiArt
//
//  Created by Philipp on 15.06.20.
//  Copyright © 2020 Philipp. All rights reserved.
//

import SwiftUI

struct Spinning: ViewModifier {
    @State var isVisible = false
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isVisible ? 360 : 0))
            .animation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false))
            .onAppear() {
                self.isVisible = true
            }
    }
}

extension View {
    func spinning() -> some View {
        self.modifier(Spinning())
    }
}
