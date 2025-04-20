//
//  RoamApp.swift
//  Roam
//
//  Created by Joshua Johnson on 2/27/25.
//

import SwiftUI
import GooglePlaces
import Firebase
// https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:didfinishlaunchingwithoptions:)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        GMSPlacesClient.provideAPIKey("")
        FirebaseApp.configure()
        print("AppDelegate's didFinishLaunchingWithOptions is running")
        return true
    }

}
@main
struct RoamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var locationManager = LocationManager()
    @StateObject private var locationViewModel = LocationViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(locationViewModel)
        }
    }
}
