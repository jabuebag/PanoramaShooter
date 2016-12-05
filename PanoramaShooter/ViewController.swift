//
//  ViewController.swift
//  CameraExample
//
//  Created by Geppy Parziale on 2/15/16.
//  Copyright © 2016 iNVASIVECODE, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion
import Agrume

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var number: Int = 0
    var motionManager = CMMotionManager()
    
    let internalVector:Double = 1.0
    var picNumber: Int = 0
    var yawPerTime : Double = 0.0
    var yawPerInterval : Double = 0.0
    var perIntervalAngle: Double = 0.0
    var rotatedAngle: Double = 0.0
    var rotateDirection: Double = 0.0
    
    var finalImage: UIImage?
    
    var projectContext: CGContext?
    
    var imageView: UIImageView?

	override func viewDidLoad() {
		super.viewDidLoad()
        number = 0
		setupCameraSession()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		view.layer.addSublayer(previewLayer)
        
		cameraSession.startRunning()
        projectContext = nil
        motionManager.deviceMotionUpdateInterval = 1/30
        self.motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {motion,error in self.calculateRotationByGyro(motion: motion!)})
	}
    
    func calculateRotationByGyro(motion:CMDeviceMotion){
        let qx = motion.attitude.quaternion.x
        let qy = motion.attitude.quaternion.y
        let qz = motion.attitude.quaternion.z
        let qw = motion.attitude.quaternion.w
        // motion.attitude.
        var pitch = atan2(2*(qx*qw + qy*qz), 1 - 2*qx*qx - 2*qz*qz) * 180 / M_PI
        var roll = atan2(2*(qy*qw + qx*qz), 1 - 2*qy*qy - 2*qz*qz) * 180 / M_PI
        let yaw = asin(2*qx*qy + 2*qz*qw) * 180 / M_PI
        rotateDirection = motion.rotationRate.y*180 / M_PI
        if rotateDirection < 0 {
            var perTimeAngle = abs(yaw - yawPerTime)
            perIntervalAngle = abs(yaw - yawPerInterval)
            rotatedAngle += perTimeAngle
            if perIntervalAngle >= internalVector {
                picNumber += 1
                yawPerInterval = yaw
            }
            yawPerTime = yaw
        }
        else {
            if rotateDirection > 30 {
                self.motionManager.stopDeviceMotionUpdates()
                print("Please restart")
            } else {
                print("please rotate to right")
            }
            
        }
    }

	lazy var cameraSession: AVCaptureSession = {
		let s = AVCaptureSession()
		s.sessionPreset = AVCaptureSessionPresetMedium
		return s
	}()

	lazy var previewLayer: AVCaptureVideoPreviewLayer = {
		let preview =  AVCaptureVideoPreviewLayer(session: self.cameraSession)
		preview?.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
		preview?.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
		preview?.videoGravity = AVLayerVideoGravityResize
		return preview!
	}()

	func setupCameraSession() {
		let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice

		do {
			let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
			
			cameraSession.beginConfiguration()

			if (cameraSession.canAddInput(deviceInput) == true) {
				cameraSession.addInput(deviceInput)
			}

			let dataOutput = AVCaptureVideoDataOutput()
			dataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value:kCVPixelFormatType_32BGRA as UInt32)]
			dataOutput.alwaysDiscardsLateVideoFrames = true

			if (cameraSession.canAddOutput(dataOutput) == true) {
				cameraSession.addOutput(dataOutput)
			}

			cameraSession.commitConfiguration()

			let queue = DispatchQueue(label: "com.jabue.PanoramaCamera")
			dataOutput.setSampleBufferDelegate(self, queue: queue)

		}
		catch let error as NSError {
			NSLog("\(error), \(error.localizedDescription)")
		}
	}

	func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if perIntervalAngle >= internalVector {
            if rotatedAngle <= 360 {
                var image: UIImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer)
                var resizeImage = resizeImageWithFixedRatio(image: image, newWidth: image.size.width)
                print(resizeImage.size)
                projectImage(resizeImage, vector: CGFloat(number * 12))
                number += 1
            } else {
                self.motionManager.stopDeviceMotionUpdates()
                self.previewLayer.isHidden = true
                self.cameraSession.stopRunning()
                var tapGesture = UITapGestureRecognizer(target: self, action: "tapImage")
                imageView = UIImageView(image: generateImage())
                imageView?.frame = CGRect(x: 0, y: 40, width: 400, height: 100)
                imageView?.addGestureRecognizer(tapGesture)
                imageView?.isUserInteractionEnabled = true
                self.view.addSubview(imageView!)
            }
        }
	}

	func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
		// Here you can count how many frames are dopped
	}
    
    func tapImage() {
        let agrume = Agrume(image: (imageView?.image)!)
        agrume.showFrom(self)
    }
    
    func imageFromSampleBuffer(sampleBuffer : CMSampleBuffer) -> UIImage
    {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        let  imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly);
        
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!);
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!);
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer!);
        let height = CVPixelBufferGetHeight(imageBuffer!);

        let colorSpace = CGColorSpaceCreateDeviceRGB();
        
        // Create a bitmap graphics context with the sample buffer data
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        let context = CGContext.init(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        // Create a Quartz image from the pixel data in the bitmap graphics context
        let quartzImage = context?.makeImage();
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly);
        let image = UIImage(cgImage: quartzImage!, scale: 1.0, orientation: UIImageOrientation.right)
        
        return (image);
    }
    
    func resizeImageWithFixedRatio(image: UIImage, newWidth: CGFloat) -> UIImage {
        let scale = newWidth / image.size.width
        let newHeight = image.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y:0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    
    fileprivate func panoramaBitmapContext(_ pixelsHigh: Int) -> CGContext? {
        let pixelsWide = pixelsHigh * 6
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // create the bitmap context
        let bitmapContext = CGContext(data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: colorSpace,
                                      // this will give us an optimal BGRA format for the device:
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        return bitmapContext
    }
    
    func projectImage(_ image: UIImage, vector: CGFloat) {
        if projectContext == nil {
            projectContext = panoramaBitmapContext(Int(image.size.height))
        }
        projectContext?.draw(image.cgImage!, in: CGRect(x: vector, y: 0.0, width: image.size.width, height: image.size.height))
    }
    
    func generateImage() -> UIImage? {
        let reflectionImage = projectContext?.makeImage()
        
        // convert the finished reflection image to a UIImage
        let theImage = UIImage(cgImage: reflectionImage!)
        
        return theImage
    }
	
}

