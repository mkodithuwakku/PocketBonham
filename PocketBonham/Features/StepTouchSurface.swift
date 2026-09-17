import SwiftUI
import UIKit

/// Recognizes a hold before claiming a drag, leaving ordinary scrolling and taps intact.
struct StepTouchSurface: UIViewRepresentable {
  var label: String
  var identifier: String
  var tap: () -> Void
  var hold: () -> Void
  var drag: (CGFloat) -> Void
  var release: () -> Void
  var adjust: (Int) -> Void

  func makeUIView(context: Context) -> StepTouchView { StepTouchView() }
  func updateUIView(_ view: StepTouchView, context: Context) {
    view.accessibilityLabel = label
    view.accessibilityIdentifier = identifier
    view.accessibilityHint = "Tap to toggle. Hold an enabled note, then slide up or down to change velocity."
    view.actions = self
  }
  static func dismantleUIView(_ view: StepTouchView, coordinator: ()) {
    view.finishHold()
  }
}

final class StepTouchView: UIView {
  var actions: StepTouchSurface?
  private var originY: CGFloat = 0
  private var holding = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isAccessibilityElement = true
    accessibilityTraits = [.button, .adjustable]
    let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
    hold.minimumPressDuration = 0.35
    hold.allowableMovement = 12
    let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
    tap.require(toFail: hold)
    addGestureRecognizer(hold)
    addGestureRecognizer(tap)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  @objc private func tapped() { actions?.tap() }
  @objc private func held(_ recognizer: UILongPressGestureRecognizer) {
    // Window coordinates stay stable if the finger leaves the pad or the layout changes.
    switch recognizer.state {
    case .began:
      originY = recognizer.location(in: window).y
      holding = true
      actions?.hold()
      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    case .changed:
      if holding { actions?.drag(recognizer.location(in: window).y - originY) }
    case .ended, .cancelled, .failed:
      finishHold()
    default: break
    }
  }
  func finishHold() {
    guard holding else { return }
    holding = false
    actions?.release()
  }
  override func accessibilityActivate() -> Bool { actions?.tap(); return true }
  override func accessibilityIncrement() { actions?.adjust(5) }
  override func accessibilityDecrement() { actions?.adjust(-5) }
}
