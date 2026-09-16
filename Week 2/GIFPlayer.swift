import SwiftUI
import ImageIO
import UIKit

/// Each frame retains its original GIF duration, including variable frame delays.
struct GIFAnimation {
    let frames: [UIImage]
    let durations: [TimeInterval]

    init(url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var images: [UIImage] = []
        var delays: [TimeInterval] = []
        for index in 0..<CGImageSourceGetCount(source) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue ?? 0.1
            images.append(UIImage(cgImage: image))
            delays.append(delay > 0 ? delay : 0.1)
        }
        guard !images.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        frames = images
        durations = delays
    }
}

struct GIFPlayer: UIViewRepresentable {
    let animation: GIFAnimation
    let isPlaying: Bool

    func makeUIView(context: Context) -> GIFImageView {
        GIFImageView(animation: animation)
    }

    func updateUIView(_ view: GIFImageView, context: Context) {
        view.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ view: GIFImageView, coordinator: ()) {
        view.setPlaying(false)
    }
}

final class GIFImageView: UIImageView {
    private let animation: GIFAnimation
    private var displayLink: CADisplayLink?
    private var frameIndex = 0
    private var elapsed: TimeInterval = 0
    private var previousTimestamp: TimeInterval?
    private var requestedPlayback = false

    init(animation: GIFAnimation) {
        self.animation = animation
        super.init(frame: .zero)
        image = animation.frames.first
        contentMode = .scaleAspectFit
        backgroundColor = .white
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: CGSize { CGSize(width: 180, height: 180) }

    func setPlaying(_ playing: Bool) {
        requestedPlayback = playing
        updatePlayback()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updatePlayback()
    }

    private func updatePlayback() {
        guard requestedPlayback, window != nil, animation.frames.count > 1 else {
            displayLink?.invalidate()
            displayLink = nil
            previousTimestamp = nil
            return
        }
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy(owner: self)
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    fileprivate func advance(_ link: CADisplayLink) {
        defer { previousTimestamp = link.timestamp }
        guard let previousTimestamp else { return }
        elapsed += link.timestamp - previousTimestamp
        let cycleDuration = animation.durations.reduce(0, +)
        if elapsed >= cycleDuration { elapsed.formTruncatingRemainder(dividingBy: cycleDuration) }
        while elapsed >= animation.durations[frameIndex] {
            elapsed -= animation.durations[frameIndex]
            frameIndex = (frameIndex + 1) % animation.frames.count
        }
        image = animation.frames[frameIndex]
    }

    deinit { displayLink?.invalidate() }
}

/// CADisplayLink retains its target; this proxy keeps the image view releasable.
private final class DisplayLinkProxy {
    weak var owner: GIFImageView?
    init(owner: GIFImageView) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) { owner?.advance(link) }
}
