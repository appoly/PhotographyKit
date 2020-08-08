# PhotographyKit
A swift library for quickly integrating a built in camera session into your app.
 
**Installing with cocoapods**
```
pod 'PhotographyKit'
```

**Quick start**

First start by creating a PhotographyKitDelegate, this will handle the result of any images being captured
```
extension CameraViewController: PhotographyKitDelegate {
    
    func didCaptureImage(image: UIImage) {
        imageView.image = image
    }
    
    
    func didStartRecordingVideo() {
        print("Recording started...")
    }
    
    
    func didFinishRecordingVideo(url: URL) {
        print("Finished recording video to \(url.absoluteString)")
    }
    
    
    func didFailRecordingVideo(error: Error) {
        print("Failed recording video to \(url.absoluteString) with error: \(error.localizedDescription)")
    }
    
}
```

Once you have your delegate setup, you can initialize your PhotographyKit object. The initializer takes 2 arguments:

- A view that will be used to display your camera preview
- The delegate which we declare above.

```
do {
    camera = try PhotographyKit(view: captureView, delegate: self)
} catch let error {
    showPhotographyKitError(error as? PhotographyKitError)
}
```

Once this is done you can toggle flash, switch cameras, take photos and record videos
```
try? camera.takePhoto()
try? camera.startVideoRecording(maxLength: 15)
camera.endVideoRecording
try? camera.switchCamera()
try? camera.toggleFlash(.auto)
```
