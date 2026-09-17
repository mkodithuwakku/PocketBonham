import AVFoundation
import CryptoKit
import Foundation

public struct DecodedSample: Sendable {
  public var stereo: [Float]
  public var frames: Int
  public var rate: Double
}
public enum SampleDecoder {
  public static func decode(
    path: URL, instrument: Instrument, rate: Double, remainingBytes: Int = 192 * 1024 * 1024
  ) throws -> DecodedSample {
    guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else {
      throw BonhamError("Unsupported output sample rate.")
    }
    if let hash = instrument.sha256 {
      let actual = SHA256.hash(data: try Data(contentsOf: path)).map {
        String(format: "%02x", $0)
      }.joined()
      try require(hash == actual, "Asset hash differs from the manifest.")
    }
    let file = try AVAudioFile(forReading: path)
    let codec = file.fileFormat.streamDescription.pointee.mFormatID
    try require(
      codec == kAudioFormatLinearPCM || codec == kAudioFormatMPEGLayer3,
      "Only PCM WAV and MP3 samples are supported.")
    let inputFormat = file.processingFormat
    try require(
      (1...2).contains(inputFormat.channelCount)
        && [44100.0, 48000.0].contains(inputFormat.sampleRate),
      "Expected mono/stereo at 44.1 or 48 kHz.")
    try require(
      file.length > 0 && Double(file.length) / inputFormat.sampleRate <= 30,
      "Sample duration must be above zero and at most 30 seconds.")
    let start = AVAudioFramePosition(instrument.startFrame ?? 0)
    let end = AVAudioFramePosition(instrument.endFrame ?? Int(file.length))
    try require(
      start < end && end <= file.length, "Sample start/end metadata exceeds file length.")
    let frames = AVAudioFrameCount(end - start)
    guard let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frames) else {
      throw BonhamError("PCM allocation failed.")
    }
    file.framePosition = start
    try file.read(into: input, frameCount: frames)
    let capacity =
      AVAudioFrameCount(ceil(Double(frames) * rate / inputFormat.sampleRate)) + 64
    try require(
      Int(capacity) * 8 <= remainingBytes,
      "Required kits exceed the 192 MiB decoded sample budget. Shorten oversized assets.")
    guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity),
      let converter = AVAudioConverter(from: inputFormat, to: format)
    else { throw BonhamError("Sample conversion is unavailable.") }
    converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
    let feed = ConverterFeed(input: input)
    var conversionError: NSError?
    let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
      feed.provide(outStatus)
    }
    if let conversionError { throw conversionError }
    try require(
      status != .error && output.frameLength > 0, "Decoder produced no sound frames.")
    guard let channels = output.floatChannelData else {
      throw BonhamError("Expected Float PCM.")
    }
    var stereo = [Float](repeating: 0, count: Int(output.frameLength) * 2)
    for n in 0..<Int(output.frameLength) {
      for ch in 0..<2 {
        let value = channels[ch][n]
        try require(value.isFinite, "Nonfinite sample at frame \(n).")
        stereo[n * 2 + ch] = value
      }
    }

    return DecodedSample(stereo: stereo, frames: Int(output.frameLength), rate: rate)
  }
}

// AVAudioConverter may invoke its input block on a worker. This lock is confined to decoding,
// never used by the realtime source node, and protects the one-shot feed from repeat requests.
private final class ConverterFeed: @unchecked Sendable {
  let input: AVAudioPCMBuffer
  private let lock = NSLock()
  private var supplied = false
  init(input: AVAudioPCMBuffer) { self.input = input }
  func provide(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
    lock.lock()
    defer { lock.unlock() }
    guard !supplied else {
      status.pointee = .endOfStream
      return nil
    }
    supplied = true
    status.pointee = .haveData
    return input
  }
}
