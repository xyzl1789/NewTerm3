//
//  SettingsBackgroundView.swift
//  NewTerm (iOS)
//
//  Created on 24/7/2026.
//

import SwiftUI
import PhotosUI
import NewTermCommon

struct SettingsBackgroundView: View {

	@ObservedObject var preferences = Preferences.shared

	@State private var pickedItem: PhotosPickerItem?
	@State private var previewImage: UIImage?

	private let backgroundsDir: URL = {
		let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
		let dir = docs.appendingPathComponent("backgrounds", isDirectory: true)
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		return dir
	}()

	var body: some View {
		Form {
			Section(header: Text("Background Image"),
					footer: Text("Choose an image from your photo library to display behind the terminal.")) {
				PhotosPicker(selection: $pickedItem, matching: .images) {
					Label("Choose Image", systemImage: "photo.on.rectangle")
				}

				if !preferences.backgroundImagePath.isEmpty {
					Button(role: .destructive) {
						clearBackground()
					} label: {
						Label("Remove Image", systemImage: "trash")
					}
				}
			}

			if !preferences.backgroundImagePath.isEmpty {
				Section(header: Text("Preview")) {
					if let img = previewImage {
						Image(uiImage: img)
							.resizable()
							.scaledToFill()
							.frame(maxHeight: 180)
							.clipped()
							.cornerRadius(10)
					} else {
						Rectangle()
							.fill(.secondary.opacity(0.2))
							.frame(height: 120)
							.overlay(Text("No preview").foregroundColor(.secondary))
					}
				}

				Section(header: Text("Appearance")) {
					VStack(alignment: .leading) {
						Text("Opacity: \(Int(preferences.backgroundImageAlpha * 100))%")
						Slider(value: $preferences.backgroundImageAlpha, in: 0...1, step: 0.05)
					}
					Toggle("Apply blur", isOn: $preferences.backgroundImageBlur)
				}
			}
		}
		.navigationTitle("Background")
		.onChange(of: pickedItem) { item in
			guard let item = item else { return }
			loadImage(item: item)
		}
		.onAppear { loadPreview() }
	}

	private func loadImage(item: PhotosPickerItem) {
		Task {
			if let data = try? await item.loadTransferable(type: Data.self),
			   let image = UIImage(data: data) {
				let url = backgroundsDir.appendingPathComponent("bg-\(Int(Date().timeIntervalSince1970)).jpg")
				if let jpgData = image.jpegData(compressionQuality: 0.85) {
					try? jpgData.write(to: url, options: .completeFileProtection)
					preferences.backgroundImagePath = url.path
					previewImage = image
				}
			}
		}
	}

	private func loadPreview() {
		let path = preferences.backgroundImagePath
		guard !path.isEmpty,
			  let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
			  let img = UIImage(data: data) else {
			previewImage = nil
			return
		}
		previewImage = img
	}

	private func clearBackground() {
		let path = preferences.backgroundImagePath
		if !path.isEmpty {
			try? FileManager.default.removeItem(atPath: path)
		}
		preferences.backgroundImagePath = ""
		preferences.backgroundImageAlpha = 0.3
		preferences.backgroundImageBlur = false
		previewImage = nil
	}

}

struct SettingsBackgroundView_Previews: PreviewProvider {
	static var previews: some View {
		NavigationView {
			SettingsBackgroundView()
		}
	}
}
