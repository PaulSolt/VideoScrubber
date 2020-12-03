//
//  SceneDelegate.swift
//  VideoScrubber
//
//  Created by Paul Solt on 11/29/20.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        
        // Simulate launching view controller with the video
        
        let url = Bundle.main.url(forResource: "BrewCoffeeVideo720", withExtension: "mp4")! // portrait
//        let url = Bundle.main.url(forResource: "tomato-polinating", withExtension: "mp4")! // vertical

        let videoController = VideoViewController.create(url: url)
        let navigationController = UINavigationController(rootViewController: videoController)
        navigationController.isToolbarHidden = false
        window.rootViewController = navigationController
        
        self.window = window
        window.makeKeyAndVisible()

    }
}

