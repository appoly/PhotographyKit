//
//  PhotographyKit.swift
//  PhotographyKit
//
//  Created by Appoly on 29/03/2020.
//  Copyright © 2020 Appoly. All rights reserved.
//



import Foundation
import CoreImage
import UIKit
import AVFoundation



public enum PhotographyKitError: Error {
    case cameraPermissionDenied
    case imageCaptureFailed
    case failedToResetCamera
    case failedToConnectToDeviceCamera
    case failedToConnectToDeviceTorch
}



extension PhotographyKitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .cameraPermissionDenied:
                return "Camera permission denied"
            case .imageCaptureFailed:
                return "Image capture failed"
            case .failedToResetCamera:
                return "Failed to reset camera"
            case .failedToConnectToDeviceCamera:
                return "Failed to connect to device camera"
            case .failedToConnectToDeviceTorch:
                return "Failed to connect to device torch"
        }
    }
}



public protocol PhotographyKitDelegate {
    
    func didCaptureImage(image: UIImage)
    
}



public class PhotographyKit: NSObject {
    
    // MARK: - Variables
    
    //User defined photo settings
    private var exif: EXIF?
    private var iptc: IPTC?
    private var gps: GPS?
    private var filter: CIFilter?
    private var contrast: CGFloat = 0.5
    private var saturation: CGFloat = 0.5
    private var brightness: CGFloat = 0.5
    private let zoomSensitivity: CGFloat = 0.03
    private var delegate: PhotographyKitDelegate!
    
    //Capture session
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private let imageOutput = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?
    private var currentZoomFactor: CGFloat = 1
    private var containingView: UIView?
    
    //Photo captured
    private var photo: PhotographyKitPhoto?
    
    
    
    // MARK: - Actions
    
    /// Tries to resets the capture session, starting the preview again.
    public func resetCamera() throws {
        photo = nil
        videoPreviewLayer?.connection?.isEnabled = true
    }
    
    
    /// Tries to take a photo using the capture session
    public func takePhoto() throws {
        imageOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        videoPreviewLayer?.connection?.isEnabled = false
    }
    
    
    /// Toggles the flash of the capture device
    public func toggleFlash(_ mode: AVCaptureDevice.TorchMode) throws {
        guard let device = captureDevice else {
            throw PhotographyKitError.failedToConnectToDeviceCamera
        }
        
        if(device.hasTorch) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.torchMode = mode
            } catch let error {
                throw error
            }
        } else {
            throw PhotographyKitError.failedToConnectToDeviceTorch
        }
    }
    
    
    
    /// Focusses on a specific point of the view
    /// - Parameter focusPoint: The point at which you want to focus within the view
    public func focus(focusPoint: CGPoint) throws {
        guard let device = captureDevice else {
            throw PhotographyKitError.failedToConnectToDeviceCamera
        }
        
        do {
            try device.lockForConfiguration()

            device.focusPointOfInterest = focusPoint
            device.focusMode = .autoFocus
            device.exposurePointOfInterest = focusPoint
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
        }
        catch let error {
            throw error
        }
    }
    
    
    /// Switches the capture device from front camera to back camera
    public func switchCamera() throws {
        //Safely unwrap variables
        guard let session = captureSession,
            let input = session.inputs.first,
            let deviceInput = input as? AVCaptureDeviceInput,
            let cameraView = containingView
            else {
            throw PhotographyKitError.failedToConnectToDeviceCamera
        }
        
        //Remove current camera
        session.removeInput(input)
        guard var newCamera = AVCaptureDevice.default(for: .video) else {
            throw PhotographyKitError.failedToConnectToDeviceCamera
        }
        
        //Get camera for position
        switch deviceInput.device.position {
            case .back:
                UIView.transition(with: cameraView, duration: 0.5, options: .transitionFlipFromLeft, animations: {
                    newCamera = self.cameraWithPosition(.front)!
                }, completion: nil)
            case .front:
                UIView.transition(with: cameraView, duration: 0.5, options: .transitionFlipFromRight, animations: {
                    newCamera = self.cameraWithPosition(.back)!
                }, completion: nil)
            default:
                throw PhotographyKitError.failedToConnectToDeviceCamera
        }
        
        do {
            try session.addInput(AVCaptureDeviceInput(device: newCamera))
        }
        catch let error {
            throw error
        }
    }
    
    
    /// Zooms the picture
    /// - Parameter percentage: New zoom percentage
    public func zoom(factor: CGFloat = 1) throws {
        guard let device = captureDevice else {
            throw PhotographyKitError.failedToConnectToDeviceCamera
        }
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            let newFactor = currentZoomFactor + factor
            if(newFactor < device.activeFormat.videoMaxZoomFactor && newFactor > device.activeFormat.videoMinZoomFactorForDepthDataDelivery) {
                currentZoomFactor = newFactor
                device.videoZoomFactor = newFactor
            }
        } catch let error {
            throw error
        }
    }
    
    
    
    // MARK: - Initializers
    
    public init?(view: UIView, delegate: PhotographyKitDelegate, exif: EXIF?, iptc: IPTC?, gps: GPS?, filter: CIFilter?, contrast: CGFloat = 0.5, saturation: CGFloat = 0.5, brightness: CGFloat = 0.5) throws {
        super.init()
        
        self.exif = exif
        self.filter = filter
        self.contrast = contrast
        self.brightness = brightness
        self.delegate = delegate
        self.exif = exif
        self.iptc = iptc
        self.gps = gps
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:))))
        
        if(!checkCameraPermissions()) {
            throw PhotographyKitError.cameraPermissionDenied
        }
        
        do {
            try setupCamera(view: view)
        } catch {
            throw error
        }
    }
    
    
    
    // MARK: - Setup
    
    private func setupCamera(view: UIView) throws {
        do {
            let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
            
            guard let captureDevice = deviceDiscoverySession.devices.first else {
                throw PhotographyKitError.failedToConnectToDeviceCamera
            }
            try captureDevice.lockForConfiguration()
            defer { captureDevice.unlockForConfiguration() }
            captureDevice.torchMode = .auto
            
            try setupPreview(view: view, captureDevice: captureDevice)
        } catch let error {
            throw error
        }
    }
    
    
    private func setupPreview(view: UIView, captureDevice: AVCaptureDevice) throws {
        do {
            let captureSession = AVCaptureSession()
            
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)
            if(captureSession.canAddOutput(imageOutput)) {
                captureSession.addOutput(imageOutput)
            }
            
            setupCaptureSession(captureSession, view: view)
            self.captureDevice = captureDevice
            try startCaptureSession()
        } catch {
            throw PhotographyKitError.failedToConnectToDeviceCamera
        }
    }
    
    
    private func setupCaptureSession(_ captureSession: AVCaptureSession, view: UIView) {
        containingView = view
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = containingView!.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)
        self.captureSession = captureSession
    }
    
    
    
    // MARK: - Capture Session Controls
    
    private func startCaptureSession() throws {
        guard let captureSession = captureSession else {
            throw PhotographyKitError.failedToConnectToDeviceCamera
        }
        
        if(!captureSession.isRunning) {
            captureSession.startRunning()
        }
    }
    
    
    private func stopCaptureSession() throws {
        guard let captureSession = captureSession else {
            throw PhotographyKitError.failedToConnectToDeviceCamera
        }
        
        if(captureSession.isRunning) {
            captureSession.stopRunning()
        }
    }
    
    
    @objc private func focus(_ sender: UITapGestureRecognizer) {
        guard sender.state == .ended else { return }
        
        guard let screenSize = sender.view?.bounds.size else { return }
        let y = sender.location(in: sender.view).y / screenSize.height
        let x = sender.location(in: sender.view).x / screenSize.width
        let focusPoint = CGPoint(x: x, y: y)
        
        try? focus(focusPoint: focusPoint)
    }
    
    
    @objc private func zoom(_ sender: UIPinchGestureRecognizer) {
        var factor: CGFloat = sender.scale
        if(sender.scale < 1) {
            factor = ((factor + 1) * zoomSensitivity) * -1
        } else {
            factor = factor * zoomSensitivity
        }
        
        try? zoom(factor: factor)
    }
    
    
    
    // MARK: - Utilities
    
    private func checkCameraPermissions() -> Bool {
        let permission = AVCaptureDevice.authorizationStatus(for: .video)
        return permission == .authorized || permission == .notDetermined
    }
    
    
    private func cameraWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceDescoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)

        for device in deviceDescoverySession.devices {
            if device.position == position {
                return device
            }
        }
        
        return nil
    }
    
    
    private func getImageFrom(_ photo: AVCapturePhoto) -> UIImage? {
        guard let imageData = photo.fileDataRepresentation() else { return nil }
        return UIImage(data: imageData)
    }

}



extension PhotographyKit: AVCapturePhotoCaptureDelegate {
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            return
        }
        guard let image = getImageFrom(photo) else { return }
        
        let photo = PhotographyKitPhoto(image: image)
        
        photo.editImage(filter, contrast: contrast, brightness: brightness, saturation: saturation)
        photo.editMetaData(exif, iptc: iptc, gps: gps)
        
        delegate.didCaptureImage(image: photo.image)
    }
    
}
