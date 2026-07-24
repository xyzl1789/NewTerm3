//
//  SettingsKeyboardLayoutView.swift
//  NewTerm (iOS)
//
//  Created on 24/7/2026.
//

import SwiftUI
import NewTermCommon

struct SettingsKeyboardLayoutView: View {

	@ObservedObject var preferences = Preferences.shared
	@State private var layout: CustomToolbarLayout = .default
	@State private var hasCustom: Bool = false

	private let availablePrimary: [ToolbarKey] = [.control, .escape, .tab, .more, .Delete, .arrows, .quickActions, .variableSpace(id: 0)]
	private let availableSecondary: [ToolbarKey] = [.home, .end, .pageUp, .pageDown, .delete, .fnKeys, .variableSpace(id: 0)]
	private let availableQuick: [ToolbarKey] = [.copy, .paste, .selectAll, .clear, .variableSpace(id: 0)]

	var body: some View {
		Form {
			Section(header: Text("Primary Toolbar"), footer: Text("Shown above the keyboard on iPhone.")) {
				listView(keys: Binding(get: { layout.primary }, set: { layout.primary = $0; save() }),
						 available: availablePrimary)
			}
			Section(header: Text("Secondary Toolbar"), footer: Text("Revealed by tapping More.")) {
				listView(keys: Binding(get: { layout.secondary }, set: { layout.secondary = $0; save() }),
						 available: availableSecondary)
			}
			Section(header: Text("Quick Actions")) {
				listView(keys: Binding(get: { layout.quickActions }, set: { layout.quickActions = $0; save() }),
						 available: availableQuick)
			}

			Section {
				Button("Reset to Defaults") { reset() }
					.foregroundColor(.red)
				if hasCustom {
					Button("Disable Custom Layout") { clearCustom() }
						.foregroundColor(.secondary)
				}
			}
		}
		.navigationTitle("Keyboard Layout")
		.toolbar { EditButton() }
		.onAppear { load() }
	}

	@ViewBuilder
	private func listView(keys: Binding<[String]>, available: [ToolbarKey]) -> some View {
		ForEach(keys.wrappedValue.indices, id: \.self) { index in
			HStack {
				let raw = keys.wrappedValue[index]
				Text(displayLabel(for: raw))
					.font(.system(.body, design: .monospaced))
				Spacer()
				Button(action: {
					keys.wrappedValue.remove(at: index)
					save()
				}) {
					Image(systemName: "minus.circle.fill")
						.foregroundColor(.red)
				}
				.buttonStyle(.borderless)
			}
		}
		.onMove { indices, target in
			keys.wrappedValue.move(fromOffsets: indices, toOffset: target)
			save()
		}
		.onDelete { indices in
			keys.wrappedValue.remove(atOffsets: indices)
			save()
		}

		// Add-key picker
		Menu {
			ForEach(available, id: \.self) { key in
				Button(displayLabel(for: key.rawValue)) {
					keys.wrappedValue.append(key.rawValue)
					save()
				}
			}
		} label: {
			Label("Add Key", systemImage: "plus.circle.fill")
				.foregroundColor(.accentColor)
		}
	}

	// MARK: - Helpers

	private func displayLabel(for raw: String) -> String {
		ToolbarKey(rawValue: raw).map { $0.key.label } ?? raw
	}

	private func load() {
		if let data = preferences.customToolbarLayoutData,
		   let decoded = try? JSONDecoder().decode(CustomToolbarLayout.self, from: data) {
			layout = decoded
			hasCustom = true
		} else {
			layout = .default
			hasCustom = false
		}
	}

	private func save() {
		hasCustom = true
		if let data = try? JSONEncoder().encode(layout) {
			preferences.customToolbarLayoutData = data
		}
	}

	private func clearCustom() {
		preferences.customToolbarLayoutData = nil
		layout = .default
		hasCustom = false
	}

	private func reset() {
		layout = .default
		hasCustom = true
		if let data = try? JSONEncoder().encode(layout) {
			preferences.customToolbarLayoutData = data
		}
	}

}

struct SettingsKeyboardLayoutView_Previews: PreviewProvider {
	static var previews: some View {
		NavigationView {
			SettingsKeyboardLayoutView()
		}
	}
}
