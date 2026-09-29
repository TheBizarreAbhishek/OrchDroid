import Cocoa

guard let sourceImage = NSImage(contentsOfFile: "/Volumes/LinuxFS/OrchDroid/assets/icon.png"),
      let sourceCgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Error: Could not load source image")
    exit(1)
}

// 1. GENERATE HOST APP ICON (Clean macOS Squircle with Shadow)
func createHostAppIcon() -> NSImage {
    let size = CGSize(width: 1024, height: 1024)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil,
                        width: Int(size.width),
                        height: Int(size.height),
                        bitsPerComponent: 8,
                        bytesPerRow: 0,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    
    // Squircle frame in 1024x1024 canvas
    let squircleRect = CGRect(x: 104, y: 108, width: 816, height: 816)
    let cornerRadius: CGFloat = 185.0
    let path = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // Draw subtle drop shadow behind squircle
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor(white: 0, alpha: 0.38).cgColor)
    ctx.setFillColor(NSColor(calibratedRed: 0.945, green: 0.937, blue: 0.914, alpha: 1.0).cgColor)
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()

    // Clip to squircle and draw OD logo
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // Draw the image inside squircle with slight padding so OD logo breathes nicely
    let drawRect = CGRect(x: 80, y: 84, width: 864, height: 864)
    ctx.draw(sourceCgImage, in: drawRect)

    // Subtle inner stroke border for Apple macOS icon polish
    ctx.setLineWidth(2.5)
    ctx.setStrokeColor(NSColor(white: 0, alpha: 0.12).cgColor)
    ctx.addPath(path)
    ctx.strokePath()

    ctx.restoreGState()
    
    let cgImg = ctx.makeImage()!
    return NSImage(cgImage: cgImg, size: size)
}

// 2. GENERATE ANDROID VM GAMING PROCESS ICON
// Distinctive Gaming Squircle with Neon Emerald Border & "120 FPS" Gaming Badge
func createAndroidInstanceIcon() -> NSImage {
    let size = CGSize(width: 1024, height: 1024)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil,
                        width: Int(size.width),
                        height: Int(size.height),
                        bitsPerComponent: 8,
                        bytesPerRow: 0,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    
    let squircleRect = CGRect(x: 104, y: 108, width: 816, height: 816)
    let cornerRadius: CGFloat = 185.0
    let path = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor(white: 0, alpha: 0.38).cgColor)
    ctx.setFillColor(NSColor(calibratedRed: 0.945, green: 0.937, blue: 0.914, alpha: 1.0).cgColor)
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()

    // Clip to squircle
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // Draw OD logo
    let drawRect = CGRect(x: 80, y: 84, width: 864, height: 864)
    ctx.draw(sourceCgImage, in: drawRect)

    // Vibrant Emerald Gamer Border
    ctx.setLineWidth(8.0)
    ctx.setStrokeColor(NSColor(calibratedRed: 0.14, green: 0.78, blue: 0.36, alpha: 0.9).cgColor)
    ctx.addPath(path)
    ctx.strokePath()

    // Draw "⚡ 120 FPS" badge in bottom right
    let badgeRect = CGRect(x: 620, y: 125, width: 275, height: 82)
    let badgePath = CGPath(roundedRect: badgeRect, cornerWidth: 41, cornerHeight: 41, transform: nil)
    
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 6), blur: 16, color: NSColor(calibratedRed: 0.08, green: 0.65, blue: 0.28, alpha: 0.7).cgColor)
    ctx.setFillColor(NSColor(calibratedRed: 0.12, green: 0.75, blue: 0.38, alpha: 1.0).cgColor)
    ctx.addPath(badgePath)
    ctx.fillPath()
    
    // White inner border on badge
    ctx.setLineWidth(2.0)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.35).cgColor)
    ctx.addPath(badgePath)
    ctx.strokePath()
    ctx.restoreGState()

    // Badge Text: "120 FPS"
    let text = "⚡ 120 FPS" as NSString
    let font = NSFont.systemFont(ofSize: 36, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let textSize = text.size(withAttributes: attrs)
    let textPos = CGPoint(x: badgeRect.midX - textSize.width / 2.0,
                          y: badgeRect.midY - textSize.height / 2.0)
    
    let gc = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    text.draw(at: textPos, withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()

    ctx.restoreGState()
    
    let cgImg = ctx.makeImage()!
    return NSImage(cgImage: cgImg, size: size)
}

func savePng(img: NSImage, path: String) {
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path)")
    }
}

let hostIcon = createHostAppIcon()
let vmIcon = createAndroidInstanceIcon()

savePng(img: hostIcon, path: "/Volumes/LinuxFS/OrchDroid/dist/host_icon.png")
savePng(img: vmIcon, path: "/Volumes/LinuxFS/OrchDroid/dist/instance_icon.png")
print("Icons generated successfully!")
