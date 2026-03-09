//
//  AttachmentsBar+Type.swift
//  LanguageModelChatUI
//

import UIKit

extension AttachmentsBar {
    enum Section { case main }
    typealias Item = ChatInputAttachment
    typealias ItemIdentifier = Item.ID
    typealias DataSource = UICollectionViewDiffableDataSource<Section, ItemIdentifier>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, ItemIdentifier>
}
