import BonhamCore
import Foundation

@main struct KitValidator {
  static func main() {
    do {
      guard CommandLine.arguments.count == 2 else {
        throw BonhamError("Usage: bonham-validate-kit <manifest.json or Kits directory>")
      }
      let location = URL(fileURLWithPath: CommandLine.arguments[1])
      let manifests: [URL]
      if location.pathExtension == "json" {
        manifests = [location]
      } else {
        manifests =
          (FileManager.default.enumerator(at: location, includingPropertiesForKeys: nil)?.allObjects
          as? [URL] ?? []).filter { $0.lastPathComponent == "manifest.json" }.sorted {
            $0.path < $1.path
          }
      }
      try require(!manifests.isEmpty, "No kit manifests found.")
      var total = 0
      var ids = Set<String>()
      for url in manifests {
        let kit = try JSONDecoder().decode(Kit.self, from: Data(contentsOf: url))
        try kit.validate()
        try require(ids.insert(kit.id).inserted, "Duplicate kit ID: \(kit.id)")
        print(
          "\(kit.name) [\(kit.id), v\(kit.assetVersion)]\(kit.developmentFixture == true ? " — DEVELOPMENT FIXTURE":"")"
        )
        for i in kit.instruments.sorted(by: { $0.order < $1.order }) {
          do {
            let sample = try SampleDecoder.decode(
              path: url.deletingLastPathComponent().appendingPathComponent(i.file), instrument: i,
              rate: 48000, remainingBytes: 192 * 1024 * 1024 - total)
            total += sample.stereo.count * 4
            let first = stride(from: 0, to: sample.stereo.count, by: 2).first {
              abs(sample.stereo[$0]) > 0.0001 || abs(sample.stereo[$0 + 1]) > 0.0001
            }
            print(
              String(
                format: "  %@: %.3f s, %.0f ms to first >−80 dB sample; %@", i.id,
                Double(sample.frames) / 48000, Double((first ?? 0) / 2) / 48, i.file))
          } catch {
            throw BonhamError("\(kit.name) / \(i.name) / \(i.file): \(error.localizedDescription)")
          }
        }
      }
      print(
        String(
          format: "PASS: %d kit(s), %.2f / 192 MiB decoded stereo PCM at 48 kHz.", manifests.count,
          Double(total) / 1_048_576))
    } catch {
      fputs("Kit validation failed: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }
}
