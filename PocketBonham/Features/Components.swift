import BonhamCore
import SwiftUI
import UIKit

extension Color {
  static let casing = Color(red: 0.93, green: 0.91, blue: 0.86)
  static let ink = Color(red: 0.12, green: 0.17, blue: 0.16)
  static let signal = Color(red: 0.80, green: 0.27, blue: 0.12)
  static let moss = Color(red: 0.24, green: 0.39, blue: 0.33)
}
struct Panel<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 12) { content }.padding(16).frame(
      maxWidth: .infinity, alignment: .leading
    ).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18)).overlay(
      RoundedRectangle(cornerRadius: 18).stroke(Color.ink.opacity(0.08)))
  }
}
struct ValueControl: View {
  let title: String
  @Binding var value: Double
  var range: ClosedRange<Double>
  var step: Double = 1
  var suffix: String = ""
  var editing: (Bool) -> Void = { _ in }
  @State private var input = ""
  @State private var entering = false
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(title).font(.subheadline.weight(.semibold))
        Spacer()
        Button {
          input = String(format: step < 1 ? "%.2f" : "%.0f", value)
          entering = true
        } label: {
          Text(String(format: step < 1 ? "%.2f" : "%.0f", value) + suffix).monospacedDigit()
            .fontWeight(.bold).frame(minWidth: 60, minHeight: 44)
        }.accessibilityLabel("\(title), \(value), enter value")
      }
      Slider(value: $value, in: range, step: step, onEditingChanged: editing).accessibilityLabel(
        title)
    }
    .alert("Set \(title)", isPresented: $entering) {
      TextField(title, text: $input).keyboardType(.numbersAndPunctuation)
      Button("Set") {
        if let n = Double(input), n.isFinite, range.contains(n) {
          editing(true)
          value = (n / step).rounded() * step
          editing(false)
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("\(range.lowerBound.formatted())–\(range.upperBound.formatted())")
    }
  }
}
struct TransportView: View {
  @ObservedObject var store: AppStore
  @ObservedObject var audio: AudioHost
  var chain: Bool
  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) {
        play
        if !chain { record }
        undo
        mixer
      }
      VStack(spacing: 4) {
        HStack {
          play
          if !chain { record }
        }
        HStack {
          undo
          mixer
        }
      }
    }
    .padding(.horizontal, 16).padding(.vertical, 10).background(
      Color.casing.shadow(color: .black.opacity(0.08), radius: 8, y: -3))
  }
  var play: some View {
    Button {
      if audio.running || audio.preparing { store.stop() } else { store.play(chainMode: chain) }
    } label: {
      Label(
        audio.preparing ? "Cancel" : audio.running ? "Stop" : "Play",
        systemImage: audio.running || audio.preparing ? "stop.fill" : "play.fill"
      ).font(.headline).frame(maxWidth: .infinity, minHeight: 50)
    }.buttonStyle(.borderedProminent).tint(.ink).disabled(
      !audio.running && !audio.preparing
        && (chain ? store.chainPlaybackIssue != nil : store.kit == nil)
    ).accessibilityIdentifier("transportPlay")
  }
  var record: some View {
    Button {
      store.toggleRecord()
    } label: {
      Image(systemName: store.recordArmed ? "record.circle.fill" : "record.circle").font(.title2)
        .frame(width: 46, height: 50)
    }.buttonStyle(.bordered).tint(store.recordArmed ? .red : .ink).disabled(
      audio.chainMode && audio.running
    ).accessibilityLabel(store.recordArmed ? "Disarm Record" : "Arm Record")
  }
  var undo: some View {
    Button {
      store.undo()
    } label: {
      Label("Undo", systemImage: "arrow.uturn.backward").font(.subheadline.weight(.semibold)).frame(
        minHeight: 50)
    }.buttonStyle(.bordered).disabled(!store.canUndo).accessibilityIdentifier("undo")
  }
  @State private var showMixer = false
  var mixer: some View {
    Button {
      showMixer = true
    } label: {
      Image(systemName: "slider.horizontal.3").frame(width: 44, height: 50)
    }.buttonStyle(.bordered).accessibilityLabel("Mixer").sheet(isPresented: $showMixer) {
      MixerView(store: store, audio: audio)
    }
  }
}
struct TouchPads: UIViewRepresentable {
  let labels: [String]
  let action: (Int, Double) -> Void
  func makeUIView(context: Context) -> PadSurface { PadSurface() }
  func updateUIView(_ view: PadSurface, context: Context) {
    view.labels = labels
    view.action = action
    view.rebuild()
  }
}
final class DrumButton: UIButton {
  var strike: ((Double) -> Void)?
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let t = touches.first { strike?(t.timestamp) }
    super.touchesBegan(touches, with: event)
  }
  override var isHighlighted: Bool {
    didSet {
      alpha = isHighlighted ? 0.6 : 1
      transform = isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
    }
  }
  override func accessibilityActivate() -> Bool {
    strike?(CACurrentMediaTime())
    return true
  }
}
final class PadSurface: UIView {
  var labels: [String] = []
  var action: ((Int, Double) -> Void)?
  private var buttons: [DrumButton] = []
  private weak var padScroll: UIScrollView?
  private var oldDelay = true
  private var oldCancel = true
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      padScroll?.delaysContentTouches = oldDelay
      padScroll?.canCancelContentTouches = oldCancel
      padScroll = nil
    } else {
      var ancestor = superview
      while let view = ancestor {
        if let scroll = view as? UIScrollView {
          padScroll = scroll
          oldDelay = scroll.delaysContentTouches
          oldCancel = scroll.canCancelContentTouches
          scroll.delaysContentTouches = false
          scroll.canCancelContentTouches = false
          break
        }
        ancestor = view.superview
      }
    }
  }
  override init(frame: CGRect) {
    super.init(frame: frame)
    isMultipleTouchEnabled = true
  }
  required init?(coder: NSCoder) { fatalError() }
  func rebuild() {
    if buttons.count != labels.count {
      buttons.forEach { $0.removeFromSuperview() }
      buttons = []
      for index in labels.indices {
        let b = DrumButton(type: .custom)
        b.isAccessibilityElement = true
        b.accessibilityTraits = .button
        b.isExclusiveTouch = false
        b.isMultipleTouchEnabled = true
        b.layer.cornerRadius = 14
        b.titleLabel?.font = .monospacedSystemFont(ofSize: 15, weight: .bold)
        b.titleLabel?.numberOfLines = 2
        b.titleLabel?.textAlignment = .center
        b.backgroundColor = UIColor(Color.ink)
        b.setTitleColor(UIColor(Color.casing), for: .normal)
        b.strike = { [weak self] timestamp in self?.action?(index, timestamp) }
        b.accessibilityIdentifier = "pad-\(index)"
        addSubview(b)
        buttons.append(b)
      }
    }
    for (index, b) in buttons.enumerated() {
      b.setTitle(labels[index], for: .normal)
      b.accessibilityLabel = "Play \(labels[index])"
      b.accessibilityHint = "Sounds on touch down. Records when armed after count-in."
    }
    setNeedsLayout()
  }
  override func layoutSubviews() {
    super.layoutSubviews()
    let w = (bounds.width - 10) / 2
    for (i, b) in buttons.enumerated() {
      b.frame = CGRect(x: CGFloat(i % 2) * (w + 10), y: CGFloat(i / 2) * 64, width: w, height: 56)
    }
  }
}
