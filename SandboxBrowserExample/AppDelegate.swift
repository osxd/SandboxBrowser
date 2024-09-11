//
//  AppDelegate.swift
//  AirSandboxExample
//
//  Created by Joe on 2017/8/25.
//  Copyright © 2017年 Joe. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let testUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
        let plistpath = testUrl?.path.appending("/example.plist")
        let pngpath = testUrl?.path.appending("/example.png")
        let dbpath = testUrl?.path.appending("/example.sqlite3")
        let logpath = testUrl?.path.appending("/example.log")
        do {
            try "Sandbox Browser".write(toFile: plistpath!, atomically: true, encoding: .utf8)
            try "Sandbox Browser".write(toFile: pngpath!, atomically: true, encoding: .utf8)
            try "Sandbox Browser".write(toFile: dbpath!, atomically: true, encoding: .utf8)
            try "Sandbox Browser".write(toFile: logpath!, atomically: true, encoding: .utf8)
        } catch {
            print(error.localizedDescription)
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
            self.enableSwipe()
        })
        
        return true
    }
    
    
    public func enableSwipe() {
        let simpleBrowser = UISwipeGestureRecognizer(target: self, action: #selector(startSimpleBrowser))
        simpleBrowser.numberOfTouchesRequired = 1
        simpleBrowser.direction = .left
        simpleBrowser.name = "swipe"
        UIApplication.shared.keyWindow?.addGestureRecognizer(simpleBrowser)
        let allOptionsBrowser = UISwipeGestureRecognizer(target: self, action: #selector(startAllOptionsBrowser))
        allOptionsBrowser.numberOfTouchesRequired = 1
        allOptionsBrowser.direction = .right
        allOptionsBrowser.name = "swipe"
        UIApplication.shared.keyWindow?.addGestureRecognizer(allOptionsBrowser)

    }
    
    @objc func startSimpleBrowser(){
        guard window?.rootViewController?.presentedViewController == nil else {
            return // this means browser is already being presented
        }
        let sandboxBrowser = SandboxBrowser()
        presentSandboxBrowser(sandboxBrowser)
    }

    @objc func startAllOptionsBrowser(){
        guard window?.rootViewController?.presentedViewController == nil else {
            return // this means browser is already being presented
        }
        let sandboxBrowser = SandboxBrowser(
            initialPath: URL(fileURLWithPath: NSHomeDirectory()),
            options: SandboxBrowser.Options.allCases
        )
        presentSandboxBrowser(sandboxBrowser)
    }

    func presentSandboxBrowser(_ sandboxBrowser: SandboxBrowser) {
        sandboxBrowser.didSelectFile = { file, vc in
            print(file.name, file.type)
        }
        window?.rootViewController?.present(sandboxBrowser, animated: true, completion: nil)
    }
}

