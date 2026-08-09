import AppKit

let canvas: CGFloat = 1024
let pixels = Int(canvas)

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xff) / 255
        let green = CGFloat((hex >> 8) & 0xff) / 255
        let blue = CGFloat(hex & 0xff) / 255
        self.init(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }
}

func rounded(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fillRounded(_ rect: CGRect, radius: CGFloat, _ color: NSColor) {
    color.setFill()
    rounded(rect, radius: radius).fill()
}

func strokeRounded(_ rect: CGRect, radius: CGFloat, _ color: NSColor, width: CGFloat) {
    let path = rounded(rect, radius: radius)
    path.lineWidth = width
    color.setStroke()
    path.stroke()
}

func strokePath(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
}

func withShadow(color: NSColor = NSColor(hex: 0x0C2230, alpha: 0.16), blur: CGFloat, offset: CGSize, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = offset
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func drawPulseLink() {
    withShadow(color: NSColor(hex: 0x10AFC3, alpha: 0.14), blur: 14, offset: CGSize(width: 0, height: -5)) {
        fillRounded(CGRect(x: 398, y: 498, width: 28, height: 28), radius: 14, NSColor(hex: 0x16B8C9))
        fillRounded(CGRect(x: 446, y: 495, width: 34, height: 34), radius: 17, NSColor(hex: 0x48D1B5))
        fillRounded(CGRect(x: 500, y: 498, width: 28, height: 28), radius: 14, NSColor(hex: 0x2F6BFF, alpha: 0.86))
    }

    fillRounded(CGRect(x: 407, y: 507, width: 10, height: 10), radius: 5, .white)
    fillRounded(CGRect(x: 457, y: 506, width: 12, height: 12), radius: 6, .white)
    fillRounded(CGRect(x: 509, y: 507, width: 10, height: 10), radius: 5, .white)
}

func drawWatch() {
    let ink = NSColor(hex: 0x10222E)
    let glass = NSColor(hex: 0xF8FEFF)
    let strap = NSColor(hex: 0xAEE8E3)

    NSGraphicsContext.saveGraphicsState()
    let offset = NSAffineTransform()
    offset.translateX(by: -20, yBy: 0)
    offset.concat()

    let scale = NSAffineTransform()
    scale.translateX(by: 255, yBy: 512)
    scale.scale(by: 0.92)
    scale.translateX(by: -255, yBy: -512)
    scale.concat()

    fillRounded(CGRect(x: 186, y: 212, width: 124, height: 600), radius: 48, strap)
    fillRounded(CGRect(x: 204, y: 242, width: 88, height: 540), radius: 34, NSColor(hex: 0xD8F8F4))

    withShadow(blur: 26, offset: CGSize(width: 0, height: -14)) {
        fillRounded(CGRect(x: 120, y: 320, width: 270, height: 384), radius: 88, ink)
    }
    fillRounded(CGRect(x: 152, y: 364, width: 206, height: 296), radius: 62, glass)
    strokeRounded(CGRect(x: 152, y: 364, width: 206, height: 296), radius: 62, NSColor(hex: 0xC9E7EC), width: 5)
    fillRounded(CGRect(x: 386, y: 478, width: 22, height: 82), radius: 11, ink)

    let miniPulse = NSBezierPath()
    miniPulse.move(to: CGPoint(x: 198, y: 512))
    miniPulse.line(to: CGPoint(x: 228, y: 512))
    miniPulse.line(to: CGPoint(x: 244, y: 478))
    miniPulse.line(to: CGPoint(x: 270, y: 558))
    miniPulse.line(to: CGPoint(x: 292, y: 512))
    miniPulse.line(to: CGPoint(x: 318, y: 512))
    strokePath(miniPulse, color: NSColor(hex: 0xFF3F5E), width: 11)

    NSGraphicsContext.restoreGraphicsState()
}

func drawComputer() {
    let ink = NSColor(hex: 0x10222E)
    let glass = NSColor(hex: 0xF8FEFF)
    let bezel = NSColor(hex: 0x1A2F3C)
    let bezelSoft = NSColor(hex: 0x233B49)

    NSGraphicsContext.saveGraphicsState()
    let offset = NSAffineTransform()
    offset.translateX(by: -65, yBy: 0)
    offset.concat()

    withShadow(blur: 28, offset: CGSize(width: 0, height: -14)) {
        fillRounded(CGRect(x: 604, y: 258, width: 348, height: 512), radius: 46, ink)
    }
    fillRounded(CGRect(x: 625, y: 300, width: 306, height: 428), radius: 32, bezel)
    fillRounded(CGRect(x: 642, y: 330, width: 272, height: 340), radius: 18, glass)
    strokeRounded(CGRect(x: 642, y: 330, width: 272, height: 340), radius: 18, NSColor(hex: 0xC9E7EC), width: 5)

    fillRounded(CGRect(x: 592, y: 414, width: 20, height: 82), radius: 10, ink)
    fillRounded(CGRect(x: 592, y: 536, width: 20, height: 82), radius: 10, ink)
    fillRounded(CGRect(x: 948, y: 458, width: 18, height: 116), radius: 9, ink)

    fillRounded(CGRect(x: 682, y: 626, width: 150, height: 18), radius: 9, NSColor(hex: 0xDCEEF0))
    fillRounded(CGRect(x: 678, y: 578, width: 80, height: 56), radius: 12, NSColor(hex: 0xE9F7F7))
    fillRounded(CGRect(x: 782, y: 578, width: 96, height: 56), radius: 12, NSColor(hex: 0xE9F7F7))

    let hrPulse = NSBezierPath()
    hrPulse.move(to: CGPoint(x: 796, y: 606))
    hrPulse.line(to: CGPoint(x: 814, y: 606))
    hrPulse.line(to: CGPoint(x: 824, y: 590))
    hrPulse.line(to: CGPoint(x: 840, y: 620))
    hrPulse.line(to: CGPoint(x: 854, y: 606))
    hrPulse.line(to: CGPoint(x: 866, y: 606))
    strokePath(hrPulse, color: NSColor(hex: 0xFF3F5E), width: 6)
    fillRounded(CGRect(x: 794, y: 586, width: 12, height: 12), radius: 6, NSColor(hex: 0xFF3F5E, alpha: 0.9))

    let route = NSBezierPath()
    route.move(to: CGPoint(x: 688, y: 534))
    route.curve(
        to: CGPoint(x: 862, y: 514),
        controlPoint1: CGPoint(x: 728, y: 566),
        controlPoint2: CGPoint(x: 814, y: 474)
    )
    strokePath(route, color: NSColor(hex: 0x12B8CC), width: 12)
    fillRounded(CGRect(x: 684, y: 528, width: 16, height: 16), radius: 8, NSColor(hex: 0x48D1B5))
    fillRounded(CGRect(x: 856, y: 508, width: 16, height: 16), radius: 8, NSColor(hex: 0xFF3F5E))

    fillRounded(CGRect(x: 678, y: 456, width: 88, height: 26), radius: 13, NSColor(hex: 0x48D1B5))
    fillRounded(CGRect(x: 790, y: 456, width: 96, height: 26), radius: 13, NSColor(hex: 0x2F6BFF, alpha: 0.82))
    fillRounded(CGRect(x: 680, y: 406, width: 174, height: 24), radius: 12, NSColor(hex: 0x12B8CC))

    fillRounded(CGRect(x: 692, y: 282, width: 44, height: 18), radius: 9, bezelSoft)
    fillRounded(CGRect(x: 758, y: 282, width: 44, height: 18), radius: 9, bezelSoft)
    fillRounded(CGRect(x: 824, y: 282, width: 44, height: 18), radius: 9, bezelSoft)

    NSGraphicsContext.restoreGraphicsState()
}

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.shouldAntialias = true

NSGradient(
    starting: NSColor(hex: 0xF5FFFC),
    ending: NSColor(hex: 0xDCEEFF)
)!.draw(in: CGRect(x: 0, y: 0, width: canvas, height: canvas), angle: 270)

drawWatch()
drawComputer()
drawPulseLink()

NSGraphicsContext.restoreGraphicsState()

let destinations = [
    "App/PulseCast/Assets.xcassets/AppIcon.appiconset/PulseCastIcon-1024.png",
    "App/PulseCastWatch/Assets.xcassets/AppIcon.appiconset/PulseCastIcon-1024.png",
]

let png = bitmap.representation(using: .png, properties: [:])!
for destination in destinations {
    try png.write(to: URL(fileURLWithPath: destination))
}
