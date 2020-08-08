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
    case failedToCreateVideoFile
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
            case .failedToCreateVideoFile:
                return "Failed to create video file for recording"
        }
    }
}



public protocol PhotographyKitDelegate {
    
    func didCaptureImage(image: PhotographyKitPhoto)
    func didStartRecordingVideo()
    func didFinishRecordingVideo(url: URL)
    func didFailRecordingVideo(error: Error)
    
}



public class PhotographyKit: NSObject {
    
    // MARK: - Variables
    
    //User defined photo settings
    private let zoomSensitivity: CGFloat = 0.03
    private var delegate: PhotographyKitDelegate!
    
    //Capture session
    private var captureSession: AVCaptureSession?
    private let movieFileOutput = AVCaptureMovieFileOutput()
    private var timer: Timer?
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
    
    
    /// Tries to start recording a video
    public func startVideoRecording(maxLength: TimeInterval, url: URL? = nil) throws {
        timer?.invalidate()
        guard let safeURL = url == nil ? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).mp4") : url else {
            throw PhotographyKitError.failedToCreateVideoFile
        }
        
        movieFileOutput.startRecording(to: safeURL, recordingDelegate: self)
        timer = Timer.scheduledTimer(withTimeInterval: maxLength, repeats: false, block: { [weak self] _ in
            self?.endVideoRecording()
        })
    }
    
    
    public func endVideoRecording() {
        movieFileOutput.stopRecording()
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
    
    public init?(view: UIView, delegate: PhotographyKitDelegate) throws {
        super.init()
        
        self.delegate = delegate
        
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
            
            if(captureSession.canAddOutput(movieFileOutput)) {
                captureSession.addOutput(movieFileOutput)
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
        delegate.didCaptureImage(image: photo)
    }
    
}



extension PhotographyKit: AVCaptureFileOutputRecordingDelegate {
    
    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        delegate.didStartRecordingVideo()
    }
    
    
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard error == nil else {
            delegate.didFailRecordingVideo(error: error!)
            return
        }
        delegate.didFinishRecordingVideo(url: outputFileURL)
    }
    
}
