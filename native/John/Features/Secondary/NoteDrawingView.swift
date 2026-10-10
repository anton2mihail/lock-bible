import PencilKit
import SwiftUI

/// A canvas for a handwritten note. Pencil and finger both draw.
struct NoteDrawingCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        canvas.accessibilityIdentifier = "saved-note-canvas"
        let picker = PKToolPicker()
        context.coordinator.picker = picker
        picker.addObserver(canvas)
        picker.setVisible(true, forFirstResponder: canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing { canvas.drawing = drawing }
    }

    @MainActor final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: NoteDrawingCanvas
        var picker: PKToolPicker?
        init(_ parent: NoteDrawingCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

struct NoteDrawingSheet: View {
    @Binding var drawing: PKDrawing
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            NoteDrawingCanvas(drawing: $drawing)
                .navigationTitle("Handwriting")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear", role: .destructive) { drawing = PKDrawing() }
                            .accessibilityIdentifier("saved-note-canvas-clear")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .accessibilityIdentifier("saved-note-canvas-done")
                    }
                }
        }
    }
}

/// A small image of a drawing. It shows the drawing in a note.
struct NoteDrawingPreview: View {
    let drawing: PKDrawing
    var body: some View {
        let bounds = drawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 100, height: 100) : drawing.bounds.insetBy(dx: -8, dy: -8)
        Image(uiImage: drawing.image(from: bounds, scale: 2))
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 160)
            .accessibilityLabel("Handwritten note")
    }
}
