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



public class PhotographyKitPhoto: NSObject {
    
    // MARK: - Variables
    
    private(set) var image: UIImage!
    
    public var uiImage: UIImage {
        return image
    }
    
    public var ciImage: CIImage? {
        return CIImage(image: image)
    }
    
    
    
    // MARK: - Initializers
    
    init(image: UIImage) {
        self.image = image
        super.init()
    }

}
