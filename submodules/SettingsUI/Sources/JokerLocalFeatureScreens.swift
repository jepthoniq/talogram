import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

public final class JokerLocalQuickRepliesController: ViewController {
    private let context: AccountContext
    private let tableView: UITableView
    private var replies: [JokerQuickReply] = []

    public init(context: AccountContext) {
        self.context = context
        self.tableView = UITableView(frame: .zero, style: .insetGrouped)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        self.title = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "ردود سريعة محلية", enValue: "Local Quick Replies")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addReply))
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.view.backgroundColor = presentationData.theme.list.plainBackgroundColor

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.backgroundColor = .clear
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.separatorInset = .zero
        self.view.addSubview(self.tableView)

        self.reloadData()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.tableView.frame = self.view.bounds
    }

    private func reloadData() {
        self.replies = getJokerLocalQuickReplies()
        self.tableView.reloadData()
    }

    @objc private func addReply() {
        self.presentReplyEditor(nil)
    }

    private func presentReplyEditor(_ reply: JokerQuickReply?) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let title = reply == nil
            ? jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "إضافة رد سريع", enValue: "Add Quick Reply")
            : jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "تعديل رد سريع", enValue: "Edit Quick Reply")

        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "اكتب الرد هنا", enValue: "Type your reply here")
            textField.text = reply?.text ?? ""
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
        }

        let cancel = UIAlertAction(title: presentationData.strings.Common_Cancel, style: .cancel)
        let save = UIAlertAction(title: presentationData.strings.Common_Save, style: .default) { [weak self, weak alert] _ in
            guard let self, let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return
            }
            var replies = getJokerLocalQuickReplies()
            if let reply {
                replies = replies.map { $0.id == reply.id ? JokerQuickReply(id: reply.id, text: text) : $0 }
            } else {
                replies.append(JokerQuickReply(id: UUID().uuidString, text: text))
            }
            saveJokerLocalQuickReplies(replies)
            self.reloadData()
        }

        alert.addAction(cancel)
        alert.addAction(save)
        self.present(alert, animated: true)
    }

    private func deleteReply(at indexPath: IndexPath) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let reply = self.replies[indexPath.row]
        let alert = UIAlertController(title: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "حذف الرد السريع", enValue: "Delete Quick Reply"), message: jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "هل أنت متأكد من حذف هذا الرد؟", enValue: "Are you sure you want to delete this quick reply?"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: presentationData.strings.Common_Cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: presentationData.strings.Common_Delete, style: .destructive) { [weak self] _ in
            guard let self else { return }
            let replies = getJokerLocalQuickReplies().filter { $0.id != reply.id }
            saveJokerLocalQuickReplies(replies)
            self.reloadData()
        })
        self.present(alert, animated: true)
    }
}

extension JokerLocalQuickRepliesController: UITableViewDataSource, UITableViewDelegate {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.replies.isEmpty ? 1 : self.replies.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

        if self.replies.isEmpty {
            var config = cell.defaultContentConfiguration()
            config.text = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "لا توجد ردود سريعة بعد.\nاضغط + لإضافة رد.", enValue: "No quick replies yet.\nTap + to add one.")
            config.textProperties.alignment = .center
            config.textProperties.color = presentationData.theme.list.itemSecondaryTextColor
            config.textProperties.numberOfLines = 0
            cell.contentConfiguration = config
            var bg = UIBackgroundConfiguration.listPlainCell()
            bg.backgroundColor = .clear
            cell.backgroundConfiguration = bg
            cell.selectionStyle = .none
            cell.accessoryType = .none
        } else {
            let reply = self.replies[indexPath.row]
            var config = cell.defaultContentConfiguration()
            config.text = reply.text
            config.textProperties.numberOfLines = 0
            config.textProperties.color = presentationData.theme.list.itemPrimaryTextColor
            config.secondaryText = jokerLocalize(sample: presentationData.strings.Common_Back, arValue: "اضغط للتعديل أو المسح من اليسار", enValue: "Tap to edit, swipe to delete")
            config.secondaryTextProperties.color = presentationData.theme.list.itemSecondaryTextColor
            config.secondaryTextProperties.numberOfLines = 1
            config.image = UIImage(systemName: "bolt.fill")?.withTintColor(presentationData.theme.list.itemAccentColor, renderingMode: .alwaysOriginal)
            cell.contentConfiguration = config
            var bg = UIBackgroundConfiguration.listGroupedCell()
            bg.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            bg.cornerRadius = 12
            cell.backgroundConfiguration = bg
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !self.replies.isEmpty else { return }
        self.presentReplyEditor(self.replies[indexPath.row])
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !self.replies.isEmpty
    }

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !self.replies.isEmpty else { return nil }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let delete = UIContextualAction(style: .destructive, title: presentationData.strings.Common_Delete) { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            self.deleteReply(at: indexPath)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
