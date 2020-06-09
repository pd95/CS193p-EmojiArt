//
//  EmojiArt.swift
//  EmojiArt
//
//  Created by Philipp on 09.06.20.
//  Copyright © 2020 Philipp. All rights reserved.
//

import Foundation

struct EmojiArt {
    var backgroundURL: URL?
    var emojis = [Emoji]()

    struct Emoji: Identifiable {
        let text: String
        var x: Int  // offset from center
        var y: Int  // offset from center
        var size: Int
        let id: Int

        fileprivate init(_ text: String, x: Int, y: Int, size: Int, id: Int) {
            self.text = text
            self.x = x
            self.y = y
            self.size = size
            self.id = id
        }
    }

    private var uniqueEmojiId = 0

    mutating func addEmoji(_ text: String, x: Int, y: Int, size: Int) {
        uniqueEmojiId += 1
        emojis.append(Emoji(text, x: x, y: y, size: size, id: uniqueEmojiId))
    }
}
