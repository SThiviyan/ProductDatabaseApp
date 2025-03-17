//
//  ViewController.swift
//  BarCodeScanner
//
//  Created by Thiviyan Saravanamuthu on 10.03.25.
//



import UIKit
import AVFoundation
import Vision

class ScanViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    
    //MARK: All variables for Camera and Vision
    var captureSession: AVCaptureSession!
    
    var backCamera: AVCaptureDevice!
    var backInput: AVCaptureInput!
    var cameraOutput = AVCaptureVideoDataOutput()
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    
    private let visionQueue = DispatchQueue(label: "visionQueue")
    private var framecounter = 0 //Throttle processing
    
    
    
    //MARK: UI Elements
    let FlashButton: UIButton =
    {
        let Button = UIButton()
        
        
        Button.clipsToBounds = true
        Button.contentMode = .center
       
        Button.translatesAutoresizingMaskIntoConstraints = false
        Button.layer.cornerRadius = 30
        Button.layer.cornerCurve = .continuous
        Button.backgroundColor = .tertiarySystemFill
        
        let image = UIImageView(image: UIImage(systemName: "flashlight.off.fill"))
        Button.addSubview(image)
        
        image.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            image.centerXAnchor.constraint(equalTo: Button.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: Button.centerYAnchor),
            image.heightAnchor.constraint(equalTo: Button.heightAnchor, multiplier: 0.6),
            image.widthAnchor.constraint(equalTo: Button.widthAnchor, multiplier: 0.4)
        ])
        
        return Button
    }()
    
    
    var flashOn = false
    
    
    
    
    //MARK: LIFECYClE OF VIEWCONTROLLER
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        setup_start_captureSession()
        addButton()
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
            
       
    }

 
    
    
    //MARK: Setup of the AVCaptureSession, to enable live feed
    func setup_start_captureSession()
    {
        DispatchQueue.global(qos: .userInitiated).async {
            
            
            self.captureSession = AVCaptureSession()
            self.captureSession.beginConfiguration()
            
            
            if self.captureSession.canSetSessionPreset(.hd1280x720)
            {
                self.captureSession.sessionPreset = .hd1280x720
            }
            else
            {
                self.captureSession.sessionPreset = .iFrame960x540
            }
            
            self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
            self.setupInputs()
            self.setupOutputs()
            
            DispatchQueue.main.async
            {
                self.camerapreviewlayer()
            }
            
            
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
            
        }
    }
    
    
    func setupInputs()
    {
        var realdevice = false
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        {
            backCamera = device
            realdevice = true
        }
        else
        {
            print("no back cam, or Simulator device")
        }
        
        if(realdevice == true)
        {
            guard let Input = try? AVCaptureDeviceInput(device: backCamera) else
            {
                fatalError("could not create input device")
            }
            backInput = Input
            
            if captureSession.canAddInput(backInput)
            {
                captureSession.addInput(backInput)
            }
        }
    }
    
    
    func setupOutputs()
    {
        cameraOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        cameraOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(cameraOutput)
        {
            captureSession.addOutput(cameraOutput)
        }
    }
    
    func camerapreviewlayer()
    {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, below: navigationController?.navigationBar.layer)
        
        previewLayer.frame = view.frame
        
        view.bringSubviewToFront(FlashButton)
    }

    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer:
                       CMSampleBuffer, from connection: AVCaptureConnection) {
        
        
        framecounter += 1
        if framecounter % 10 != 0 { return }
        
        guard let pixelbuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else
        {return}
        
        detectBarcode(pixelBuffer: pixelbuffer)
        
    }
    
    func detectBarcode(pixelBuffer: CVPixelBuffer)
    {
        
        let request = VNDetectBarcodesRequest(completionHandler: {
            (request, error) in
            
            if let results = request.results as? [VNBarcodeObservation]
                {
                    for barcode in results
                    {
                        if let payload = barcode.payloadStringValue
                        {
                            DispatchQueue.main.async
                            {
                                self.captureSession.stopRunning()
                                self.showBarcodeAlert(payload: payload)
                            }
                        }
                    }
                }
            
        })
        
        
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do
            {
                try handler.perform([request])
            }
            catch
            {
                print("barcode detection failed")
            }
        }
    
    
    
    func showBarcodeAlert(payload: String)
    {
        let alert = UIAlertController(title: "Barcode detected", message: payload, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            
            self.captureSession.startRunning()
            
        }))
        present(alert, animated: true, completion: {
            return
        })
    }
}



extension ScanViewController
{
    func addButton()
    {
        view.addSubview(FlashButton)
        FlashButton.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            //FlashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            //FlashButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            FlashButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            FlashButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            FlashButton.widthAnchor.constraint(equalToConstant: 60),
            FlashButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    
    @objc func buttonPressed()
    {
        flashOn.toggle()
        
        if(flashOn)
        {
            do{
                if(backCamera.hasTorch)
                {
                    try backCamera.lockForConfiguration()
                    backCamera.torchMode = .on
                    backCamera.unlockForConfiguration()
                }
            }
            catch
            {
                print("Device flash Error")
            }
        }
        else
        {
            do
            {
                if(backCamera.hasTorch)
                {
                    try backCamera.lockForConfiguration()
                    backCamera.torchMode = .off
                    backCamera.unlockForConfiguration()
                }
            }
            catch
            {
                print("Device torch flash Error")
            }
        }
    }
}
