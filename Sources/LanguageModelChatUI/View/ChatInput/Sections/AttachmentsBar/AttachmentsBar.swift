//
//  AttachmentsBar.swift
//  LanguageModelChatUI
//

import AlignedCollectionViewFlowLayout
import OrderedCollections
import QuickLook
import UIKit

class AttachmentsBar: EditorSectionView {
    let collectionView: UICollectionView
    let collectionViewLayout = AlignedCollectionViewFlowLayout(
        horizontalAlignment: .justified,
        verticalAlignment: .center
    )
    var attachments: OrderedDictionary<ItemIdentifier, Item> = [:] {
        didSet { updateDataSource() }
    }

    lazy var dataSource: DataSource = .init(collectionView: collectionView) { [weak self] _, indexPath, itemIdentifier in
        self?.cellFor(indexPath: indexPath, itemIdentifier: itemIdentifier) ?? .init()
    }

    var inset: UIEdgeInsets = .init(top: 10, left: 10, bottom: 0, right: 10)
    let itemSpacing: CGFloat = 10
    let itemSize = CGSize(width: 80, height: AttachmentsBar.itemHeight)

    static let itemHeight: CGFloat = 80

    weak var delegate: Delegate?
    var animatingDifferences: Bool = true
    var isDeletable: Bool = true {
        didSet { collectionView.reloadData() }
    }

    var previewItemDataSource: Any?

    required init() {
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.minimumInteritemSpacing = itemSpacing
        collectionViewLayout.minimumLineSpacing = itemSpacing
        collectionView = .init(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.register(
            AttachmentsImageCell.self,
            forCellWithReuseIdentifier: String(describing: AttachmentsImageCell.self)
        )
        collectionView.register(
            AttachmentsTextCell.self,
            forCellWithReuseIdentifier: String(describing: AttachmentsTextCell.self)
        )
        collectionView.register(
            AttachmentsAudioCell.self,
            forCellWithReuseIdentifier: String(describing: AttachmentsAudioCell.self)
        )
        collectionViewLayout.sectionInset = .init(
            top: 0,
            left: inset.left,
            bottom: 0,
            right: inset.right
        )
        super.init()
        collectionView.delegate = self
    }

    override func initializeViews() {
        super.initializeViews()
        clipsToBounds = true
        addSubview(collectionView)
        updateDataSource()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = .init(x: 0, y: inset.top, width: bounds.width, height: itemSize.height)
    }

    func idealSize() -> CGSize {
        let itemWidth = attachments.values
            .map { itemSize(for: $0.type).width }
            .reduce(0, +)
        let spacingWidth = CGFloat(attachments.count) * itemSpacing
        return .init(
            width: itemWidth + spacingWidth + inset.left + inset.right,
            height: itemSize.height + inset.top + inset.bottom
        )
    }

    func item(for id: ItemIdentifier) -> Item? {
        attachments[id]
    }

    func cellFor(indexPath: IndexPath, itemIdentifier: ItemIdentifier) -> UICollectionViewCell {
        guard let item = item(for: itemIdentifier) else { return .init() }
        switch item.type {
        case .image:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: String(describing: AttachmentsImageCell.self),
                for: indexPath
            ) as! AttachmentsImageCell
            cell.isDeletable = isDeletable
            cell.configure(item: item)
            return cell
        case .document:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: String(describing: AttachmentsTextCell.self),
                for: indexPath
            ) as! AttachmentsTextCell
            cell.isDeletable = isDeletable
            cell.configure(item: item)
            return cell
        case .audio:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: String(describing: AttachmentsAudioCell.self),
                for: indexPath
            ) as! AttachmentsAudioCell
            cell.isDeletable = isDeletable
            cell.configure(item: item)
            return cell
        }
    }

    func updateDataSource() {
        var snapshot = dataSource.snapshot()
        if snapshot.sectionIdentifiers.isEmpty {
            snapshot.appendSections([.main])
        }
        let currentItemIdentifiers = attachments.keys
        for item in snapshot.itemIdentifiers {
            if !currentItemIdentifiers.contains(item) {
                snapshot.deleteItems([item])
            }
        }
        for item in currentItemIdentifiers {
            if !snapshot.itemIdentifiers.contains(item) {
                snapshot.appendItems([item])
            }
        }
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
        delegate?.attachmentBarDidUpdateAttachments(Array(attachments.values))

        if attachments.isEmpty {
            doEditorLayoutAnimation { self.heightPublisher.send(0) }
        } else {
            doEditorLayoutAnimation { [self] in
                heightPublisher.send(itemSize.height + inset.top + inset.bottom)
            }
        }
    }

    func reloadItem(itemIdentifier: Item.ID) {
        var snapshot = dataSource.snapshot()
        snapshot.reloadItems([itemIdentifier])
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    func delete(itemIdentifier: Item.ID?) {
        guard let itemIdentifier else { return }
        attachments.removeValue(forKey: itemIdentifier)
    }

    func insert(item: Item) {
        attachments.updateValue(item, forKey: item.id)
        reloadItem(itemIdentifier: item.id)
    }

    func deleteAllItems() {
        attachments.removeAll()
    }
}

// MARK: - UICollectionViewDelegate

extension AttachmentsBar: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    var storage: TemporaryStorage? {
        var superview = superview
        while superview != nil {
            if let editor = superview as? ChatInputView {
                return editor.storage
            }
            superview = superview?.superview
        }
        return nil
    }

    private var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }

    private var previewTempDir: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LanguageModelChatUI.Preview")
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        cell.puddingAnimate()
        guard
            let itemIdentifier = dataSource.itemIdentifier(for: indexPath),
            let item = item(for: itemIdentifier)
        else { return }
        presentPreview(for: item)
    }

    func presentPreview(for item: Item) {
        assert(Thread.isMainThread)

        if item.type == .document {
            let textViewerController = makeTextViewer(text: item.textContent, editable: storage != nil)
            if storage != nil {
                (textViewerController as? UINavigationController)?.viewControllers.first?.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    systemItem: .done,
                    primaryAction: UIAction { [weak self, weak textViewerController] _ in
                        guard let self, let navigationController = textViewerController as? UINavigationController,
                              let contentVC = navigationController.viewControllers.first else { return }
                        let tv = contentVC.view.subviews.compactMap { $0 as? UITextView }.first
                        let updatedText = tv?.text ?? ""
                        var attachment = item
                        if let storage {
                            let url = storage.fileURL(for: attachment.storageFilename)
                            try? updatedText.write(to: url, atomically: true, encoding: .utf8)
                        }
                        attachment = ChatInputAttachment(
                            id: item.id,
                            type: item.type,
                            name: item.name,
                            previewImageData: item.previewImageData,
                            fileData: item.fileData,
                            textContent: updatedText,
                            storageFilename: item.storageFilename
                        )
                        insert(item: attachment)
                        textViewerController?.dismiss(animated: true)
                    }
                )
            }
            parentViewController?.present(textViewerController, animated: true)
            return
        }

        if let previewDataSource = makeQuickLookDataSource(for: item, storage: storage) {
            let controller = QLPreviewController()
            controller.dataSource = previewDataSource
            controller.delegate = previewDataSource
            parentViewController?.present(controller, animated: true)
            previewItemDataSource = previewDataSource
            return
        }

        if !item.textContent.isEmpty {
            let textViewerController = makeTextViewer(text: item.textContent, editable: false)
            parentViewController?.present(textViewerController, animated: true)
        }
    }

    private func makeTextViewer(text: String, editable: Bool) -> UIViewController {
        let contentVC = UIViewController()
        contentVC.title = editable ? String.localized("Text Editor") : String.localized("Text Viewer")

        let textView = UITextView()
        textView.font = .monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .systemBackground
        textView.isEditable = editable
        textView.text = text
        contentVC.view = textView

        if !editable {
            contentVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
                systemItem: .done,
                primaryAction: UIAction { [weak contentVC] _ in
                    contentVC?.dismiss(animated: true)
                }
            )
        } else {
            contentVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                systemItem: .cancel,
                primaryAction: UIAction { [weak contentVC] _ in
                    contentVC?.dismiss(animated: true)
                }
            )
        }

        let navigationController = UINavigationController(rootViewController: contentVC)
        navigationController.modalPresentationStyle = .formSheet
        navigationController.preferredContentSize = CGSize(width: 555, height: 555)
        navigationController.isModalInPresentation = editable
        return navigationController
    }

    private func makeQuickLookDataSource(for item: Item, storage: TemporaryStorage?) -> SingleItemDataSource? {
        let tempDir = previewTempDir
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        func destinationURL(withExtension fileExtension: String) -> URL {
            var url = tempDir.appendingPathComponent(UUID().uuidString)
            if !fileExtension.isEmpty { url.appendPathExtension(fileExtension) }
            return url
        }

        func cleanup(for url: URL) -> () -> Void {
            { try? FileManager.default.removeItem(at: url) }
        }

        switch item.type {
        case .image:
            if let storage {
                let source = storage.fileURL(for: item.storageFilename)
                if FileManager.default.fileExists(atPath: source.path) {
                    let fileExtension = source.pathExtension.isEmpty ? "png" : source.pathExtension
                    let destination = destinationURL(withExtension: fileExtension)
                    do {
                        if FileManager.default.fileExists(atPath: destination.path) {
                            try FileManager.default.removeItem(at: destination)
                        }
                        try FileManager.default.copyItem(at: source, to: destination)
                        return SingleItemDataSource(
                            item: destination,
                            name: String.localized("Image"),
                            cleanup: cleanup(for: destination)
                        )
                    } catch {}
                }
            }

            if !item.fileData.isEmpty {
                let fileExtension = URL(fileURLWithPath: item.storageFilename).pathExtension
                let resolvedFileExtension = fileExtension.isEmpty ? "png" : fileExtension
                let destination = destinationURL(withExtension: resolvedFileExtension)
                do {
                    try item.fileData.write(to: destination, options: .atomic)
                    return SingleItemDataSource(
                        item: destination,
                        name: String.localized("Image"),
                        cleanup: cleanup(for: destination)
                    )
                } catch {
                    return nil
                }
            }

            if let image = UIImage(data: item.previewImageData), let data = image.pngData() {
                let destination = destinationURL(withExtension: "png")
                do {
                    try data.write(to: destination, options: .atomic)
                    return SingleItemDataSource(
                        item: destination,
                        name: String.localized("Image"),
                        cleanup: cleanup(for: destination)
                    )
                } catch {
                    return nil
                }
            }
            return nil

        case .audio:
            let fileExtension = URL(fileURLWithPath: item.storageFilename).pathExtension
            let resolvedFileExtension = fileExtension.isEmpty ? "m4a" : fileExtension

            if let storage {
                let source = storage.fileURL(for: item.storageFilename)
                if FileManager.default.fileExists(atPath: source.path) {
                    let destination = destinationURL(withExtension: resolvedFileExtension)
                    do {
                        if FileManager.default.fileExists(atPath: destination.path) {
                            try FileManager.default.removeItem(at: destination)
                        }
                        try FileManager.default.copyItem(at: source, to: destination)
                        return SingleItemDataSource(
                            item: destination,
                            name: item.name,
                            cleanup: cleanup(for: destination)
                        )
                    } catch {}
                }
            }

            if !item.fileData.isEmpty {
                let destination = destinationURL(withExtension: resolvedFileExtension)
                do {
                    try item.fileData.write(to: destination, options: .atomic)
                    return SingleItemDataSource(
                        item: destination,
                        name: item.name,
                        cleanup: cleanup(for: destination)
                    )
                } catch {
                    return nil
                }
            }
            return nil

        case .document:
            return nil
        }
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let itemIdentifier = dataSource.itemIdentifier(for: indexPath) else { return .zero }
        guard let item = item(for: itemIdentifier) else { return .zero }
        return itemSize(for: item.type)
    }

    private func itemSize(for type: Item.AttachmentType) -> CGSize {
        switch type {
        case .image:
            itemSize
        case .document, .audio:
            .init(width: itemSize.width * 3, height: itemSize.height)
        }
    }
}
