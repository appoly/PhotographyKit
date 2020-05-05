//
//  PhotographyKitPhoto.swift
//  PhotographyKit
//
//  Created by Appoly on 29/03/2020.
//  Copyright © 2020 Appoly. All rights reserved.
//



import Foundation
import CoreImage
import CoreGraphics
import UIKit



internal class PhotographyKitPhoto: NSObject {
    
    // MARK: - Variables
    
    private(set) var image: UIImage!
    
    
    
    // MARK: - Initializers
    
    init(image: UIImage) {
        self.image = image
        super.init()
    }
    
    
    
    // MARK: - Setup
    
    public func editImage(_ filter: CIFilter?, contrast: CGFloat = 0.5, brightness: CGFloat = 0.5, saturation: CGFloat = 0.5, square: Bool = false) {
        let context = CIContext(options: nil)
        guard filter != nil else { return }
        
        let beginImage = CIImage(image: image)
        filter!.setValue(beginImage, forKey: kCIInputImageKey)
        filter!.setValue(0.5, forKey: kCIInputIntensityKey)
        filter!.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter!.setValue(saturation, forKey: kCIInputSaturationKey)
        filter!.setValue(contrast, forKey: kCIInputContrastKey)
        
        if(square) {
            filter!.setValue(1, forKey: kCIInputAspectRatioKey)
        }

        if let output = filter!.outputImage {
            if let cgimg = context.createCGImage(output, from: output.extent) {
                image = UIImage(cgImage: cgimg)
            }
        }
    }
    
    
    public func editMetaData(_ exif: EXIF? = nil, iptc: IPTC? = nil, gps: GPS? = nil) {
        let jpeg = image.jpegData(compressionQuality: 1.0)
        let source = CGImageSourceCreateWithData((jpeg as CFData?)!, nil)
        
        var metadata = [CFString: Any]()
        metadata[kCGImagePropertyExifDictionary] = exif?.toDictionary() ?? [:]
        metadata[kCGImagePropertyIPTCDictionary] = iptc?.toDictionary() ?? [:]
        metadata[kCGImagePropertyGPSDictionary] = gps?.toDictionary() ?? [:]

        let uti: CFString = CGImageSourceGetType(source!)!
        let destData = NSMutableData()
        let destination: CGImageDestination = CGImageDestinationCreateWithData(destData as CFMutableData, uti, 1, nil)!
        CGImageDestinationAddImageFromSource(destination, source!, 0, (metadata as CFDictionary?))
        CGImageDestinationFinalize(destination)
    }

}
