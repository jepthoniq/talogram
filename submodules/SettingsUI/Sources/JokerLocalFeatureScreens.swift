import Foundation
import UIKit
import AVFoundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

private final class JokerQuickReplyActionButton: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    init(theme: PresentationTheme, icon: String, title: String, isRTL: Bool) {
        super.init(frame: .zero)

        self.backgroundColor = theme.list.itemAccentColor.withAlphaComponent(0.10)
        self.layer.cornerRadius = 14.0
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.accessibilityLabel = title

        self.iconView.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17.0, weight: .semibold))?.withTintColor(theme.list.itemAccentColor, renderingMode: .alwaysOriginal)
        self.iconView.contentMode = .scaleAspectFit
        self.iconView.translatesAutoresizingMaskIntoConstraints = false

        self.titleLabel.text = title
        self.titleLabel.font = Font.semibold(15.0)
        self.titleLabel.textColor = theme.list.itemAccentColor
        self.titleLabel.textAlignment = isRTL ? .right : .left

        let stackView = UIStackView(arrangedSubviews: [self.iconView, self.titleLabel])
        stackView.axis = .horizontal
        stackView.spacing = 9.0
        stackView.alignment = .center
        stackView.isUserInteractionEnabled = false
        stackView.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        stackView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stackView)

        NSLayoutConstraint.activate([
            self.iconView.widthAnchor.constraint(equalToConstant: 20.0),
            self.iconView.heightAnchor.constraint(equalToConstant: 20.0),
            stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: 14.0),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -14.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTitle(_ title: String) {
        self.titleLabel.text = title
        self.accessibilityLabel = title
    }
}

private final class JokerQuickReplyCell: UITableViewCell {
    let cardView = UIView()
    private let iconBackgroundView = UIView()
    private let iconView = UIImageView()
    private let shortcutLabelView = UILabel()
    private let textLabelView = UILabel()
    let deleteButton = UIButton(type: .system)
    private var isRTL = false
    private var showsThumbnail = false
    var onDelete: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.selectionStyle = .none

        self.cardView.layer.cornerRadius = 18.0
        self.cardView.layer.masksToBounds = true
        self.contentView.addSubview(self.cardView)

        self.iconBackgroundView.layer.cornerRadius = 18.0
        self.cardView.addSubview(self.iconBackgroundView)

        self.iconView.contentMode = .scaleAspectFit
        self.iconBackgroundView.addSubview(self.iconView)

        self.shortcutLabelView.font = Font.semibold(13.0)
        self.shortcutLabelView.numberOfLines = 1
        self.cardView.addSubview(self.shortcutLabelView)

        self.textLabelView.numberOfLines = 2
        self.cardView.addSubview(self.textLabelView)

        self.deleteButton.addTarget(self, action: #selector(self.deleteTapped), for: .touchUpInside)
        self.cardView.addSubview(self.deleteButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func deleteTapped() {
        self.onDelete?()
    }

    func update(reply: JokerQuickReply, theme: PresentationTheme, isRTL: Bool, fallbackTitle: String, mediaTitle: String) {
        self.isRTL = isRTL
        self.cardView.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.iconBackgroundView.backgroundColor = theme.list.itemAccentColor.withAlphaComponent(0.14)
        self.shortcutLabelView.textColor = theme.list.itemAccentColor
        self.shortcutLabelView.text = "/" + (reply.shortcut ?? fallbackTitle)
        self.shortcutLabelView.textAlignment = isRTL ? .right : .left
        self.shortcutLabelView.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        self.textLabelView.text = reply.text.isEmpty ? mediaTitle : reply.text
        self.textLabelView.textColor = reply.text.isEmpty ? theme.list.itemSecondaryTextColor : theme.list.itemPrimaryTextColor
        self.textLabelView.font = Font.regular(15.0)
        self.textLabelView.textAlignment = isRTL ? .right : .left
        self.deleteButton.setImage(UIImage(systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15.0, weight: .medium)), for: .normal)
        self.deleteButton.tintColor = theme.list.itemSecondaryTextColor
        self.deleteButton.backgroundColor = theme.list.itemPrimaryTextColor.withAlphaComponent(0.05)
        self.deleteButton.layer.cornerRadius = 17.0
        self.textLabelView.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight

        self.iconView.layer.cornerRadius = 0.0
        self.iconView.clipsToBounds = false
        self.iconView.contentMode = .scaleAspectFit
        self.showsThumbnail = false
        if let media = reply.media {
            if media.isVideo {
                self.iconView.image = UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16.0, weight: .semibold))?.withTintColor(theme.list.itemAccentColor, renderingMode: .alwaysOriginal)
            } else {
                let url = jokerQuickReplyMediaURL(fileName: media.fileName)
                if let image = UIImage(contentsOfFile: url.path) {
                    self.iconView.image = image
                    self.iconView.contentMode = .scaleAspectFill
                    self.iconView.layer.cornerRadius = 10.0
                    self.iconView.clipsToBounds = true
                    self.showsThumbnail = true
                } else {
                    self.iconView.image = UIImage(systemName: "photo.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16.0, weight: .semibold))?.withTintColor(theme.list.itemAccentColor, renderingMode: .alwaysOriginal)
                }
            }
        } else {
            self.iconView.image = UIImage(systemName: "bolt.fill")?.withTintColor(theme.list.itemAccentColor, renderingMode: .alwaysOriginal)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.cardView.frame = self.contentView.bounds.insetBy(dx: 16.0, dy: 5.0)
        let bounds = self.cardView.bounds
        let isRTL = self.isRTL
        let iconSize: CGFloat = 36.0
        let padding: CGFloat = 14.0
        let deleteSize: CGFloat = 34.0
        let iconX = isRTL ? bounds.width - padding - iconSize : padding
        self.iconBackgroundView.frame = CGRect(x: iconX, y: (bounds.height - iconSize) / 2.0, width: iconSize, height: iconSize)
        if self.showsThumbnail {
            self.iconView.frame = self.iconBackgroundView.bounds.insetBy(dx: 3.0, dy: 3.0)
        } else {
            self.iconView.frame = self.iconBackgroundView.bounds.insetBy(dx: 9.0, dy: 9.0)
        }
        let deleteX = isRTL ? padding : bounds.width - padding - deleteSize
        self.deleteButton.frame = CGRect(x: deleteX, y: (bounds.height - deleteSize) / 2.0, width: deleteSize, height: deleteSize)
        let textX = isRTL ? padding + deleteSize + 8.0 : padding + iconSize + 12.0
        let textWidth = bounds.width - padding * 2.0 - iconSize - 12.0 - deleteSize - 8.0
        self.shortcutLabelView.frame = CGRect(x: textX, y: 8.0, width: textWidth, height: 18.0)
        self.textLabelView.frame = CGRect(x: textX, y: 27.0, width: textWidth, height: max(0.0, bounds.height - 34.0))
    }
}

private struct JokerQuickReplyDraft {
    let shortcut: String
    let text: String
    let media: JokerQuickReplyMedia?
    let mediaPreview: UIImage?
}

private final class JokerQuickReplyEditorView: UIView, UITextViewDelegate, UITextFieldDelegate {
    private let dimView = UIView()
    private let cardView = UIView()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let shortcutContainer = UIView()
    private let slashLabel = UILabel()
    private let shortcutField = UITextField()
    private let inputContainer = UIView()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let mediaContainer = UIView()
    private let mediaImageView = UIImageView()
    private let mediaVideoIconBackground = UIView()
    private let mediaVideoIconView = UIImageView()
    private let mediaLabel = UILabel()
    private let removeMediaButton = UIButton(type: .system)
    private let attachButton: JokerQuickReplyActionButton
    private let errorLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private var cardHeightConstraint: NSLayoutConstraint!

    private let isRTL: Bool
    private let attachTitle: String
    private let changeAttachTitle: String
    private let imageTitle: String
    private let videoTitle: String
    private let placeholderText: String
    private let mediaPlaceholderText: String
    private var media: JokerQuickReplyMedia?
    private var mediaPreview: UIImage?
    private var newlyCreatedMediaFileName: String?
    private var didCommit = false

    var mediaFileName: String? {
        return self.media?.fileName
    }
    var onSave: ((JokerQuickReplyDraft) -> Bool)?
    var onAttachMedia: (() -> Void)?
    var onDismiss: (() -> Void)?

    init(theme: PresentationTheme, title: String, shortcut: String, text: String, media: JokerQuickReplyMedia?, mediaPreview: UIImage?, placeholder: String, mediaPlaceholder: String, attachTitle: String, changeAttachTitle: String, imageTitle: String, videoTitle: String, cancelTitle: String, saveTitle: String, isRTL: Bool) {
        self.isRTL = isRTL
        self.attachTitle = attachTitle
        self.changeAttachTitle = changeAttachTitle
        self.imageTitle = imageTitle
        self.videoTitle = videoTitle
        self.placeholderText = placeholder
        self.mediaPlaceholderText = mediaPlaceholder
        self.media = media
        self.mediaPreview = mediaPreview
        self.attachButton = JokerQuickReplyActionButton(theme: theme, icon: "paperclip", title: attachTitle, isRTL: isRTL)

        super.init(frame: .zero)

        let semantic: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        self.semanticContentAttribute = semantic
        self.translatesAutoresizingMaskIntoConstraints = false

        self.dimView.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        self.dimView.translatesAutoresizingMaskIntoConstraints = false
        self.dimView.alpha = 0.0
        self.addSubview(self.dimView)

        self.cardView.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.cardView.layer.cornerRadius = 24.0
        self.cardView.layer.masksToBounds = true
        self.cardView.layer.borderWidth = 0.5
        self.cardView.layer.borderColor = theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.35).cgColor
        self.cardView.semanticContentAttribute = semantic
        self.cardView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.cardView)

        self.scrollView.alwaysBounceVertical = true
        self.scrollView.keyboardDismissMode = .interactive
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.cardView.addSubview(self.scrollView)

        self.contentStack.axis = .vertical
        self.contentStack.spacing = 14.0
        self.contentStack.alignment = .fill
        self.contentStack.semanticContentAttribute = semantic
        self.contentStack.translatesAutoresizingMaskIntoConstraints = false

        self.titleLabel.text = title
        self.titleLabel.font = Font.semibold(18.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.titleLabel.textAlignment = isRTL ? .right : .left
        self.titleLabel.numberOfLines = 2

        self.shortcutContainer.backgroundColor = theme.list.blocksBackgroundColor
        self.shortcutContainer.layer.cornerRadius = 14.0
        self.shortcutContainer.layer.masksToBounds = true
        self.shortcutContainer.semanticContentAttribute = semantic

        self.slashLabel.text = "/"
        self.slashLabel.font = Font.semibold(17.0)
        self.slashLabel.textColor = theme.list.itemAccentColor
        self.slashLabel.textAlignment = .center
        self.slashLabel.translatesAutoresizingMaskIntoConstraints = false
        self.shortcutContainer.addSubview(self.slashLabel)

        self.shortcutField.text = shortcut
        self.shortcutField.placeholder = ""
        self.shortcutField.font = Font.regular(16.0)
        self.shortcutField.textColor = theme.list.itemPrimaryTextColor
        self.shortcutField.tintColor = theme.list.itemAccentColor
        self.shortcutField.textAlignment = isRTL ? .right : .left
        self.shortcutField.semanticContentAttribute = semantic
        self.shortcutField.autocapitalizationType = .none
        self.shortcutField.autocorrectionType = .no
        self.shortcutField.spellCheckingType = .no
        self.shortcutField.returnKeyType = .next
        self.shortcutField.delegate = self
        self.shortcutField.addTarget(self, action: #selector(self.shortcutChanged), for: .editingChanged)
        self.shortcutField.translatesAutoresizingMaskIntoConstraints = false
        self.shortcutContainer.addSubview(self.shortcutField)

        self.inputContainer.backgroundColor = theme.list.blocksBackgroundColor
        self.inputContainer.layer.cornerRadius = 14.0
        self.inputContainer.layer.masksToBounds = true

        self.textView.backgroundColor = .clear
        self.textView.textColor = theme.list.itemPrimaryTextColor
        self.textView.tintColor = theme.list.itemAccentColor
        self.textView.font = Font.regular(16.0)
        self.textView.textAlignment = isRTL ? .right : .left
        self.textView.textContainerInset = UIEdgeInsets(top: 10.0, left: 12.0, bottom: 10.0, right: 12.0)
        self.textView.isScrollEnabled = true
        self.textView.text = text
        self.textView.delegate = self
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.inputContainer.addSubview(self.textView)

        self.placeholderLabel.text = placeholder
        self.placeholderLabel.font = Font.regular(16.0)
        self.placeholderLabel.textColor = theme.list.itemPlaceholderTextColor
        self.placeholderLabel.textAlignment = isRTL ? .right : .left
        self.placeholderLabel.isHidden = !text.isEmpty
        self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        self.inputContainer.addSubview(self.placeholderLabel)

        self.mediaContainer.backgroundColor = theme.list.blocksBackgroundColor
        self.mediaContainer.layer.cornerRadius = 14.0
        self.mediaContainer.layer.masksToBounds = true
        self.mediaContainer.semanticContentAttribute = semantic

        self.mediaImageView.contentMode = .scaleAspectFill
        self.mediaImageView.clipsToBounds = true
        self.mediaImageView.translatesAutoresizingMaskIntoConstraints = false
        self.mediaContainer.addSubview(self.mediaImageView)

        self.mediaVideoIconBackground.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        self.mediaVideoIconBackground.layer.cornerRadius = 27.0
        self.mediaVideoIconBackground.translatesAutoresizingMaskIntoConstraints = false
        self.mediaContainer.addSubview(self.mediaVideoIconBackground)

        self.mediaVideoIconView.image = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22.0, weight: .semibold))?.withTintColor(.white, renderingMode: .alwaysOriginal)
        self.mediaVideoIconView.contentMode = .scaleAspectFit
        self.mediaVideoIconView.translatesAutoresizingMaskIntoConstraints = false
        self.mediaVideoIconBackground.addSubview(self.mediaVideoIconView)

        self.mediaLabel.font = Font.semibold(13.0)
        self.mediaLabel.textColor = .white
        self.mediaLabel.textAlignment = .center
        self.mediaLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        self.mediaLabel.translatesAutoresizingMaskIntoConstraints = false
        self.mediaContainer.addSubview(self.mediaLabel)

        self.removeMediaButton.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13.0, weight: .bold)), for: .normal)
        self.removeMediaButton.tintColor = .white
        self.removeMediaButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        self.removeMediaButton.layer.cornerRadius = 16.0
        self.removeMediaButton.addTarget(self, action: #selector(self.removeMediaTapped), for: .touchUpInside)
        self.removeMediaButton.translatesAutoresizingMaskIntoConstraints = false
        self.mediaContainer.addSubview(self.removeMediaButton)

        self.attachButton.addTarget(self, action: #selector(self.attachTapped), for: .touchUpInside)

        self.errorLabel.font = Font.regular(13.0)
        self.errorLabel.textColor = theme.list.itemDestructiveColor
        self.errorLabel.textAlignment = isRTL ? .right : .left
        self.errorLabel.numberOfLines = 2
        self.errorLabel.isHidden = true

        self.cancelButton.setTitle(cancelTitle, for: .normal)
        self.cancelButton.setTitleColor(theme.list.itemPrimaryTextColor, for: .normal)
        self.cancelButton.titleLabel?.font = Font.semibold(16.0)
        self.cancelButton.backgroundColor = theme.list.itemPrimaryTextColor.withAlphaComponent(0.06)
        self.cancelButton.layer.cornerRadius = 14.0
        self.cancelButton.addTarget(self, action: #selector(self.cancelTapped), for: .touchUpInside)

        self.saveButton.setTitle(saveTitle, for: .normal)
        self.saveButton.setTitleColor(.white, for: .normal)
        self.saveButton.titleLabel?.font = Font.semibold(16.0)
        self.saveButton.backgroundColor = theme.list.itemAccentColor
        self.saveButton.layer.cornerRadius = 14.0
        self.saveButton.addTarget(self, action: #selector(self.saveTapped), for: .touchUpInside)
        self.saveButton.isEnabled = false
        self.saveButton.alpha = 0.45

        let buttonsRow = UIStackView(arrangedSubviews: [self.cancelButton, self.saveButton])
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 10.0
        buttonsRow.distribution = .fillEqually
        buttonsRow.semanticContentAttribute = semantic

        self.contentStack.addArrangedSubview(self.titleLabel)
        self.contentStack.addArrangedSubview(self.shortcutContainer)
        self.contentStack.addArrangedSubview(self.inputContainer)
        self.contentStack.addArrangedSubview(self.mediaContainer)
        self.contentStack.addArrangedSubview(self.attachButton)
        self.contentStack.addArrangedSubview(self.errorLabel)
        self.contentStack.addArrangedSubview(buttonsRow)
        self.scrollView.addSubview(self.contentStack)

        self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapped)))

        let cardWidth = self.cardView.widthAnchor.constraint(equalTo: self.widthAnchor, constant: -32.0)
        cardWidth.priority = UILayoutPriority(999.0)
        self.cardHeightConstraint = self.cardView.heightAnchor.constraint(equalToConstant: 420.0)
        self.cardHeightConstraint.priority = UILayoutPriority(999.0)
        let cardFallbackHeight = self.cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240.0)
        cardFallbackHeight.priority = UILayoutPriority(250.0)
        let cardCenterY = self.cardView.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -12.0)
        cardCenterY.priority = UILayoutPriority(750.0)

        NSLayoutConstraint.activate([
            self.dimView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.dimView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.dimView.topAnchor.constraint(equalTo: self.topAnchor),
            self.dimView.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            self.cardView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.cardView.topAnchor.constraint(greaterThanOrEqualTo: self.safeAreaLayoutGuide.topAnchor, constant: 20.0),
            self.cardView.bottomAnchor.constraint(lessThanOrEqualTo: self.keyboardLayoutGuide.topAnchor, constant: -16.0),
            self.cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 540.0),
            cardWidth,
            cardCenterY,
            self.cardHeightConstraint,
            cardFallbackHeight,

            self.scrollView.leadingAnchor.constraint(equalTo: self.cardView.leadingAnchor, constant: 18.0),
            self.scrollView.trailingAnchor.constraint(equalTo: self.cardView.trailingAnchor, constant: -18.0),
            self.scrollView.topAnchor.constraint(equalTo: self.cardView.topAnchor, constant: 18.0),
            self.scrollView.bottomAnchor.constraint(equalTo: self.cardView.bottomAnchor, constant: -18.0),

            self.contentStack.leadingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.leadingAnchor),
            self.contentStack.trailingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.trailingAnchor),
            self.contentStack.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor),
            self.contentStack.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor),
            self.contentStack.widthAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.widthAnchor),

            self.shortcutContainer.heightAnchor.constraint(equalToConstant: 50.0),
            self.inputContainer.heightAnchor.constraint(equalToConstant: 128.0),
            self.mediaContainer.heightAnchor.constraint(equalToConstant: 150.0),
            self.attachButton.heightAnchor.constraint(equalToConstant: 48.0),
            buttonsRow.heightAnchor.constraint(equalToConstant: 50.0),

            self.slashLabel.leadingAnchor.constraint(equalTo: self.shortcutContainer.leadingAnchor, constant: 12.0),
            self.slashLabel.centerYAnchor.constraint(equalTo: self.shortcutContainer.centerYAnchor),
            self.slashLabel.widthAnchor.constraint(equalToConstant: 12.0),

            self.shortcutField.leadingAnchor.constraint(equalTo: self.slashLabel.trailingAnchor, constant: 4.0),
            self.shortcutField.trailingAnchor.constraint(equalTo: self.shortcutContainer.trailingAnchor, constant: -12.0),
            self.shortcutField.topAnchor.constraint(equalTo: self.shortcutContainer.topAnchor),
            self.shortcutField.bottomAnchor.constraint(equalTo: self.shortcutContainer.bottomAnchor),

            self.textView.leadingAnchor.constraint(equalTo: self.inputContainer.leadingAnchor),
            self.textView.trailingAnchor.constraint(equalTo: self.inputContainer.trailingAnchor),
            self.textView.topAnchor.constraint(equalTo: self.inputContainer.topAnchor),
            self.textView.bottomAnchor.constraint(equalTo: self.inputContainer.bottomAnchor),

            self.placeholderLabel.leadingAnchor.constraint(equalTo: self.inputContainer.leadingAnchor, constant: 12.0),
            self.placeholderLabel.trailingAnchor.constraint(equalTo: self.inputContainer.trailingAnchor, constant: -12.0),
            self.placeholderLabel.topAnchor.constraint(equalTo: self.inputContainer.topAnchor, constant: 10.0),

            self.mediaImageView.leadingAnchor.constraint(equalTo: self.mediaContainer.leadingAnchor),
            self.mediaImageView.trailingAnchor.constraint(equalTo: self.mediaContainer.trailingAnchor),
            self.mediaImageView.topAnchor.constraint(equalTo: self.mediaContainer.topAnchor),
            self.mediaImageView.bottomAnchor.constraint(equalTo: self.mediaContainer.bottomAnchor),

            self.mediaVideoIconBackground.centerXAnchor.constraint(equalTo: self.mediaContainer.centerXAnchor),
            self.mediaVideoIconBackground.centerYAnchor.constraint(equalTo: self.mediaContainer.centerYAnchor),
            self.mediaVideoIconBackground.widthAnchor.constraint(equalToConstant: 54.0),
            self.mediaVideoIconBackground.heightAnchor.constraint(equalToConstant: 54.0),

            self.mediaVideoIconView.centerXAnchor.constraint(equalTo: self.mediaVideoIconBackground.centerXAnchor, constant: 2.0),
            self.mediaVideoIconView.centerYAnchor.constraint(equalTo: self.mediaVideoIconBackground.centerYAnchor),
            self.mediaVideoIconView.widthAnchor.constraint(equalToConstant: 24.0),
            self.mediaVideoIconView.heightAnchor.constraint(equalToConstant: 24.0),

            self.mediaLabel.leadingAnchor.constraint(equalTo: self.mediaContainer.leadingAnchor),
            self.mediaLabel.trailingAnchor.constraint(equalTo: self.mediaContainer.trailingAnchor),
            self.mediaLabel.bottomAnchor.constraint(equalTo: self.mediaContainer.bottomAnchor),
            self.mediaLabel.heightAnchor.constraint(equalToConstant: 30.0),

            self.removeMediaButton.topAnchor.constraint(equalTo: self.mediaContainer.topAnchor, constant: 10.0),
            self.removeMediaButton.trailingAnchor.constraint(equalTo: self.mediaContainer.trailingAnchor, constant: -10.0),
            self.removeMediaButton.widthAnchor.constraint(equalToConstant: 32.0),
            self.removeMediaButton.heightAnchor.constraint(equalToConstant: 32.0)
        ])

        self.updateMediaUI()
        self.updateSaveState()

        self.cardView.alpha = 0.0
        self.cardView.transform = CGAffineTransform(translationX: 0.0, y: 36.0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.updateCardHeight()
    }

    private func updateCardHeight() {
        guard self.bounds.width > 0.0, self.cardView.bounds.width > 0.0 else {
            return
        }
        let keyboardTop = self.keyboardLayoutGuide.layoutFrame.minY
        let maxHeight = max(240.0, keyboardTop - self.safeAreaInsets.top - 36.0)
        let fittingSize = CGSize(width: max(180.0, self.scrollView.bounds.width), height: 0.0)
        let contentHeight = self.contentStack.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height + 36.0
        let target = min(contentHeight, maxHeight)
        if abs(self.cardHeightConstraint.constant - target) > 0.5 {
            self.cardHeightConstraint.constant = target
            self.setNeedsLayout()
        }
    }

    func present(in parent: UIView) {
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            self.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            self.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            self.topAnchor.constraint(equalTo: parent.topAnchor),
            self.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
        parent.layoutIfNeeded()
        UIView.animate(withDuration: 0.28, delay: 0.0, options: [.curveEaseOut], animations: {
            self.dimView.alpha = 1.0
            self.cardView.alpha = 1.0
            self.cardView.transform = .identity
        }, completion: nil)
        DispatchQueue.main.async {
            if self.shortcutField.text?.isEmpty ?? true {
                self.shortcutField.becomeFirstResponder()
            } else {
                self.textView.becomeFirstResponder()
            }
        }
    }

    private func dismissEditor() {
        self.shortcutField.resignFirstResponder()
        self.textView.resignFirstResponder()
        UIView.animate(withDuration: 0.22, delay: 0.0, options: [.curveEaseIn], animations: {
            self.dimView.alpha = 0.0
            self.cardView.alpha = 0.0
            self.cardView.transform = CGAffineTransform(translationX: 0.0, y: 30.0)
        }, completion: { _ in
            self.removeFromSuperview()
            self.onDismiss?()
        })
    }

    private func cleanupUncommittedMedia() {
        if !self.didCommit, let fileName = self.newlyCreatedMediaFileName {
            try? FileManager.default.removeItem(at: jokerQuickReplyMediaURL(fileName: fileName))
            self.newlyCreatedMediaFileName = nil
        }
    }

    func setMedia(media: JokerQuickReplyMedia?, preview: UIImage?, isNewlyCreated: Bool) {
        if isNewlyCreated, let previous = self.newlyCreatedMediaFileName, previous != media?.fileName {
            try? FileManager.default.removeItem(at: jokerQuickReplyMediaURL(fileName: previous))
        }
        self.newlyCreatedMediaFileName = isNewlyCreated ? media?.fileName : nil
        self.media = media
        self.mediaPreview = preview
        self.updateMediaUI()
        self.updateSaveState()
    }

    func updateMediaPreview(_ preview: UIImage?) {
        self.mediaPreview = preview
        if let preview = preview {
            self.mediaImageView.image = preview
        }
    }

    private func updateMediaUI() {
        let hasMedia = self.media != nil
        self.mediaContainer.isHidden = !hasMedia
        self.attachButton.updateTitle(hasMedia ? self.changeAttachTitle : self.attachTitle)
        self.mediaImageView.image = self.mediaPreview
        self.mediaVideoIconBackground.isHidden = !(self.media?.isVideo ?? false)
        if let media = self.media {
            self.mediaLabel.text = media.isVideo ? self.videoTitle : self.imageTitle
        } else {
            self.mediaLabel.text = nil
        }
        self.placeholderLabel.text = hasMedia ? self.mediaPlaceholderText : self.placeholderText
        self.setNeedsLayout()
    }

    private func updateSaveState() {
        let shortcut = jokerNormalizedQuickReplyShortcut(self.shortcutField.text ?? "")
        let hasText = !self.textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isValid = !shortcut.isEmpty && (hasText || self.media != nil)
        self.saveButton.isEnabled = isValid
        self.saveButton.alpha = isValid ? 1.0 : 0.45
    }

    private func showError(_ text: String) {
        self.errorLabel.text = text
        self.errorLabel.isHidden = text.isEmpty
        self.setNeedsLayout()
    }

    @objc private func shortcutChanged() {
        self.showError("")
        self.updateSaveState()
    }

    @objc private func dimTapped() {
        self.cleanupUncommittedMedia()
        self.dismissEditor()
    }

    @objc private func cancelTapped() {
        self.cleanupUncommittedMedia()
        self.dismissEditor()
    }

    @objc private func saveTapped() {
        let shortcut = jokerNormalizedQuickReplyShortcut(self.shortcutField.text ?? "")
        if shortcut.isEmpty {
            self.showError(jokerLocalize(sample: self.titleLabel.text ?? "", arValue: "أدخل اختصارًا من دون مسافات.", enValue: "Enter a shortcut without spaces."))
            return
        }
        let text = self.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty && self.media == nil {
            self.showError(jokerLocalize(sample: self.titleLabel.text ?? "", arValue: "اكتب نص الرد أو أرفق صورة أو فيديو.", enValue: "Write a reply or attach a photo or video."))
            return
        }
        let draft = JokerQuickReplyDraft(shortcut: shortcut, text: text, media: self.media, mediaPreview: self.mediaPreview)
        if self.onSave?(draft) == true {
            self.didCommit = true
            self.newlyCreatedMediaFileName = nil
            self.dismissEditor()
        }
    }

    @objc private func attachTapped() {
        self.onAttachMedia?()
    }

    @objc private func removeMediaTapped() {
        if let fileName = self.newlyCreatedMediaFileName {
            try? FileManager.default.removeItem(at: jokerQuickReplyMediaURL(fileName: fileName))
            self.newlyCreatedMediaFileName = nil
        }
        self.media = nil
        self.mediaPreview = nil
        self.updateMediaUI()
        self.updateSaveState()
    }

    func textViewDidChange(_ textView: UITextView) {
        self.showError("")
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.updateSaveState()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.textView.becomeFirstResponder()
        return false
    }
}

public final class JokerLocalQuickRepliesController: ViewController {
    private let context: AccountContext
    private var replies: [JokerQuickReply] = []
    private var isRTL = false
    private var currentEditor: JokerQuickReplyEditorView?

    private let headerView = UIView()
    private let headerSeparator = UIView()
    private let backButton = UIButton(type: .system)
    private let addHeaderButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = UIView()
    private let emptyIconBackground = UIView()
    private let emptyIconView = UIImageView()
    private let emptyTitleLabel = UILabel()
    private let emptySubtitleLabel = UILabel()
    private let emptyActionButton = UIButton(type: .system)
    private let floatingButton = UIButton(type: .system)

    public init(context: AccountContext) {
        self.context = context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        self.displayNavigationBar = false
        self.isRTL = presentationData.strings.baseLanguageCode.hasPrefix("ar")
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let theme = presentationData.theme

        self.view.backgroundColor = theme.list.blocksBackgroundColor
        self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.backgroundColor = .clear
        self.tableView.separatorStyle = .none
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.contentInset = UIEdgeInsets(top: 6.0, left: 0.0, bottom: 110.0, right: 0.0)
        self.tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 100.0, right: 0.0)
        self.tableView.register(JokerQuickReplyCell.self, forCellReuseIdentifier: "reply")
        self.view.addSubview(self.tableView)

        self.headerSeparator.backgroundColor = theme.list.itemPlainSeparatorColor.withAlphaComponent(0.45)
        self.headerView.addSubview(self.headerSeparator)

        self.titleLabel.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "الردود السريعة", enValue: "Quick Replies")
        self.titleLabel.font = Font.semibold(20.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.titleLabel.textAlignment = self.isRTL ? .right : .left
        self.headerView.addSubview(self.titleLabel)

        self.subtitleLabel.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "اكتب /الاختصار في الدردشة أو أرسلها من +", enValue: "Type /shortcut in chat or send from +")
        self.subtitleLabel.font = Font.regular(12.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.textAlignment = self.isRTL ? .right : .left
        self.headerView.addSubview(self.subtitleLabel)

        self.backButton.setImage(UIImage(systemName: self.isRTL ? "chevron.right" : "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18.0, weight: .semibold)), for: .normal)
        self.backButton.tintColor = theme.list.itemPrimaryTextColor
        self.backButton.backgroundColor = theme.list.itemPrimaryTextColor.withAlphaComponent(0.05)
        self.backButton.layer.cornerRadius = 22.0
        self.backButton.addTarget(self, action: #selector(self.goBack), for: .touchUpInside)
        self.backButton.accessibilityLabel = presentationData.strings.Common_Back
        self.headerView.addSubview(self.backButton)

        self.addHeaderButton.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19.0, weight: .semibold)), for: .normal)
        self.addHeaderButton.tintColor = .white
        self.addHeaderButton.backgroundColor = theme.list.itemAccentColor
        self.addHeaderButton.layer.cornerRadius = 22.0
        self.addHeaderButton.addTarget(self, action: #selector(self.addReplyTapped), for: .touchUpInside)
        self.addHeaderButton.accessibilityLabel = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "إضافة رد سريع", enValue: "Add Quick Reply")
        self.headerView.addSubview(self.addHeaderButton)

        self.view.addSubview(self.headerView)

        self.emptyIconBackground.backgroundColor = theme.list.itemAccentColor.withAlphaComponent(0.12)
        self.emptyIconBackground.layer.cornerRadius = 44.0
        self.emptyView.addSubview(self.emptyIconBackground)

        self.emptyIconView.image = UIImage(systemName: "bolt.horizontal.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 40.0, weight: .regular))?.withTintColor(theme.list.itemAccentColor, renderingMode: .alwaysOriginal)
        self.emptyIconView.contentMode = .scaleAspectFit
        self.emptyIconBackground.addSubview(self.emptyIconView)

        self.emptyTitleLabel.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "لا توجد ردود سريعة بعد", enValue: "No quick replies yet")
        self.emptyTitleLabel.font = Font.semibold(20.0)
        self.emptyTitleLabel.textColor = theme.list.itemPrimaryTextColor
        self.emptyTitleLabel.textAlignment = .center
        self.emptyView.addSubview(self.emptyTitleLabel)

        self.emptySubtitleLabel.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "أضف اختصارًا ونصًا أو صورة ليتم إرسالها فورًا من الدردشة.", enValue: "Add a shortcut with text or media and send it instantly from chat.")
        self.emptySubtitleLabel.font = Font.regular(15.0)
        self.emptySubtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.emptySubtitleLabel.textAlignment = .center
        self.emptySubtitleLabel.numberOfLines = 2
        self.emptyView.addSubview(self.emptySubtitleLabel)

        self.emptyActionButton.setTitle(jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "إضافة رد سريع", enValue: "Add Quick Reply"), for: .normal)
        self.emptyActionButton.setTitleColor(.white, for: .normal)
        self.emptyActionButton.titleLabel?.font = Font.semibold(16.0)
        self.emptyActionButton.backgroundColor = theme.list.itemAccentColor
        self.emptyActionButton.layer.cornerRadius = 24.0
        self.emptyActionButton.addTarget(self, action: #selector(self.addReplyTapped), for: .touchUpInside)
        self.emptyView.addSubview(self.emptyActionButton)

        self.view.addSubview(self.emptyView)

        self.floatingButton.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24.0, weight: .semibold)), for: .normal)
        self.floatingButton.tintColor = .white
        self.floatingButton.backgroundColor = theme.list.itemAccentColor
        self.floatingButton.layer.cornerRadius = 29.0
        self.floatingButton.layer.shadowColor = UIColor.black.cgColor
        self.floatingButton.layer.shadowOpacity = 0.22
        self.floatingButton.layer.shadowRadius = 12.0
        self.floatingButton.layer.shadowOffset = CGSize(width: 0.0, height: 6.0)
        self.floatingButton.addTarget(self, action: #selector(self.addReplyTapped), for: .touchUpInside)
        self.floatingButton.accessibilityLabel = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "إضافة رد سريع", enValue: "Add Quick Reply")
        self.view.addSubview(self.floatingButton)

        self.reloadReplies()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = self.view.bounds
        let safeTop = self.view.safeAreaInsets.top
        let safeBottom = self.view.safeAreaInsets.bottom
        let safeLeft = self.view.safeAreaInsets.left
        let safeRight = self.view.safeAreaInsets.right
        let headerContentHeight: CGFloat = 66.0
        let headerHeight = safeTop + headerContentHeight

        self.headerView.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: headerHeight)
        self.headerSeparator.frame = CGRect(x: 0.0, y: headerHeight - 0.5, width: bounds.width, height: 0.5)

        let sideInset: CGFloat = 8.0
        let buttonSize: CGFloat = 44.0
        let backX = self.isRTL ? bounds.width - safeRight - sideInset - buttonSize : safeLeft + sideInset
        let addX = self.isRTL ? safeLeft + sideInset : bounds.width - safeRight - sideInset - buttonSize
        self.backButton.frame = CGRect(x: backX, y: safeTop + 11.0, width: buttonSize, height: buttonSize)
        self.addHeaderButton.frame = CGRect(x: addX, y: safeTop + 11.0, width: buttonSize, height: buttonSize)

        let textInset: CGFloat = buttonSize + sideInset + 12.0
        self.titleLabel.frame = CGRect(x: textInset, y: safeTop + 10.0, width: max(0.0, bounds.width - textInset * 2.0), height: 26.0)
        self.subtitleLabel.frame = CGRect(x: textInset, y: safeTop + 37.0, width: max(0.0, bounds.width - textInset * 2.0), height: 16.0)

        let contentFrame = CGRect(x: 0.0, y: headerHeight, width: bounds.width, height: max(0.0, bounds.height - headerHeight))
        self.tableView.frame = contentFrame
        self.emptyView.frame = contentFrame

        let emptyBounds = self.emptyView.bounds
        let iconSize: CGFloat = 88.0
        var offsetY = emptyBounds.midY - 128.0
        self.emptyIconBackground.frame = CGRect(x: (emptyBounds.width - iconSize) / 2.0, y: offsetY, width: iconSize, height: iconSize)
        self.emptyIconView.frame = self.emptyIconBackground.bounds.insetBy(dx: 24.0, dy: 24.0)
        offsetY += iconSize + 18.0
        self.emptyTitleLabel.frame = CGRect(x: 24.0, y: offsetY, width: emptyBounds.width - 48.0, height: 28.0)
        offsetY += 28.0 + 8.0
        self.emptySubtitleLabel.frame = CGRect(x: 36.0, y: offsetY, width: emptyBounds.width - 72.0, height: 42.0)
        offsetY += 42.0 + 24.0
        let actionWidth: CGFloat = 210.0
        self.emptyActionButton.frame = CGRect(x: (emptyBounds.width - actionWidth) / 2.0, y: offsetY, width: actionWidth, height: 48.0)

        let floatingSize: CGFloat = 58.0
        let floatingX = self.isRTL ? safeLeft + 20.0 : bounds.width - safeRight - 20.0 - floatingSize
        let floatingY = bounds.height - safeBottom - 22.0 - floatingSize
        self.floatingButton.frame = CGRect(x: floatingX, y: floatingY, width: floatingSize, height: floatingSize)
    }

    private func reloadReplies() {
        self.replies = getJokerLocalQuickReplies()
        self.tableView.reloadData()
        let isEmpty = self.replies.isEmpty
        self.emptyView.isHidden = !isEmpty
        self.floatingButton.isHidden = isEmpty
        self.view.setNeedsLayout()
    }

    @objc private func goBack() {
        if let navigationController = self.navigationController, navigationController.viewControllers.contains(where: { $0 === self }) {
            _ = navigationController.popViewController(animated: true)
            return
        }
        if let navigationController = self.navigationController {
            navigationController.dismiss(animated: true)
            return
        }
        self.dismiss(animated: true)
    }

    @objc private func addReplyTapped() {
        self.presentEditor(nil)
    }

    private func presentEditor(_ reply: JokerQuickReply?) {
        if let currentEditor = self.currentEditor {
            currentEditor.removeFromSuperview()
            self.currentEditor = nil
        }

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let title: String
        if reply == nil {
            title = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "رد سريع جديد", enValue: "New Quick Reply")
        } else {
            title = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "تعديل الرد السريع", enValue: "Edit Quick Reply")
        }
        let placeholder = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "اكتب نص الرد هنا…", enValue: "Write your reply here…")
        let mediaPlaceholder = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "أضف تعليقًا اختياريًا…", enValue: "Add an optional caption…")
        let attachTitle = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "إرفاق صورة أو فيديو", enValue: "Attach a photo or video")
        let changeAttachTitle = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "تغيير الصورة أو الفيديو", enValue: "Change the photo or video")
        let imageTitle = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "صورة", enValue: "Photo")
        let videoTitle = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "فيديو", enValue: "Video")
        let mediaPreview: UIImage?
        if let media = reply?.media, !media.isVideo {
            mediaPreview = UIImage(contentsOfFile: jokerQuickReplyMediaURL(fileName: media.fileName).path)
        } else {
            mediaPreview = nil
        }

        let editor = JokerQuickReplyEditorView(
            theme: presentationData.theme,
            title: title,
            shortcut: reply?.shortcut ?? "",
            text: reply?.text ?? "",
            media: reply?.media,
            mediaPreview: mediaPreview,
            placeholder: placeholder,
            mediaPlaceholder: mediaPlaceholder,
            attachTitle: attachTitle,
            changeAttachTitle: changeAttachTitle,
            imageTitle: imageTitle,
            videoTitle: videoTitle,
            cancelTitle: presentationData.strings.Common_Cancel,
            saveTitle: presentationData.strings.Common_Save,
            isRTL: self.isRTL
        )
        editor.onSave = { [weak self] draft in
            guard let self else {
                return false
            }
            var replies = getJokerLocalQuickReplies()
            let normalized = draft.shortcut.lowercased()
            let isDuplicate = replies.contains(where: { item in
                if let reply, item.id == reply.id {
                    return false
                }
                guard let shortcut = item.shortcut else {
                    return false
                }
                return jokerNormalizedQuickReplyShortcut(shortcut).lowercased() == normalized
            })
            if isDuplicate {
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                let alert = UIAlertController(
                    title: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "اختصار مستخدم", enValue: "Shortcut in Use"),
                    message: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "يوجد رد سريع آخر يستخدم هذا الاختصار. اختر اختصارًا مختلفًا.", enValue: "Another quick reply already uses this shortcut. Choose a different one."),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: presentationData.strings.Common_OK, style: .default))
                self.present(alert, animated: true)
                return false
            }
            if let reply {
                replies = replies.map { item in
                    if item.id == reply.id {
                        return JokerQuickReply(id: item.id, text: draft.text, shortcut: draft.shortcut, media: draft.media)
                    }
                    return item
                }
            } else {
                replies.append(JokerQuickReply(id: UUID().uuidString, text: draft.text, shortcut: draft.shortcut, media: draft.media))
            }
            saveJokerLocalQuickReplies(replies)
            if let oldMedia = reply?.media, oldMedia.fileName != draft.media?.fileName {
                try? FileManager.default.removeItem(at: jokerQuickReplyMediaURL(fileName: oldMedia.fileName))
            }
            self.reloadReplies()
            return true
        }
        editor.onAttachMedia = { [weak self] in
            self?.presentMediaPicker()
        }
        editor.onDismiss = { [weak self] in
            self?.currentEditor = nil
        }
        self.currentEditor = editor
        editor.present(in: self.view)
    }

    private func presentMediaPicker() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.allowsEditing = false
        picker.delegate = self
        self.present(picker, animated: true)
    }

    private func showMediaError(title: String, message: String) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: presentationData.strings.Common_OK, style: .default))
        self.present(alert, animated: true)
    }

    private func confirmDelete(_ reply: JokerQuickReply) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let alert = UIAlertController(
            title: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "حذف الرد السريع", enValue: "Delete Quick Reply"),
            message: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "سيتم حذف هذا الرد من جهازك.", enValue: "This reply will be deleted from your device."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: presentationData.strings.Common_Cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: presentationData.strings.Common_Delete, style: .destructive) { [weak self] _ in
            guard let self else {
                return
            }
            let replies = getJokerLocalQuickReplies().filter { $0.id != reply.id }
            saveJokerLocalQuickReplies(replies)
            if let media = reply.media {
                try? FileManager.default.removeItem(at: jokerQuickReplyMediaURL(fileName: media.fileName))
            }
            self.reloadReplies()
        })
        self.present(alert, animated: true)
    }
}

extension JokerLocalQuickRepliesController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.replies.count
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 84.0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "reply", for: indexPath) as? JokerQuickReplyCell else {
            return UITableViewCell()
        }
        let reply = self.replies[indexPath.row]
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let fallbackTitle = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "رد سريع", enValue: "Quick Reply")
        let mediaTitle = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "مرفق وسائط", enValue: "Media attachment")
        cell.update(reply: reply, theme: presentationData.theme, isRTL: self.isRTL, fallbackTitle: fallbackTitle, mediaTitle: mediaTitle)
        cell.onDelete = { [weak self] in
            self?.confirmDelete(reply)
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard indexPath.row < self.replies.count else {
            return
        }
        self.presentEditor(self.replies[indexPath.row])
    }

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < self.replies.count else {
            return nil
        }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let reply = self.replies[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: presentationData.strings.Common_Delete) { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            self.confirmDelete(reply)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

extension JokerLocalQuickRepliesController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let editor = self.currentEditor else {
            return
        }

        if let videoURL = info[.mediaURL] as? URL {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? NSNumber)?.int64Value ?? 0
            if fileSize > 64 * 1024 * 1024 {
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                self.showMediaError(
                    title: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "الملف كبير جدًا", enValue: "File Is Too Large"),
                    message: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "اختر صورة أو فيديو أصغر من 64 ميجابايت.", enValue: "Choose a photo or video smaller than 64 MB.")
                )
                return
            }
            let pathExtension = videoURL.pathExtension.isEmpty ? "mp4" : videoURL.pathExtension.lowercased()
            let fileName = UUID().uuidString + "." + pathExtension
            let destinationURL = jokerQuickReplyMediaURL(fileName: fileName)
            do {
                try FileManager.default.copyItem(at: videoURL, to: destinationURL)
            } catch {
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                self.showMediaError(
                    title: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "تعذر إضافة الملف", enValue: "Could Not Add File"),
                    message: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "حدث خطأ أثناء نسخ الفيديو. حاول مرة أخرى.", enValue: "An error occurred while copying the video. Try again.")
                )
                return
            }
            let asset = AVURLAsset(url: destinationURL)
            let duration = max(0.0, asset.duration.seconds)
            var width: Int32 = 0
            var height: Int32 = 0
            if let track = asset.tracks(withMediaType: .video).first {
                let transformedSize = track.naturalSize.applying(track.preferredTransform)
                width = Int32(abs(transformedSize.width))
                height = Int32(abs(transformedSize.height))
            }
            let mimeType = pathExtension == "mov" ? "video/quicktime" : "video/mp4"
            let media = JokerQuickReplyMedia(fileName: fileName, isVideo: true, width: max(1, width), height: max(1, height), duration: duration, mimeType: mimeType)
            editor.setMedia(media: media, preview: nil, isNewlyCreated: true)

            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 640.0, height: 640.0)
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime(seconds: 0.0, preferredTimescale: 30))]) { [weak self] _, image, _, _, _ in
                guard let image = image else {
                    return
                }
                let preview = UIImage(cgImage: image)
                DispatchQueue.main.async {
                    guard let self, self.currentEditor?.mediaFileName == fileName else {
                        return
                    }
                    self.currentEditor?.updateMediaPreview(preview)
                }
            }
            return
        }

        guard let image = info[.originalImage] as? UIImage else {
            return
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            self.showMediaError(
                title: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "تعذر إضافة الصورة", enValue: "Could Not Add Photo"),
                message: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "حدث خطأ أثناء تجهيز الصورة. حاول مرة أخرى.", enValue: "An error occurred while preparing the photo. Try again.")
            )
            return
        }
        let fileName = UUID().uuidString + ".jpg"
        let destinationURL = jokerQuickReplyMediaURL(fileName: fileName)
        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            self.showMediaError(
                title: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "تعذر إضافة الصورة", enValue: "Could Not Add Photo"),
                message: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "حدث خطأ أثناء نسخ الصورة. حاول مرة أخرى.", enValue: "An error occurred while copying the photo. Try again.")
            )
            return
        }
        let pixelWidth = Int32(max(1.0, image.size.width * image.scale))
        let pixelHeight = Int32(max(1.0, image.size.height * image.scale))
        let media = JokerQuickReplyMedia(fileName: fileName, isVideo: false, width: pixelWidth, height: pixelHeight, duration: 0.0, mimeType: "image/jpeg")
        editor.setMedia(media: media, preview: image, isNewlyCreated: true)
    }
}
