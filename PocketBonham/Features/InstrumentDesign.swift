import SwiftUI

/// Static instrument surfaces; no animation or audio work is driven by the decoration.
struct InstrumentBackground: View {
  var body: some View {
    ZStack {
      LinearGradient(colors: [Color(red: 0.95, green: 0.91, blue: 0.81), .casing,
        Color(red: 0.82, green: 0.77, blue: 0.66)], startPoint: .topLeading, endPoint: .bottomTrailing)
      Canvas { context, size in
        var grain = Path()
        for y in stride(from: 0.0, to: size.height, by: 4) {
          grain.move(to: CGPoint(x: 0, y: y))
          grain.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(grain, with: .color(.white.opacity(0.13)), lineWidth: 0.5)
      }
      RoundedRectangle(cornerRadius: 34).strokeBorder(Color.walnut.opacity(0.28), lineWidth: 2)
        .padding(.horizontal, 9).padding(.vertical, 3)
      HStack {
        rail
        Spacer()
        rail
      }
    }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
  }
  private var rail: some View {
    LinearGradient(colors: [.walnut, Color(red: 0.43, green: 0.25, blue: 0.14), .walnut],
      startPoint: .leading, endPoint: .trailing)
      .frame(width: 9)
      .overlay(alignment: .trailing) { Color.brass.opacity(0.6).frame(width: 1) }
  }
}

struct ScrewHead: View {
  var body: some View {
    Circle().fill(LinearGradient(colors: [.brass, .ink.opacity(0.75)],
      startPoint: .topLeading, endPoint: .bottomTrailing))
      .frame(width: 6, height: 6)
      .overlay { Rectangle().fill(Color.ink.opacity(0.8)).frame(width: 4, height: 1).rotationEffect(.degrees(-35)) }
      .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
      .accessibilityHidden(true)
  }
}

struct KeycapSurface: View {
  var enabled: Bool
  var playing: Bool
  var selected: Bool
  var body: some View {
    RoundedRectangle(cornerRadius: 9)
      .fill(LinearGradient(colors: enabled
        ? [Color(red: 0.85, green: 0.36, blue: 0.16), .signal]
        : [Color(red: 1, green: 0.98, blue: 0.9), Color(red: 0.84, green: 0.80, blue: 0.70)],
        startPoint: .top, endPoint: .bottom))
      .overlay {
        RoundedRectangle(cornerRadius: 9).strokeBorder(
          playing ? Color.ink : selected ? Color.brass : Color.ink.opacity(0.18),
          lineWidth: playing ? 2.5 : 1)
      }
      .overlay(alignment: .top) {
        RoundedRectangle(cornerRadius: 1).fill(.white.opacity(enabled ? 0.25 : 0.8))
          .frame(height: 1).padding(.horizontal, 7).padding(.top, 2)
      }
      .shadow(color: Color.walnut.opacity(0.3), radius: 0, y: 3)
      .shadow(color: .black.opacity(0.08), radius: 2, y: 4)
  }
}

private struct InstrumentGlass: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  var radius: CGFloat
  @ViewBuilder func body(content: Content) -> some View {
    if reduceTransparency {
      content.background(Color.casing, in: RoundedRectangle(cornerRadius: radius))
        .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(Color.ink.opacity(0.25)) }
    } else if #available(iOS 26.0, *) {
      content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
    } else {
      content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
        .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.65)) }
    }
  }
}
extension View {
  func instrumentGlass(radius: CGFloat = 18) -> some View {
    modifier(InstrumentGlass(radius: radius))
  }
}

struct SpeakerGrille: View {
  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<8, id: \.self) { _ in
        Capsule().fill(Color.ink.opacity(0.6))
          .shadow(color: .white.opacity(0.7), radius: 0, y: 1)
      }
    }.accessibilityHidden(true)
  }
}

struct VelocityFader: View {
  let name: String
  let step: Int
  let level: Int
  var body: some View {
    VStack(spacing: 5) {
      Text(name.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced))
        .lineLimit(1).minimumScaleFactor(0.6)
      Text("STEP \(String(format: "%02d", step))").font(.system(size: 9, design: .monospaced))
      Text("\(level)").font(.system(size: 25, weight: .medium, design: .monospaced))
        .foregroundStyle(Color.amber).frame(maxWidth: .infinity)
        .background(Color.ink, in: RoundedRectangle(cornerRadius: 5))
      GeometryReader { proxy in
        let travel = proxy.size.height - 16
        ZStack(alignment: .top) {
          HStack {
            VStack {
              ForEach(0..<9, id: \.self) { i in
                Rectangle().fill(Color.brass).frame(width: i % 2 == 0 ? 12 : 6, height: 1)
                if i < 8 { Spacer() }
              }
            }
            Spacer()
          }.padding(.vertical, 8)
          Capsule().fill(Color.ink).frame(width: 7).padding(.vertical, 8)
          Capsule().fill(Color.signal).frame(width: 3, height: max(1, travel * CGFloat(level - 1) / 126))
            .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 8)
          RoundedRectangle(cornerRadius: 3)
            .fill(LinearGradient(colors: [.white, .casing, .brass], startPoint: .top, endPoint: .bottom))
            .frame(width: 36, height: 16)
            .overlay { Rectangle().fill(Color.signal).frame(height: 2).padding(.horizontal, 3) }
            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            .offset(y: travel * (1 - CGFloat(level - 1) / 126))
        }
      }
      Text("VELOCITY").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
    }.padding(10).foregroundStyle(Color.ink)
      .background(Color.casing, in: RoundedRectangle(cornerRadius: 13))
      .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(Color.brass, lineWidth: 1.5) }
      .shadow(color: Color.ink.opacity(0.35), radius: 10, y: 5)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(name), step \(step), velocity \(level)")
      .accessibilityIdentifier("velocityFader")
  }
}
