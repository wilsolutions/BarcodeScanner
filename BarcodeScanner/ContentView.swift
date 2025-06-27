//
//  ContentView.swift
//  BarcodeScanner
//
//  Created by Wils G. on 2025-03-01.
//

import SwiftUI

import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    var completion: (String) -> Void
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.completion = completion
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var completion: ((String) -> Void)?
    var closeButton: UIButton!
    
    var scanBoxView: UIView!
    var feedbackLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .code128, .qr]
        } else {
            return
        }
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Add scanBoxView
        scanBoxView = UIView(frame: CGRect(x: (view.frame.width - 260)/2, y: (view.frame.height - 120)/2, width: 260, height: 120))
        scanBoxView.layer.borderWidth = 3
        scanBoxView.layer.borderColor = UIColor.orange.cgColor // Changed from green to orange
        scanBoxView.layer.cornerRadius = 12
        scanBoxView.backgroundColor = .clear
        scanBoxView.clipsToBounds = true
        scanBoxView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        view.addSubview(scanBoxView)
        
        // Add feedbackLabel below scanBoxView
        feedbackLabel = UILabel()
        feedbackLabel.text = "Position a barcode inside the box."
        feedbackLabel.textColor = .white
        feedbackLabel.font = UIFont.systemFont(ofSize: 16)
        feedbackLabel.textAlignment = .center
        feedbackLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        feedbackLabel.layer.cornerRadius = 8
        feedbackLabel.clipsToBounds = true
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(feedbackLabel)
        
        NSLayoutConstraint.activate([
            feedbackLabel.topAnchor.constraint(equalTo: scanBoxView.bottomAnchor, constant: 16),
            feedbackLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            feedbackLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            feedbackLabel.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        closeButton.layer.cornerRadius = 8
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.frame = CGRect(x: view.frame.width - 90, y: 50, width: 70, height: 36)
        closeButton.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        view.addSubview(closeButton)
        
        captureSession.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Reset border color to orange on every scanned barcode
        DispatchQueue.main.async { [weak self] in
            self?.scanBoxView.layer.borderColor = UIColor.orange.cgColor
        }
        
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            DispatchQueue.main.async { [weak self] in
                self?.scanBoxView.layer.borderColor = UIColor.red.cgColor
                self?.feedbackLabel.text = "Invalid barcode"
            }
            return
        }
        
        // Updated validation logic
        let isValid = (stringValue.count == 12 || stringValue.count == 13)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Convert metadataObject.bounds to view coordinates
            let transformedObject = self.previewLayer.transformedMetadataObject(for: metadataObject)
            guard let barcodeBounds = transformedObject?.bounds else {
                // If can't transform bounds, treat as invalid
                self.scanBoxView.layer.borderColor = UIColor.red.cgColor
                self.feedbackLabel.text = "Invalid \(metadataObject.type.rawValue): \(stringValue)"
                return
            }
            
            if isValid {
                // Check intersection area ratio between barcodeBounds and scanBoxView.frame
                let intersection = barcodeBounds.intersection(self.scanBoxView.frame)
                if !intersection.isNull {
                    let intersectionArea = intersection.width * intersection.height
                    let barcodeArea = barcodeBounds.width * barcodeBounds.height
                    let overlapRatio = barcodeArea > 0 ? intersectionArea / barcodeArea : 0.0
                    if overlapRatio > 0.7 {
                        self.scanBoxView.layer.borderColor = UIColor.green.cgColor
                        self.feedbackLabel.text = "Valid \(metadataObject.type.rawValue): \(stringValue)"
                    } else {
                        // Barcode not sufficiently inside scanBoxView
                        self.scanBoxView.layer.borderColor = UIColor.orange.cgColor
                        self.feedbackLabel.text = "Position barcode fully inside the box."
                    }
                } else {
                    // No intersection, set orange
                    self.scanBoxView.layer.borderColor = UIColor.orange.cgColor
                    self.feedbackLabel.text = "Position barcode inside the box."
                }
            } else {
                self.scanBoxView.layer.borderColor = UIColor.red.cgColor
                self.feedbackLabel.text = "Invalid \(metadataObject.type.rawValue): \(stringValue)"
            }
        }
        
        if isValid {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self = self else { return }
                // Before dismissing, check again if barcode bounds are sufficiently inside scanBoxView frame
                let transformedObject = self.previewLayer.transformedMetadataObject(for: metadataObject)
                guard let barcodeBounds = transformedObject?.bounds else {
                    return
                }
                let intersection = barcodeBounds.intersection(self.scanBoxView.frame)
                if !intersection.isNull {
                    let intersectionArea = intersection.width * intersection.height
                    let barcodeArea = barcodeBounds.width * barcodeBounds.height
                    let overlapRatio = barcodeArea > 0 ? intersectionArea / barcodeArea : 0.0
                    if overlapRatio > 0.7 {
                        self.captureSession.stopRunning()
                        self.dismiss(animated: true) {
                            self.completion?("\(metadataObject.type.rawValue):\(stringValue)")
                        }
                    }
                    // else do nothing, wait for better position
                }
            }
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true) { [weak self] in
            self?.completion?("")
        }
    }
    
    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}


struct ContentView: View {
    
    @State private var isShowingScanner = false
    @State private var scannedBarcode: String? = nil
    @State private var barcodeValidationMessage: String? = nil
    @State private var isShowingValidationAlert = false
    
    /// Use for testing the camera in simulator, it requires RocketSim App
    private func loadRocketSimConnect() {
#if DEBUG
        guard (Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework")?.load() == true) else {
            print("Failed to load linker framework")
            return
        }
        print("RocketSim Connect successfully linked")
#endif
    }
    
    // Uncomment in order to use the Camera in the Simulator
    init() {
        //loadRocketSimConnect()
    }

    
    var body: some View {
        
        NavigationStack {
            HeaderView()
            VStack(spacing: 20) {

                Spacer()
                
                // Scanner Button
                Button(action: {
                    isShowingScanner = true
                }) {
                    HStack {
                        Image(systemName: "barcode.viewfinder")
                        Text("Scan Barcode")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("")
            //            .navigationBarHidden(true)
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView { code in
                isShowingScanner = false
                if !code.isEmpty {
                    // Updated check for 12- or 13-digit codes (with ':')
                    if code.contains(":") {
                        let components = code.split(separator: ":", maxSplits: 1)
                        if components.count == 2 {
                            let type = String(components[0])
                            let value = String(components[1])
                            if value.count == 12 || value.count == 13 {
                                barcodeValidationMessage = "Valid \(type) scanned: \(value)"
                            } else {
                                barcodeValidationMessage = "Invalid barcode scanned: \(code)"
                            }
                        } else {
                            barcodeValidationMessage = "Invalid barcode scanned: \(code)"
                        }
                    } else {
                        barcodeValidationMessage = "Invalid barcode scanned: \(code)"
                    }
                    isShowingValidationAlert = true
                    scannedBarcode = code
                }
            }
        }
        .alert(barcodeValidationMessage ?? "", isPresented: $isShowingValidationAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}


#Preview {
    ContentView()
}
