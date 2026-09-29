import Cocoa

let srcPath = "/Users/abhishekbabu/.gemini/antigravity-ide/brain/96feffb3-0de7-4b86-ab7e-f902cc627338/orchdroid_android_icon_1790620461568.jpg"
guard let srcImg = NSImage(contentsOfFile: srcPath),
      let cgSrc = srcImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Failed to load generated image")
    exit(1)
}

let size = CGSize(width: 1024, height: 1024)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Apple squircle inside 1024x1024: x: 110, y: 114, width: 804, height: 804
let squircleRect = CGRect(x: 112, y: 116, width: 800, height: 800)
let path = CGPath(roundedRect: squircleRect, cornerWidth: 185.0, cornerHeight: 185.0, transform: nil)

// Shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 32, color: NSColor(white: 0, alpha: 0.55).cgColor)
ctx.setFillColor(NSColor(calibratedRed: 0.08, green: 0.1, blue: 0.13, alpha: 1.0).cgColor)
ctx.addPath(path)
ctx.fillPath()
ctx.restoreGState()

// Clip to squircle
ctx.saveGState()
ctx.addPath(path)
ctx.clip()

// Draw the generated icon exactly aligned to the squircle
let drawRect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
ctx.draw(cgSrc, in: drawRect)

// Subtle outer bezel stroke
ctx.setLineWidth(2.0)
ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.15).cgColor)
ctx.addPath(path)
ctx.strokePath()

ctx.restoreGState()

if let cgOut = ctx.makeImage() {
    let outImg = NSImage(cgImage: cgOut, size: size)
    if let tiff = outImg.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "/Volumes/LinuxFS/OrchDroid/dist/instance_icon.png"))
        print("Successfully masked instance_icon.png")
    }
}
