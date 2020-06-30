#  EmojiArt

A drawing app for iPads written in SwiftUI, based on the [Stanford University's course CS193p](https://cs193p.sites.stanford.edu) (Developing Applications for iOS using SwiftUI) of Spring 2020.

The project shows:

- Basic MVVM architecture:
    - **Model**: `EmojiArt`
    - **View**: `EmojiArtDocumentView`, `EmojiArtDocumentChooser`
    - **View Model**: `EmojiArtDocument`, `EmojiArtDocumentStore`

- Basic "document based architecture"
- JSON encoding/decoding
- File storage in user documents folder

- **SwiftUI features**:
    - Custom grid layout
    - Drag & Drop of text and URL for Emoji placement and background selection
    - Use of `UIPasteBoard` to provide background URL
    - Extensive gesture use for placement and emoji/image scaling
    - `UIImagePickerViewController` integration


![Screen capture](Screencapture2.gif)

## Previous versions:
![Screen capture](Screencapture.gif)
