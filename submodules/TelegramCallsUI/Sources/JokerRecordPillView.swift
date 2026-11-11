import Foundation
import UIKit
import Display

// Joker Mod: a floating "recording" pill for call screens (private 1:1, group chats and channels).
// Idle: a small red circle button. Recording: expands into a red capsule showing a white stop
// square and the elapsed time (e.g. "0:07"), so the user knows the call is being recorded.
final class JokerRecordPillView: UIView {
    private let action: () -> Void

    private let iconView = UIImageView()
    private let label = UILabel()
    private let backgroundView = UIView()
    private var timer: Timer?
    private var startedAt: Date?
    private var isRecording = false

    private let capsuleHeight: CGFloat = 40.0
    private let circleSize: CGFloat = 40.0

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)

        self.addSubview(self.backgroundView)
        self.backgroundView.clipsToBounds = true
        self.backgroundView.layer.cornerRadius = self.circleSize / 2.0

        self.iconView.contentMode = .center
        self.backgroundView.addSubview(self.iconView)

        self.label.textColor = .white
        self.label.font = UIFont.monospacedDigitSystemFont(ofSize: 15.0, weight: .semibold)
        self.label.isHidden = true
        self.backgroundView.addSubview(self.label)

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
        self.addGestureRecognizer(tap)

        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true

        self.updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        self.action()
    }

    func setRecording(_ recording: Bool) {
        if self.isRecording == recording {
            return
        }
        self.isRecording = recording
        if recording {
            self.startedAt = Date()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true, block: { [weak self] _ in
                self?.updateAppearance()
            })
        } else {
            self.startedAt = nil
            self.timer?.invalidate()
            self.timer = nil
        }
        self.updateAppearance()
        self.setNeedsLayout()
    }

    private var elapsedText: String {
        guard let startedAt = self.startedAt else {
            return "0:00"
        }
        let elapsed = max(0, Int(Date().timeIntervalSince(startedAt)))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func makeIcon() -> UIImage? {
        let size = CGSize(width: 40.0, height: 40.0)
        return generateImage(size, opaque: false, rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            if self.isRecording {
                context.setFillColor(UIColor.white.cgColor)
                let square = CGSize(width: 15.0, height: 15.0)
                let frame = CGRect(origin: CGPoint(x: (size.width - square.width) / 2.0, y: (size.height - square.height) / 2.0), size: square)
                let path = UIBezierPath(roundedRect: frame, cornerRadius: 3.5)
                context.addPath(path.cgPath)
                context.fillPath(using: .normal)
            } else {
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(x: 12.0, y: 12.0, width: 16.0, height: 16.0))
            }
        })
    }

    private func updateAppearance() {
        self.iconView.image = self.makeIcon()
        if self.isRecording {
            self.label.text = self.elapsedText
            self.label.isHidden = false
            self.backgroundView.layer.cornerRadius = self.capsuleHeight / 2.0
        } else {
            self.label.text = ""
            self.label.isHidden = true
            self.backgroundView.layer.cornerRadius = self.circleSize / 2.0
        }
        self.backgroundView.backgroundColor = UIColor(rgb: 0xFF3B30)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.backgroundView.frame = self.bounds
        self.iconView.frame = CGRect(origin: .zero, size: CGSize(width: self.capsuleHeight, height: self.capsuleHeight))
        let labelWidth: CGFloat = 42.0
        let labelX = self.capsuleHeight + 2.0
        self.label.frame = CGRect(x: labelX, y: 0.0, width: labelWidth, height: self.capsuleHeight)
    }

    override var intrinsicContentSize: CGSize {
        if self.isRecording {
            return CGSize(width: self.capsuleHeight + 2.0 + 42.0, height: self.capsuleHeight)
        } else {
            return CGSize(width: self.circleSize, height: self.circleSize)
        }
    }

    override var bounds: CGRect {
        didSet {
            self.invalidateIntrinsicContentSize()
        }
    }
}
