import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

private final class JokerQuickReplyCell: UITableViewCell {
    let cardView = UIView()
    private let iconBackgroundView = UIView()
    private let iconView = UIImageView()
    private let textLabelView = UILabel()
    let deleteButton = UIButton(type: .system)
    private var isRTL = false
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

        self.textLabelView.numberOfLines = 0
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

    func update(reply: JokerQuickReply, theme: PresentationTheme, isRTL: Bool) {
        self.isRTL = isRTL
        self.cardView.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.iconBackgroundView.backgroundColor = theme.list.itemAccentColor.withAlphaComponent(0.14)
        self.iconView.image = UIImage(systemName: "bolt.fill")?.withTintColor(theme.list.itemAccentColor, renderingMode: .alwaysOriginal)
        self.textLabelView.text = reply.text
        self.textLabelView.textColor = theme.list.itemPrimaryTextColor
        self.textLabelView.font = Font.regular(16.0)
        self.textLabelView.textAlignment = isRTL ? .right : .left
        self.deleteButton.setImage(UIImage(systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15.0, weight: .medium)), for: .normal)
        self.deleteButton.tintColor = theme.list.itemSecondaryTextColor
        self.deleteButton.backgroundColor = theme.list.itemPrimaryTextColor.withAlphaComponent(0.05)
        self.deleteButton.layer.cornerRadius = 17.0
        self.textLabelView.semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
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
        self.iconView.frame = self.iconBackgroundView.bounds.insetBy(dx: 9.0, dy: 9.0)
        let deleteX = isRTL ? padding : bounds.width - padding - deleteSize
        self.deleteButton.frame = CGRect(x: deleteX, y: (bounds.height - deleteSize) / 2.0, width: deleteSize, height: deleteSize)
        let textX = isRTL ? padding + deleteSize + 6.0 : padding + iconSize + 12.0
        let textWidth = bounds.width - padding * 2.0 - iconSize - 12.0 - deleteSize - 6.0
        self.textLabelView.frame = CGRect(x: textX, y: 10.0, width: textWidth, height: bounds.height - 20.0)
    }

    static func height(for text: String, width: CGFloat) -> CGFloat {
        let cardWidth = width - 32.0
        let textWidth = cardWidth - 28.0 - 36.0 - 12.0 - 34.0 - 6.0
        let bounding = (text as NSString).boundingRect(with: CGSize(width: max(40.0, textWidth), height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: Font.regular(16.0)], context: nil)
        return max(66.0, ceil(bounding.height) + 20.0 + 10.0)
    }
}

private final class JokerQuickReplyEditorView: UIView, UITextViewDelegate {
    private let dimView = UIView()
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let inputContainer = UIView()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)

    var onCancel: (() -> Void)?
    var onSave: ((String) -> Void)?

    init(theme: PresentationTheme, title: String, text: String, placeholder: String, cancelTitle: String, saveTitle: String, isRTL: Bool) {
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

        self.titleLabel.text = title
        self.titleLabel.font = Font.semibold(18.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.titleLabel.textAlignment = isRTL ? .right : .left
        self.titleLabel.numberOfLines = 2

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
        self.saveButton.isEnabled = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.saveButton.alpha = self.saveButton.isEnabled ? 1.0 : 0.45

        let buttonsRow = UIStackView(arrangedSubviews: [self.cancelButton, self.saveButton])
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 10.0
        buttonsRow.distribution = .fillEqually
        buttonsRow.semanticContentAttribute = semantic

        let stackView = UIStackView(arrangedSubviews: [self.titleLabel, self.inputContainer, buttonsRow])
        stackView.axis = .vertical
        stackView.spacing = 14.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        self.cardView.addSubview(stackView)

        self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapped)))

        let cardBottom = self.cardView.bottomAnchor.constraint(equalTo: self.keyboardLayoutGuide.topAnchor, constant: -16.0)
        cardBottom.priority = UILayoutPriority(999.0)
        let cardWidth = self.cardView.widthAnchor.constraint(equalTo: self.widthAnchor, constant: -32.0)
        cardWidth.priority = UILayoutPriority(999.0)

        NSLayoutConstraint.activate([
            self.dimView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.dimView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.dimView.topAnchor.constraint(equalTo: self.topAnchor),
            self.dimView.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            self.cardView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.cardView.topAnchor.constraint(greaterThanOrEqualTo: self.safeAreaLayoutGuide.topAnchor, constant: 24.0),
            self.cardView.bottomAnchor.constraint(lessThanOrEqualTo: self.safeAreaLayoutGuide.bottomAnchor, constant: -16.0),
            self.cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 540.0),
            cardWidth,
            cardBottom,

            stackView.leadingAnchor.constraint(equalTo: self.cardView.leadingAnchor, constant: 18.0),
            stackView.trailingAnchor.constraint(equalTo: self.cardView.trailingAnchor, constant: -18.0),
            stackView.topAnchor.constraint(equalTo: self.cardView.topAnchor, constant: 18.0),
            stackView.bottomAnchor.constraint(equalTo: self.cardView.bottomAnchor, constant: -18.0),

            self.inputContainer.heightAnchor.constraint(equalToConstant: 132.0),
            buttonsRow.heightAnchor.constraint(equalToConstant: 48.0),

            self.textView.leadingAnchor.constraint(equalTo: self.inputContainer.leadingAnchor),
            self.textView.trailingAnchor.constraint(equalTo: self.inputContainer.trailingAnchor),
            self.textView.topAnchor.constraint(equalTo: self.inputContainer.topAnchor),
            self.textView.bottomAnchor.constraint(equalTo: self.inputContainer.bottomAnchor),

            self.placeholderLabel.leadingAnchor.constraint(equalTo: self.inputContainer.leadingAnchor, constant: 12.0),
            self.placeholderLabel.trailingAnchor.constraint(equalTo: self.inputContainer.trailingAnchor, constant: -12.0),
            self.placeholderLabel.topAnchor.constraint(equalTo: self.inputContainer.topAnchor, constant: 10.0)
        ])

        self.cardView.alpha = 0.0
        self.cardView.transform = CGAffineTransform(translationX: 0.0, y: 36.0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            self.textView.becomeFirstResponder()
        }
    }

    func dismissEditor() {
        self.textView.resignFirstResponder()
        UIView.animate(withDuration: 0.22, delay: 0.0, options: [.curveEaseIn], animations: {
            self.dimView.alpha = 0.0
            self.cardView.alpha = 0.0
            self.cardView.transform = CGAffineTransform(translationX: 0.0, y: 30.0)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    @objc private func dimTapped() {
        self.onCancel?()
    }

    @objc private func cancelTapped() {
        self.onCancel?()
    }

    @objc private func saveTapped() {
        let text = self.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        self.onSave?(text)
    }

    func textViewDidChange(_ textView: UITextView) {
        let isEmpty = textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.saveButton.isEnabled = !isEmpty
        self.saveButton.alpha = isEmpty ? 0.45 : 1.0
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

        self.subtitleLabel.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "جاهزة للإرسال من الدردشة عبر / أو +", enValue: "Ready to send from chat via / or +")
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

        self.emptySubtitleLabel.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "أضف ردودًا جاهزة لتصل إليها بسرعة من الدردشة.", enValue: "Add ready-made replies and reach them quickly from chat.")
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

        let editor = JokerQuickReplyEditorView(
            theme: presentationData.theme,
            title: title,
            text: reply?.text ?? "",
            placeholder: placeholder,
            cancelTitle: presentationData.strings.Common_Cancel,
            saveTitle: presentationData.strings.Common_Save,
            isRTL: self.isRTL
        )
        editor.onCancel = { [weak self] in
            guard let self else {
                return
            }
            self.currentEditor?.dismissEditor()
            self.currentEditor = nil
        }
        editor.onSave = { [weak self] text in
            guard let self else {
                return
            }
            var replies = getJokerLocalQuickReplies()
            if let reply {
                replies = replies.map { item in
                    if item.id == reply.id {
                        return JokerQuickReply(id: item.id, text: text)
                    }
                    return item
                }
            } else {
                replies.append(JokerQuickReply(id: UUID().uuidString, text: text))
            }
            saveJokerLocalQuickReplies(replies)
            self.currentEditor?.dismissEditor()
            self.currentEditor = nil
            self.reloadReplies()
        }
        self.currentEditor = editor
        editor.present(in: self.view)
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
        let reply = self.replies[indexPath.row]
        return JokerQuickReplyCell.height(for: reply.text, width: tableView.bounds.width)
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "reply", for: indexPath) as? JokerQuickReplyCell else {
            return UITableViewCell()
        }
        let reply = self.replies[indexPath.row]
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        cell.update(reply: reply, theme: presentationData.theme, isRTL: self.isRTL)
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
