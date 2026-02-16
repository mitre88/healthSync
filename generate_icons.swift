import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func createAppIcon(size: CGFloat, filename: String, outputDir: URL) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    guard let context = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        print("Failed to create context for \(filename)")
        return
    }
    
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    
    let tealColor = CGColor(red: 0.0, green: 0.7, blue: 0.8, alpha: 1.0)
    let whiteColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    
    context.setFillColor(tealColor)
    let cornerRadius = size * 0.2237
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )
    context.addPath(path)
    context.fillPath()
    
    context.setFillColor(whiteColor)
    context.setStrokeColor(whiteColor)
    
    let pillWidth = size * 0.35
    let pillHeight = size * 0.7
    let pillX = (size - pillWidth) / 2
    let pillY = (size - pillHeight) / 2
    let pillCornerRadius = pillWidth / 2
    
    let pillRect = CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
    let pillPath = CGPath(
        roundedRect: pillRect,
        cornerWidth: pillCornerRadius,
        cornerHeight: pillCornerRadius,
        transform: nil
    )
    context.addPath(pillPath)
    context.fillPath()
    
    let lineY = size / 2
    context.move(to: CGPoint(x: pillX, y: lineY))
    context.addLine(to: CGPoint(x: pillX + pillWidth, y: lineY))
    context.setStrokeColor(tealColor)
    context.setLineWidth(size * 0.04)
    context.strokePath()
    
    let plusSize = size * 0.15
    let plusX = size * 0.72
    let plusY = size * 0.28
    let plusLineWidth = size * 0.06
    
    context.setStrokeColor(whiteColor)
    context.setLineWidth(plusLineWidth)
    context.setLineCap(.round)
    
    context.move(to: CGPoint(x: plusX - plusSize/2, y: plusY))
    context.addLine(to: CGPoint(x: plusX + plusSize/2, y: plusY))
    context.strokePath()
    
    context.move(to: CGPoint(x: plusX, y: plusY - plusSize/2))
    context.addLine(to: CGPoint(x: plusX, y: plusY + plusSize/2))
    context.strokePath()
    
    guard let cgImage = context.makeImage() else {
        print("Failed to create image for \(filename)")
        return
    }
    
    let url = outputDir.appendingPathComponent(filename)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("Failed to create destination for \(filename)")
        return
    }
    
    CGImageDestinationAddImage(destination, cgImage, nil)
    CGImageDestinationFinalize(destination)
    
    print("Created: \(filename)")
}

let outputDir = URL(fileURLWithPath: "/Users/dr.alexmitre/HealthSync/HealthSync/Assets.xcassets/AppIcon.appiconset")

let iconSizes: [(size: CGFloat, filename: String)] = [
    (40, "AppIcon-20@2x.png"),
    (60, "AppIcon-20@3x.png"),
    (58, "AppIcon-29@2x.png"),
    (87, "AppIcon-29@3x.png"),
    (80, "AppIcon-40@2x.png"),
    (120, "AppIcon-40@3x.png"),
    (120, "AppIcon-60@2x.png"),
    (180, "AppIcon-60@3x.png"),
    (20, "AppIcon-20.png"),
    (29, "AppIcon-29.png"),
    (40, "AppIcon-40.png"),
    (76, "AppIcon-76.png"),
    (152, "AppIcon-76@2x.png"),
    (167, "AppIcon-83.5@2x.png"),
    (1024, "AppIcon-1024.png")
]

for icon in iconSizes {
    createAppIcon(size: icon.size, filename: icon.filename, outputDir: outputDir)
}

print("\nAll icons created successfully!")
