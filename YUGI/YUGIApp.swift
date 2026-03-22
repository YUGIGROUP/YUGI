//
//  YUGIApp.swift
//  YUGI
//
//  Created by EVA PARMAR on 29/05/2025.
//

import SwiftUI
import Firebase

@main
struct YUGIApp: App {
    init() {
        FirebaseApp.configure()
        _ = LocationService.shared // trigger location permission request at app start
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
