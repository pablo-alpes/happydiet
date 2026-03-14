//
//  CaptureSource.swift
//  HappyDiet
//
//  Abstraction layer for meal image capture: Camera, Photo Library, HeyCyan glasses.
//  Enables swapping capture sources without changing Analyze/Diet flows.
//

import SwiftUI
import UIKit

/// Source of meal/diet images. Add new sources by extending this enum.
enum MealCaptureSource: String, CaseIterable {
    case camera
    case photoLibrary
    case heycyan

    var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .photoLibrary: return "Photo Library"
        case .heycyan: return "HeyCyan Glasses"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: return "camera.fill"
        case .photoLibrary: return "photo.on.rectangle"
        case .heycyan: return "eyeglasses"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .camera: return UIImagePickerController.isSourceTypeAvailable(.camera)
        case .photoLibrary: return true
        case .heycyan: return true
        }
    }
}
