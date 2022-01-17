//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Philipp on 09.06.20.
//  Copyright © 2020 Philipp. All rights reserved.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument

    @State private var chosenPalette: String = ""

    init(document: EmojiArtDocument) {
        self.document = document
        _chosenPalette = State(wrappedValue: document.defaultPalette)
    }

    var body: some View {
        VStack {
            HStack {
                PaletteChooser(document: document, chosenPalette: $chosenPalette)
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(chosenPalette.map { String($0)}, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: self.defaultEmojiSize))
                                .onDrag {
                                    return NSItemProvider(object: emoji as NSString)
                                }
                        }
                    }
                }
            }

            GeometryReader { geometry in
                ZStack {
                    Color.white.overlay(
                        OptionalImage(uiImage: self.document.backgroundImage)
                            .scaleEffect(self.zoomScale)
                            .offset(self.panOffset)
                    )
                    .gesture(
                        self.doubleTapToZoom(in: geometry.size)
                            .exclusively(before: self.singleTapForSelection(for: nil))
                    )

                    if self.isLoading {
                        Image(systemName: "hourglass")
                            .imageScale(.large)
                            .spinning()
                    }
                    else {
                        ForEach(self.document.emojis) { emoji in
                            Text(emoji.text)
                                .font(animatableWithSize: emoji.fontSize * self.zoomScale(for: emoji))
                                .rotationEffect(self.rotationAngle(for: emoji))
                                .position(self.position(for: emoji, in: geometry.size))
                                .gesture(self.singleTapForSelection(for: emoji))
                                .gesture(self.dragSelectionEmoji(for: emoji))
                                .shadow(color: self.isEmojiSelected(emoji) ? .blue : .clear, radius: 10 * self.zoomScale(for: emoji))
                        }
                    }
                }
                .clipped()
                .gesture(self.panGesture())
                .gesture(
                    self.zoomGesture()
                        .simultaneously(with: self.rotationGesture())
                )
                .edgesIgnoringSafeArea([.horizontal, .bottom])
                .onReceive(self.document.$backgroundImage, perform: { (image) in
                    self.zoomToFit(image, in: geometry.size)
                })
                .onDrop(of: ["public.image", "public.text"], isTargeted: nil) { providers, targetLocation in
                    var location: CGPoint
                    if #available(iOS 14, *) {
                        location = targetLocation
                    } else {
                        // SwiftUI bug (as of 13.4)? the location is supposed to be in our coordinate system
                        // however, the y coordinate appears to be in the global coordinate system
                        location = CGPoint(x: targetLocation.x, y: geometry.convert(targetLocation, from: .global).y)
                    }
                    location = CGPoint(x: location.x - geometry.size.width/2, y: location.y - geometry.size.height/2)
                    location = CGPoint(x: location.x - self.panOffset.width, y: location.y - self.panOffset.height)
                    location = CGPoint(x: location.x / self.zoomScale, y: location.y / self.zoomScale)
                    return self.drop(providers: providers, at: location)
                }
                .navigationBarItems(leading: self.pickImage, trailing: Button(action: {
                    if let url = UIPasteboard.general.url, url != self.document.backgroundURL {
                        self.confirmBackgroundPaste = true
                    } else {
                        self.explainBackgroundPaste = true
                    }
                }, label: {
                    Image(systemName: "doc.on.clipboard").imageScale(.large)
                        .alert(isPresented: self.$explainBackgroundPaste) { () -> Alert in
                            Alert(title: Text("Paste Background"),
                                  message: Text("Copy the URL of an image to the clip board and touch this button to make it the background of the document."),
                                  dismissButton: .default(Text("OK"))
                            )
                        }
                }))
            }
            .zIndex(-1)
        }
        .alert(isPresented: self.$confirmBackgroundPaste) { () -> Alert in
            Alert(title: Text("Paste Background"),
                  message: Text("Replace your background with \(UIPasteboard.general.url?.absoluteString ?? "nothing")?"),
                  primaryButton: .default(Text("OK"), action: {
                    self.document.backgroundURL = UIPasteboard.general.url
                  }),
                  secondaryButton: .cancel()
            )
        }
    }

    @State private var showImagePicker = false
    @State private var imagePickerSourceType = UIImagePickerController.SourceType.photoLibrary

    private var pickImage: some View {
        HStack {
            Image(systemName: "photo").imageScale(.large).foregroundColor(.accentColor).onTapGesture {
                self.imagePickerSourceType = .photoLibrary
                self.showImagePicker = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Image(systemName: "camera").imageScale(.large).foregroundColor(.accentColor).onTapGesture {
                    self.imagePickerSourceType = .camera
                    self.showImagePicker = true
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: self.imagePickerSourceType) { image in
                if image != nil {
                    DispatchQueue.main.async {
                        self.document.backgroundURL = image!.storeInFilesystem()
                    }
                }
                self.showImagePicker = false
            }
        }
    }

    @State private var explainBackgroundPaste = false
    @State private var confirmBackgroundPaste = false

    var isLoading: Bool {
        document.backgroundURL != nil && document.backgroundImage == nil
    }

    @GestureState private var gestureZoomScale: CGFloat = 1.0

    private var zoomScale: CGFloat {
        document.steadyStateZoomScale * (hasSelection ? 1 : gestureZoomScale)
    }

    private func zoomScale(for emoji: EmojiArt.Emoji) -> CGFloat {
        if isEmojiSelected(emoji) {
            return document.steadyStateZoomScale * gestureZoomScale
        }
        else {
            return zoomScale
        }
    }

    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale, body: { (latestGestureScale, gestureZoomScale, transaction) in
                gestureZoomScale = latestGestureScale
            })
            .onEnded { finalGestureScale in
                if self.hasSelection {
                    self.selectedEmojiIDs.forEach { (emojiId) in
                        if let emoji = self.document.emojis.first(where: {$0.id == emojiId }) {
                            self.document.scaleEmoji(emoji, by: finalGestureScale)
                        }
                    }
                }
                else {
                    self.document.steadyStateZoomScale *= finalGestureScale
                }
            }
    }

    @GestureState private var rotationAngle: Angle = .zero

    private func rotationAngle(for emoji: EmojiArt.Emoji) -> Angle {
        if isEmojiSelected(emoji) {
            return Angle(radians: emoji.rotation) + rotationAngle
        }
        else {
            return Angle(radians: emoji.rotation)
        }
    }

    private func rotationGesture() -> some Gesture {
        RotationGesture()
            .updating($rotationAngle, body: { latestGestureAngle, rotationAngle, transaction in
                rotationAngle = latestGestureAngle
            })
            .onEnded { finalGestureAngle in
                if self.hasSelection {
                    self.selectedEmojiIDs.forEach { (emojiId) in
                        if let emoji = self.document.emojis.first(where: {$0.id == emojiId }) {
                            self.document.rotateEmoji(emoji, by: finalGestureAngle.radians)
                        }
                    }
                }
            }

    }

    @GestureState private var gesturePanOffset: CGSize = .zero

    private var panOffset: CGSize {
        (document.steadyStatePanOffset + gesturePanOffset) * zoomScale
    }

    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset, body: { (latestDragGestureValue, gesturePanOffset, transaction) in
                gesturePanOffset = latestDragGestureValue.translation / self.zoomScale
            })
            .onEnded { finalDragGestureValue in
                self.document.steadyStatePanOffset = self.document.steadyStatePanOffset + (finalDragGestureValue.translation / self.zoomScale)
            }
    }

    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    self.zoomToFit(self.document.backgroundImage, in: size)
                }
            }
    }

    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            document.steadyStatePanOffset = .zero
            document.steadyStateZoomScale = min(hZoom, vZoom)
        }
    }

    private func position(for emoji: EmojiArt.Emoji, in size: CGSize) -> CGPoint {
        var location = emoji.location
        location = CGPoint(x: location.x * zoomScale, y: location.y * zoomScale)
        location = CGPoint(x: location.x + size.width/2, y: location.y + size.height/2)
        location = CGPoint(x: location.x + panOffset.width, y: location.y + panOffset.height)
        if gestureStateSelectedEmoji.singleEmoji?.id == emoji.id || (gestureStateSelectedEmoji.singleEmoji == nil && isEmojiSelected(emoji)) {
            location = CGPoint(x: location.x + gestureStateSelectedEmoji.offset.width, y: location.y + gestureStateSelectedEmoji.offset.height)
        }
        return location
    }

    private func drop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            self.document.backgroundURL = url
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                self.document.addEmoji(string, at: location, size: self.defaultEmojiSize)
            }
        }
        return found
    }

    // Used to store the current selection (only IDs of emojis)
    @State private var selectedEmojiIDs = Set<EmojiArt.Emoji.ID>()

    private var hasSelection: Bool {
        !selectedEmojiIDs.isEmpty
    }

    private func isEmojiSelected(_ emoji: EmojiArt.Emoji) -> Bool {
        selectedEmojiIDs.contains(emoji.id)
    }

    // Tap gesture recognizer for handling one tap selection/deselection and clear
    // if emoji is nil, the action is to clear the selection.
    private func singleTapForSelection(for emoji: EmojiArt.Emoji?) -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                withAnimation(Animation.easeInOut(duration: 0.3)) {
                    if let emoji = emoji {
                        self.selectedEmojiIDs.toggle(emoji.id)
                    }
                    else {
                        self.selectedEmojiIDs.removeAll()
                    }
                }
            }
    }

    // Temporary state for selection drag gesture
    @GestureState private var gestureStateSelectedEmoji: (offset: CGSize, singleEmoji: EmojiArt.Emoji?) = (.zero, nil)

    private func dragSelectionEmoji(for emoji: EmojiArt.Emoji) -> some Gesture {
        let startedWithSelection = self.isEmojiSelected(emoji)
        let draggingEmoji = startedWithSelection ? nil : emoji
        return DragGesture()
            .updating($gestureStateSelectedEmoji, body: { (latestDragGestureValue, gestureStateSelectedEmoji, transaction) in
                let translation = latestDragGestureValue.translation
                gestureStateSelectedEmoji = (translation, draggingEmoji)
            })
            .onEnded { finalDragGestureValue in
                let translation = finalDragGestureValue.translation / self.zoomScale
                if startedWithSelection {
                    self.selectedEmojiIDs.forEach { (emojiId) in
                        if let emoji = self.document.emojis.first(where: {$0.id == emojiId }) {
                            self.document.moveEmoji(emoji, by: translation)
                        }
                    }
                }
                else {
                    self.document.moveEmoji(emoji, by: translation)
                }
        }
    }

    private let defaultEmojiSize: CGFloat = 40
}
