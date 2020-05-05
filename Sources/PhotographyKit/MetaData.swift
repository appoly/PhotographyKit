//
//  Metadata.swift
//  PhotographyKit
//
//  Created by Appoly on 30/03/2020.
//  Copyright © 2020 Appoly. All rights reserved.
//



import Foundation
import CoreImage
import CoreLocation



public class EXIF {
    
    // MARK: - Variables
    
    var make: String? = nil
    var lensMake: String? = nil
    var lensModel: String? = nil
    var lensSerialNumber: String? = nil
    var createDate: Date? = nil
    var dateTimeOriginal: Date? = nil
    var ownerName: String? = nil
    var userComment: String? = nil
    
    private let exifDateFormatter = DateFormatter()
    
    
    // MARK: - Initializer
    
    init() {
        
        exifDateFormatter.locale = .autoupdatingCurrent
        exifDateFormatter.calendar = .autoupdatingCurrent
        exifDateFormatter.dateFormat = "YYYY:MM:DD hh:mm:ss"
    }
    
    
    // MARK: - Utilites
    
    public func toDictionary() -> [CFString: Any] {
        
        var data = [CFString: Any]()
        data[kCGImagePropertyExifMakerNote] = make ?? ""
        data[kCGImagePropertyExifLensMake] = lensMake ?? ""
        data[kCGImagePropertyExifLensModel] = lensModel ?? ""
        data[kCGImagePropertyExifLensSerialNumber] = lensSerialNumber ?? ""
        data[kCGImagePropertyExifDateTimeOriginal] = dateTimeOriginal != nil ? exifDateFormatter.string(from: dateTimeOriginal!) : ""
        data[kCGImagePropertyExifCameraOwnerName] = ownerName ?? ""
        data[kCGImagePropertyExifUserComment] = userComment ?? ""
        
        return data
    }
    
}



public class IPTC {
    
    // MARK: - Variables
    
    var byline: String? = nil
    var bylineTitle: String? = nil
    var copyrightNotice: String? = nil
    var writerEditor: String? = nil
    var keywords = [String]()
    var objectName: String? = nil
    var headline: String? = nil
    var captionAbstract: String? = nil
    var countryPrimaryLocationName: String? = nil
    var provinceState: String? = nil
    var city: String? = nil
    var sublocation: String? = nil
    
    
    
    // MARK: - Utilites
    
    public func toDictionary() -> [CFString: Any] {
        
        var data = [CFString: Any]()
        data[kCGImagePropertyIPTCByline] = byline ?? ""
        data[kCGImagePropertyIPTCBylineTitle] = bylineTitle ?? ""
        data[kCGImagePropertyIPTCCopyrightNotice] = copyrightNotice ?? ""
        data[kCGImagePropertyIPTCWriterEditor] = writerEditor ?? ""
        data[kCGImagePropertyIPTCKeywords] = keywords.joined(separator: ",")
        data[kCGImagePropertyIPTCObjectName] = objectName ?? ""
        data[kCGImagePropertyIPTCHeadline] = headline ?? ""
        data[kCGImagePropertyIPTCCaptionAbstract] = captionAbstract ?? ""
        data[kCGImagePropertyIPTCCountryPrimaryLocationName] = countryPrimaryLocationName ?? ""
        data[kCGImagePropertyIPTCProvinceState] = provinceState ?? ""
        data[kCGImagePropertyIPTCCity] = city ?? ""
        data[kCGImagePropertyIPTCSubLocation] = sublocation ?? ""
        
        return data
    }
    
}



public class GPS {
    
    // MARK: - Variables
    
    var gpsVersion: String? = nil
    var location: CLLocation? = nil

    
    
    // MARK: - Utilites
    
    public func toDictionary() -> [CFString: Any] {
        
        var data = [CFString: Any]()
        data[kCGImagePropertyGPSVersion] = gpsVersion ?? ""
        if(location != nil) {
            data[kCGImagePropertyGPSLatitude] = "\(location!.coordinate.latitude)"
            data[kCGImagePropertyGPSLongitude] = "\(location!.coordinate.longitude)"
            data[kCGImagePropertyGPSAltitude] = "\(location!.altitude)"
            data[kCGImagePropertyGPSSpeed] = "\(location!.speed)"
        }
        
        return data
    }
    
}
