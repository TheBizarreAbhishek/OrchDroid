import Cocoa

guard let srcImg = NSImage(contentsOfFile: "/Volumes/LinuxFS/OrchDroid/assets/icon.png"),
      let rep = srcImg.representations.first as? NSBitmapImageRep else {
    print("Failed to load source image")
    exit(1)
}

let W = rep.pixelsWide
let H = rep.pixelsHigh

// Step 1: Create transparent RGBA representation of the OD logo
// Extract OD logo: separate into charcoal parts and green parts
var logoMaskRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: W,
                                   pixelsHigh: H,
                                   bitsPerSample: 8,
                                   samplesPerPixel: 4,
                                   hasAlpha: true,
                                   isPlanar: false,
                                   colorSpaceName: .calibratedRGB,
                                   bytesPerRow: W * 4,
                                   bitsPerPixel: 32)!

// Buffer to store pixel types: 0 = bg, 1 = charcoal OD, 2 = green mascot/accents
enum PixelType { case background, charcoal, green }
var pixelTypes = [PixelType](repeating: .background, count: W * H)

for y in 0..<H {
    for x in 0..<W {
        if let c = rep.colorAt(x: x, y: y) {
            let r = c.redComponent
            let g = c.greenComponent
            let b = c.blueComponent
            let brightness = (r + g + b) / 3.0
            
            // Check if background (cream color > 0.85)
            if brightness > 0.82 && r > 0.8 && g > 0.8 && b > 0.75 {
                pixelTypes[y * W + x] = .background
            } else if g > r + 0.12 && g > b + 0.15 {
                // Green part (Android head or green accents on OD)
                pixelTypes[y * W + x] = .green
            } else {
                // Charcoal / Dark body of OD
                pixelTypes[y * W + x] = .charcoal
            }
        }
    }
}

// Function to generate an icon with dark squircle
func renderDarkIcon(isInstance: Bool) -> NSImage {
    let size = CGSize(width: 1024, height: 1024)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil,
                        width: 1024,
                        height: 1024,
                        bitsPerComponent: 8,
                        bytesPerRow: 0,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    
    // Apple Squircle geometry
    let squircleRect = CGRect(x: 104, y: 108, width: 816, height: 816)
    let cornerRadius: CGFloat = 185.0
    let path = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // 1. Soft macOS Icon Drop Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor(white: 0, alpha: 0.45).cgColor)
    ctx.setFillColor(NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0).cgColor)
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Clip to Squircle
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // 3. Dark Mode Background (macOS Sequoia Dark Icon style: sleek dark slate gradient)
    let bgColors = isInstance ? [
        NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.22, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.14, alpha: 1.0).cgColor
    ] as CFArray : [
        NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.20, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1.0).cgColor
    ] as CFArray
    
    let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 108), options: [])

    // 4. Render the OD Logo onto the dark background
    // Create bitmap for this icon
    let logoRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: W,
                                   pixelsHigh: H,
                                   bitsPerSample: 8,
                                   samplesPerPixel: 4,
                                   hasAlpha: true,
                                   isPlanar: false,
                                   colorSpaceName: .calibratedRGB,
                                   bytesPerRow: W * 4,
                                   bitsPerPixel: 32)!
    
    for y in 0..<H {
        for x in 0..<W {
            let t = pixelTypes[y * W + x]
            switch t {
            case .background:
                // transparent
                logoRep.setColor(NSColor(white: 0, alpha: 0), atX: x, y: y)
            case .charcoal:
                if isInstance {
                    // For Instance: Slightly tinted Emerald Titanium / Vibrant Green accent on OD
                    logoRep.setColor(NSColor(calibratedRed: 0.22, green: 0.78, blue: 0.42, alpha: 1.0), atX: x, y: y)
                } else {
                    // For Host App: Clean Light Silver / Titanium White on dark background
                    logoRep.setColor(NSColor(calibratedRed: 0.92, green: 0.94, blue: 0.97, alpha: 1.0), atX: x, y: y)
                }
            case .green:
                // Vibrant Android Green for the mascot head and accents
                logoRep.setColor(NSColor(calibratedRed: 0.28, green: 0.85, blue: 0.45, alpha: 1.0), atX: x, y: y)
            }
        }
    }
    
    // Draw the processed logo inside the squircle (flipped Y for CGContext)
    let logoCg = logoRep.cgImage!
    let logoRect = CGRect(x: 80, y: 84, width: 864, height: 864)
    ctx.draw(logoCg, in: logoRect)

    // 5. Subtle Edge Border (macOS Sequoia Dark Icon standard)
    ctx.setLineWidth(2.5)
    if isInstance {
        ctx.setStrokeColor(NSColor(calibratedRed: 0.28, green: 0.85, blue: 0.45, alpha: 0.55).cgColor)
    } else {
        ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.15).cgColor)
    }
    ctx.addPath(path)
    ctx.strokePath()

    ctx.restoreGState()

    let outCg = ctx.makeImage()!
    return NSImage(cgImage: outCg, size: size)
}

func savePng(img: NSImage, path: String) {
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path)")
    }
}

let hostDark = renderDarkIcon(isInstance: false)
let instDark = renderDarkIcon(isInstance: true)

savePng(img: hostDark, path: "/Volumes/LinuxFS/OrchDroid/dist/host_dark_icon.png")
savePng(img: instDark, path: "/Volumes/LinuxFS/OrchDroid/dist/instance_dark_icon.png")
print("Done generating dark mode icons")
