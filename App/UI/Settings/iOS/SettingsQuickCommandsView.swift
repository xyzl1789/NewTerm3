//
//  SettingsQuickCommandsView.swift
//  NewTerm (iOS)
//
//  Created on 24/7/2026.
//

import SwiftUI
import NewTermCommon

struct SettingsQuickCommandsView: View {

	@ObservedObject var preferences = Preferences.shared
	@State private var commands: [String] = []
	@State private var newItem: String = ""

	private func load() {
		commands = preferences.quickCommands
	}

	private func save() {
		preferences.quickCommands = commands
	}

	var body: some View {
		Form {
			Section(header: Text("Quick Commands"),
					footer: Text("Tap a command in the terminal’s quick panel to send it. Use %@ as a placeholder for inline input.").replacingOccurrences(of: "%@", with: "%")) {
				ForEach(commands.indices, id: \.self) { index in
					HStack {
						TextField("Command", text: Binding(
							get: { commands[index] },
							set: { commands[index] = $0; save() }
						))
						.textFieldStyle(RoundedBorderTextFieldStyle())

						Button(action: {
							commands.remove(at: index)
							save()
						}) {
							Image(systemName: "minus.circle.fill")
								.foregroundColor(.red)
						}
						.buttonStyle(.borderless)
					}
				}
				.onMove { indices, target in
					commands.move(fromOffsets: indices, toOffset: target)
					save()
				}
				.onDelete { indices in
					commands.remove(atOffsets: indices)
					save()
				}

				HStack {
					TextField("Add command…", text: $newItem)
						.textFieldStyle(RoundedBorderTextFieldStyle())
					Button(action: {
						guard !newItem.isEmpty else { return }
						commands.append(newItem)
						newItem = ""
						save()
					}) {
						Image(systemName: "plus.circle.fill")
							.foregroundColor(.accentColor)
					}
					.buttonStyle(.borderless)
					.disabled(newItem.isEmpty)
				}
			}

			Section {
				Button("Reset to Defaults") {
					commands = []
					save()
				}
				.foregroundColor(.red)
			}
		}
		.navigationTitle("Quick Commands")
		.toolbar {
			EditButton()
		}
		.onAppear { load() }
	}

}

struct SettingsQuickCommandsView_Previews: PreviewProvider {
	static var previews: some View {
		NavigationView {
			SettingsQuickCommandsView()
		}
	}
}
