//
//  GymbrosApp.swift
//  Gymbros
//
//  Created by Nattapong Sawatraksa on 17/5/2568 BE.
//

import SwiftUI

@main
struct GymbrosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
