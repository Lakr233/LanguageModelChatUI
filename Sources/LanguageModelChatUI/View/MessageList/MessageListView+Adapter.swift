//
//  MessageListView+Adapter.swift
//  LanguageModelChatUI
//

import ListViewKit
import Litext
import MarkdownView
import UIKit

private extension MessageListView {
    enum RowType {
        case userContent
        case userAttachment
        case reasoningContent
        case responseContent
        case hint
        case toolCallHint
        case activityReporting
    }
}

extension MessageListView: ListViewAdapter {
    private func entryForRow(at index: Int) -> Entry? {
        dataSource.snapshot().item(at: index)
    }

    public func listView(_: ListView, rowKindFor _: any Identifiable, at index: Int) -> any Hashable {
        guard let entry = entryForRow(at: index) else { return RowType.hint }
        return switch entry {
        case .userContent: RowType.userContent
        case .userAttachment: RowType.userAttachment
        case .reasoningContent: RowType.reasoningContent
        case .responseContent: RowType.responseContent
        case .hint: RowType.hint
        case .toolCallHint: RowType.toolCallHint
        case .activityReporting: RowType.activityReporting
        }
    }

    public func listViewMakeRow(for kind: any Hashable) -> ListRowView {
        guard let type = kind as? RowType else { return .init() }

        let view: MessageListRowView = switch type {
        case .userContent:
            UserMessageView()
        case .userAttachment:
            UserAttachmentView()
        case .reasoningContent:
            ReasoningContentView()
        case .responseContent:
            ResponseView()
        case .hint:
            HintMessageView()
        case .toolCallHint:
            ToolHintView()
        case .activityReporting:
            ActivityReportingView()
        }
        view.theme = theme
        return view
    }

    public func listView(_ listView: ListView, heightFor _: any Identifiable, at index: Int) -> CGFloat {
        guard let entry = entryForRow(at: index) else { return 0 }

        let listRowInsets = MessageListView.listRowInsets
        let containerWidth = max(0, listView.bounds.width - listRowInsets.horizontal)
        if containerWidth == 0 { return 0 }

        let bottomInset = listRowInsets.bottom
        let contentHeight: CGFloat = {
            switch entry {
            case let .userContent(_, message):
                let attributedContent = NSAttributedString(string: message.content, attributes: [
                    .font: theme.fonts.body,
                    .foregroundColor: theme.colors.body,
                ])
                let availableWidth = UserMessageView.availableTextWidth(for: containerWidth)
                return boundingSize(with: availableWidth, for: attributedContent).height + UserMessageView.textPadding * 2
            case .userAttachment:
                return AttachmentsBar.itemHeight
            case let .reasoningContent(_, message):
                let attributedContent = NSAttributedString(string: message.content, attributes: [
                    .font: theme.fonts.footnote,
                    .paragraphStyle: ReasoningContentView.paragraphStyle,
                ])
                if message.isRevealed {
                    return boundingSize(with: containerWidth - 16, for: attributedContent).height
                        + ReasoningContentView.spacing
                        + ReasoningContentView.revealedTileHeight
                        + 2
                } else {
                    return ReasoningContentView.unrevealedTileHeight
                }
            case let .responseContent(_, message):
                markdownViewForSizeCalculation.theme = theme
                let package = markdownPackageCache.package(for: message, theme: theme)
                markdownViewForSizeCalculation.setMarkdownManually(package)
                return ceil(markdownViewForSizeCalculation.boundingSize(for: containerWidth).height)
            case .hint:
                return ceil(theme.fonts.footnote.lineHeight + 16)
            case let .activityReporting(content):
                let textHeight = boundingSize(with: .greatestFiniteMagnitude, for: NSAttributedString(string: content, attributes: [
                    .font: theme.fonts.body,
                ])).height
                return max(textHeight, ActivityReportingView.loadingSymbolSize.height + 16)
            case .toolCallHint:
                return theme.fonts.body.lineHeight + 20
            }
        }()

        return contentHeight + bottomInset
    }

    public func listView(_: ListView, configureRowView rowView: ListRowView, for _: any Identifiable, at index: Int) {
        guard let entry = entryForRow(at: index) else { return }

        if let userMessageView = rowView as? UserMessageView {
            if case let .userContent(_, message) = entry {
                userMessageView.theme = theme
                userMessageView.text = message.content
            }
        } else if let userAttachmentView = rowView as? UserAttachmentView {
            if case let .userAttachment(_, attachments) = entry {
                userAttachmentView.theme = theme
                userAttachmentView.update(with: attachments)
            }
        } else if let responseView = rowView as? ResponseView {
            if case let .responseContent(_, message) = entry {
                responseView.theme = theme
                let package = markdownPackageCache.package(for: message, theme: theme)
                responseView.markdownView.setMarkdown(package)
            }
        } else if let hintMessageView = rowView as? HintMessageView {
            if case let .hint(_, content) = entry {
                hintMessageView.theme = theme
                hintMessageView.text = content
            }
        } else if let activityReportingView = rowView as? ActivityReportingView {
            if case let .activityReporting(content) = entry {
                activityReportingView.theme = theme
                activityReportingView.text = content
            }
        } else if let reasoningContentView = rowView as? ReasoningContentView {
            if case let .reasoningContent(_, message) = entry {
                reasoningContentView.theme = theme
                reasoningContentView.isRevealed = message.isRevealed
                reasoningContentView.isThinking = message.isThinking
                reasoningContentView.thinkingDuration = message.thinkingDuration
                reasoningContentView.text = message.content
                reasoningContentView.thinkingTileTapHandler = { [weak self] _ in
                    guard let self, let conversationMessage = session?.message(for: message.id) else { return }
                    for (index, part) in conversationMessage.parts.enumerated() {
                        if case var .reasoning(reasoningPart) = part {
                            reasoningPart.isCollapsed.toggle()
                            conversationMessage.parts[index] = .reasoning(reasoningPart)
                            break
                        }
                    }
                    session?.notifyMessagesDidChange(scrolling: false)
                }
            }
        } else if let toolHintView = rowView as? ToolHintView {
            if case let .toolCallHint(_, toolCall) = entry {
                toolHintView.theme = theme
                toolHintView.toolName = toolCall.toolName
                toolHintView.text = toolCall.parameters
                toolHintView.state = toolCall.state
                toolHintView.clickHandler = nil
            }
        }
    }

    private func boundingSize(with width: CGFloat, for attributedString: NSAttributedString) -> CGSize {
        labelForSizeCalculation.preferredMaxLayoutWidth = width
        labelForSizeCalculation.attributedText = attributedString
        let contentSize = labelForSizeCalculation.intrinsicContentSize
        return .init(width: ceil(contentSize.width), height: ceil(contentSize.height))
    }
}
