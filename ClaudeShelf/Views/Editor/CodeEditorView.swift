import SwiftUI
import AppKit

/// An NSTextView-based code editor wrapped in NSViewRepresentable.
///
/// Provides a monospaced text editing surface with line numbers in a gutter,
/// horizontal and vertical scrolling, and undo support. Designed as a drop-in
/// replacement for SwiftUI's TextEditor with macOS-native editor capabilities.
struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var onTextChange: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isRichText = false
        textView.importsGraphics = false

        // Disable automatic text substitutions for code editing
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false

        // Enable horizontal scrolling
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.string = text
        textView.delegate = context.coordinator

        scrollView.documentView = textView

        // Set up line number ruler
        scrollView.rulersVisible = true
        scrollView.hasVerticalRuler = true
        let rulerView = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = rulerView

        // Register for text change notifications to update the ruler
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleTextStorageDidProcessEditing(_:)),
            name: NSTextStorage.didProcessEditingNotification,
            object: textView.textStorage
        )

        context.coordinator.textView = textView
        context.coordinator.rulerView = rulerView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update editability
        textView.isEditable = isEditable

        // Only update text if it differs to avoid cursor jumps and feedback loops
        guard !context.coordinator.isUpdating else { return }
        if textView.string != text {
            context.coordinator.isUpdating = true
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.isUpdating = false
            context.coordinator.rulerView?.needsDisplay = true
        }
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        var isUpdating = false
        weak var textView: NSTextView?
        weak var rulerView: NSRulerView?

        init(_ parent: CodeEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating else { return }
            guard let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string
            parent.onTextChange?(textView.string)
            isUpdating = false
        }

        @objc func handleTextStorageDidProcessEditing(_ notification: Notification) {
            // Schedule ruler redraw on next run loop iteration to ensure layout is current
            DispatchQueue.main.async { [weak self] in
                self?.rulerView?.needsDisplay = true
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Line Number Ruler View

/// A custom ruler view that draws line numbers in the gutter alongside an NSTextView.
///
/// Uses the text view's layout manager to enumerate visible line fragments and
/// draws right-aligned line numbers for each line.
fileprivate final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let lineNumberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private let lineNumberColor = NSColor.secondaryLabelColor
    private let gutterPadding: CGFloat = 8

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 40
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var requiredThickness: CGFloat {
        guard let textView = textView else { return 40 }
        let lineCount = max(1, countLines(in: textView.string))
        let digitCount = max(2, String(lineCount).count)
        let sampleString = String(repeating: "8", count: digitCount) as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: lineNumberFont]
        let width = sampleString.size(withAttributes: attributes).width
        return max(40, width + gutterPadding * 2)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Fill gutter background
        let gutterBackgroundColor = NSColor.windowBackgroundColor
        gutterBackgroundColor.setFill()
        rect.fill()

        // Draw separator line
        let separatorColor = NSColor.separatorColor
        separatorColor.setStroke()
        let separatorPath = NSBezierPath()
        separatorPath.move(to: NSPoint(x: bounds.maxX - 0.5, y: rect.minY))
        separatorPath.line(to: NSPoint(x: bounds.maxX - 0.5, y: rect.maxY))
        separatorPath.lineWidth = 1.0
        separatorPath.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor
        ]

        let string = textView.string as NSString
        let visibleRect = scrollView?.contentView.bounds ?? textView.visibleRect
        let textInset = textView.textContainerInset

        // Find the visible glyph range
        let visibleGlyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        let visibleCharRange = layoutManager.characterRange(
            forGlyphRange: visibleGlyphRange,
            actualGlyphRange: nil
        )

        // Count lines before the visible range to get the starting line number
        var lineNumber = 1
        var index = 0
        while index < visibleCharRange.location {
            let lineRange = string.lineRange(for: NSRange(location: index, length: 0))
            index = NSMaxRange(lineRange)
            lineNumber += 1
        }

        // Enumerate line fragments in the visible range
        index = visibleCharRange.location
        while index < NSMaxRange(visibleCharRange) {
            let lineRange = string.lineRange(for: NSRange(location: index, length: 0))

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: lineRange,
                actualCharacterRange: nil
            )

            // Get the rect for this line fragment
            let lineRect = layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: textContainer
            )

            // Calculate Y position relative to the ruler
            let yPosition = lineRect.minY + textInset.height - visibleRect.origin.y

            // Draw the line number right-aligned
            let lineNumberString = "\(lineNumber)" as NSString
            let stringSize = lineNumberString.size(withAttributes: attributes)
            let drawX = bounds.width - stringSize.width - gutterPadding
            let drawY = yPosition + (lineRect.height - stringSize.height) / 2

            lineNumberString.draw(
                at: NSPoint(x: drawX, y: drawY),
                withAttributes: attributes
            )

            lineNumber += 1
            index = NSMaxRange(lineRange)
        }

        // Handle empty document — draw line 1
        if string.length == 0 {
            let lineNumberString = "1" as NSString
            let stringSize = lineNumberString.size(withAttributes: attributes)
            let drawX = bounds.width - stringSize.width - gutterPadding
            let drawY = textInset.height + (lineNumberFont.ascender - stringSize.height) / 2

            lineNumberString.draw(
                at: NSPoint(x: drawX, y: drawY),
                withAttributes: attributes
            )
        }
    }

    /// Count the number of lines in a string.
    private func countLines(in string: String) -> Int {
        guard !string.isEmpty else { return 1 }
        var count = 0
        string.enumerateLines { _, _ in
            count += 1
        }
        // If string ends with newline, add one more line
        if string.hasSuffix("\n") {
            count += 1
        }
        return count
    }
}

// MARK: - Preview

#Preview {
    CodeEditorView(
        text: .constant("""
        # CLAUDE.md

        This is a sample configuration file.
        It demonstrates the code editor with line numbers.

        ## Rules

        - Follow Swift API Design Guidelines
        - Use MVVM architecture
        - Keep functions under 50 lines

        ## Commands

        ```bash
        swift build
        swift test
        ```
        """),
        isEditable: true
    )
    .frame(width: 600, height: 400)
}
