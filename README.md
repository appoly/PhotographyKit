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
    
}
```

Once you have your delegate setup, you can initialize your PhotographyKit object. The initializer takes 9 arguments:

- A view that will be used to display your camera preview
- The delegate which we declare above.
- EXIF: An exif data object to add metadata to an image
- IPTC: An IPTC data object to add metadata to an image
- GPS: A GPS data object to add metadata to an image
- Filter: A CIFilter object to add a filter to an image
- Contrast: A Float representation of the image's contrast ranging from 0-1, default value is 0.5
- Saturation: A Float representation of the image's saturation ranging from 0-1, default value is 0.5
- Brightness: A Float representation of the image's brightness ranging from 0-1, default value is 0.5

```
do {
    camera = try PhotographyKit(view: captureView, delegate: self, exif: nil, iptc: nil, gps: nil, filter: nil)
} catch let error {
    showPhotographyKitError(error as? PhotographyKitError)
}
```

Once this is done you can toggle flash, switch cameras, and take photos
```
try? camera.takePhoto()
try? camera.switchCamera()
try? camera.toggleFlash(.auto)
```
