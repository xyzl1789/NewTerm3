//
//  QuickCommandsPanelView.swift
//  NewTerm (iOS)
//
//  Created on 24/7/2026.
//

import SwiftUI
import NewTermCommon

struct QuickCommandsPanelView: View {

	let commands: [String]
	let onSend: (String) -> Void
	let onDismiss: () -> Void

	@State private var showingPlaceholderAlert = false
	@State private var pendingCommand = ""
	@State private var placeholderInput = ""

	var body: some View {
		VStack(spacing: 0) {
			// Grab handle
			RoundedRectangle(cornerRadius: 2.5)
				.fill(.secondary.opacity(0.5))
				.frame(width: 36, height: 5)
				.padding(.top, 8)

			Text("Quick Commands")
				.font(.headline)
				.padding(.top, 8)
				.padding(.bottom, 10)

			if commands.isEmpty {
				VStack(spacing: 6) {
					Image(systemName: "chevron.left.forwardslash.chevron.right")
						.font(.largeTitle)
						.foregroundColor(.secondary)
					Text("No commands configured")
						.font(.subheadline)
						.foregroundColor(.secondary)
					Text("Add them in Settings > Quick Commands")
						.font(.caption)
						.foregroundColor(.tertiary)
				}
				.padding(.vertical, 20)
			} else {
				ScrollView(.vertical, showsIndicators: true) {
					VStack(spacing: 6) {
						ForEach(commands, id: \.self) { cmd in
							Button(action: {
								sendCommand(cmd)
							}) {
								HStack {
									Text(cmd)
										.font(.system(.body, design: .monospaced))
										.lineLimit(1)
									Spacer()
									Image(systemName: "chevron.right")
										.font(.caption)
										.foregroundColor(.secondary)
								}
								.padding(.horizontal, 12)
								.padding(.vertical, 10)
								.background(.regularMaterial)
								.cornerRadius(8)
							}
							.buttonStyle(.plain)
						}
					}
					.padding(.horizontal, 12)
				}
				.frame(maxHeight: 300)
			}

			Divider()
				.padding(.vertical, 4)

			Button(action: onDismiss) {
				Text("Done")
					.fontWeight(.semibold)
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.padding(.horizontal, 12)
			.padding(.bottom, 8)
		}
		.frame(maxHeight: 420)
		.background(.thinMaterial)
		.cornerRadius(16)
		.padding(.horizontal, 16)
		.alert("Enter value", isPresented: $showingPlaceholderAlert) {
			TextField("Value", text: $placeholderInput)
			Button("Send") {
				let resolved = pendingCommand.replacingOccurrences(of: "%", with: placeholderInput)
				onSend(resolved)
				placeholderInput = ""
			}
			Button("Cancel", role: .cancel) {
				placeholderInput = ""
			}
		} message: {
			Text("Enter a value for the placeholder in: \(pendingCommand)")
		}
	}

	private func sendCommand(_ cmd: String) {
		if cmd.contains("%") {
			pendingCommand = cmd
			placeholderInput = ""
			showingPlaceholderAlert = true
		} else {
			onSend(cmd)
		}
	}

}