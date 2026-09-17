import AppKit
let size = NSSize(width: 1024, height: 1024)
let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
NSColor(calibratedRed:0.93,green:0.91,blue:0.86,alpha:1).setFill();NSRect(origin:.zero,size:size).fill()
let dark = NSColor(calibratedRed:0.12,green:0.17,blue:0.16,alpha:1)
dark.setFill();NSBezierPath(roundedRect:NSRect(x:105,y:625,width:814,height:280),xRadius:55,yRadius:55).fill()
let label="PB / 16" as NSString
label.draw(at:NSPoint(x:161,y:695),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:126,weight:.bold),.foregroundColor:NSColor(calibratedRed:0.93,green:0.91,blue:0.86,alpha:1)])
for row in 0..<4 {for col in 0..<4 {let active=[0,2,5,8,10,15].contains(row*4+col);(active ? NSColor(calibratedRed:0.8,green:0.27,blue:0.12,alpha:1):dark).setFill();NSBezierPath(roundedRect:NSRect(x:105+col*207,y:103+(3-row)*119,width:191,height:103),xRadius:20,yRadius:20).fill()}}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
