//
//  ViewController.swift
//  VideoRecorder
//
//  Created by Paul Solt on 10/2/19.
//  Copyright © 2019 Lambda, Inc. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view.
	
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// TODO: get permission
		
		requestCameraPermission()
		
	}
	
	private func requestCameraPermission() {
		
		// TODO: Get permission, showCamera if we have it
		// TODO: error conditions with lack of permission / restricted
		
		let status = AVCaptureDevice.authorizationStatus(for: .video)
		
		switch status {
		case .notDetermined:
			// We have not asked for permission
			requestCameraAccess()
		case .restricted:
			// parental controls limit media usage (no camera access)
			fatalError("Please inform the user they cannot use app due to parental restrictions")
		case .denied:
			// User has said no camera allowed
			fatalError("Please ask user to enable access to camera in Settings > Privacy > Camera")
		case .authorized:
			// User has allowed our app to use the camera
			
			showCamera()
		}
		
	}
	
	private func requestCameraAccess() {
		// The popup will appear 1 time with this dialog
		
		AVCaptureDevice.requestAccess(for: .video) { (granted) in
			if granted == false {
				fatalError("Please request user to enable camera usage in Settings > Privacy")
			}
			
			DispatchQueue.main.async {
				self.showCamera()
			}
		}
	}
	
	private func showCamera() {
		performSegue(withIdentifier: "ShowCamera", sender: self)
	}
}
