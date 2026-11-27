import AppKit

@MainActor
final class NewFilePanel: NSPanel {
    private let directory: URL
    private let name = NSTextField()
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private let form = NSStackView()
    private var createdFile: URL?

    init(directory: URL) {
        self.directory = directory
        let width: CGFloat = 332
        let inset: CGFloat = 18
        super.init(contentRect: NSRect(x: 0, y: 0, width: width, height: 158),
                   styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        title = "New File"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .boldSystemFont(ofSize: 14)
        let header = NSStackView(views: [icon, titleLabel])
        header.alignment = .centerY
        header.spacing = 6

        let path = NSTextField(labelWithString: directory.path)
        path.lineBreakMode = .byTruncatingMiddle
        path.alignment = .center
        path.toolTip = directory.path
        path.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        name.placeholderString = "File name, e.g. test.txt"
        name.setAccessibilityLabel("File name")
        name.target = self
        name.action = #selector(createFile)

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        errorLabel.preferredMaxLayoutWidth = width - 2 * inset
        errorLabel.isHidden = true

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelOperation(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let create = NSButton(title: "Create", target: self, action: #selector(createFile))
        create.keyEquivalent = "\r"
        let buttons = NSStackView(views: [cancel, create])
        buttons.spacing = 8

        form.orientation = .vertical
        form.alignment = .centerX
        form.spacing = 12
        form.edgeInsets = NSEdgeInsets(top: 16, left: inset, bottom: 14, right: inset)
        for view in [header, path, name, errorLabel, buttons] { form.addArrangedSubview(view) }
        form.setCustomSpacing(7, after: header)
        contentView?.addSubview(form)
        NSLayoutConstraint.activate([
            form.widthAnchor.constraint(equalToConstant: width),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalTo: icon.widthAnchor),
            name.widthAnchor.constraint(equalToConstant: width - 2 * inset),
            path.widthAnchor.constraint(equalTo: name.widthAnchor),
            errorLabel.widthAnchor.constraint(equalTo: name.widthAnchor),
            cancel.widthAnchor.constraint(equalToConstant: 94),
            create.widthAnchor.constraint(equalTo: cancel.widthAnchor)
        ])
        fitForm()
        initialFirstResponder = name
        center()
    }

    private func fitForm() {
        let size = form.fittingSize
        setContentSize(size)
        form.frame = NSRect(origin: .zero, size: size)
    }

    func run() -> URL? {
        makeKeyAndOrderFront(nil)
        NSApp.runModal(for: self)
        orderOut(nil)
        return createdFile
    }

    @objc private func createFile() {
        do {
            createdFile = try NewFile.create(named: name.stringValue, in: directory)
            NSApp.stopModal()
        } catch {
            errorLabel.stringValue = error.localizedDescription
            errorLabel.isHidden = false
            fitForm()
            makeFirstResponder(name)
            name.selectText(nil)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        NSApp.stopModal()
    }
}
