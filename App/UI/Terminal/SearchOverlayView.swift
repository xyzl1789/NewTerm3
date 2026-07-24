//
//  SearchOverlayView.swift
//  NewTerm (iOS)
//
//  Created by on 24/7/2026.
//

import SwiftUI

struct SearchOverlayView: View {

	@Binding var query: String
	var matchCount: Int
	var currentIndex: Int
	var onNext: () -> Void
	var onPrevious: () -> Void
	var onClose: () -> Void
	var onQueryChange: (String) -> Void

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: 8) {
				Image(systemName: "magnifyingglass")
					.foregroundColor(.secondary)
					.font(.system(size: 14))

				TextField("Search…", text: $query)
					.font(.system(size: 15))
					.textFieldStyle(PlainTextFieldStyle())
					.onChange(of: query) { newValue in
						onQueryChange(newValue)
					}

				if !query.isEmpty {
					Text("\(currentIndex + 1)/\(matchCount)")
						.font(.caption)
						.foregroundColor(.secondary)
						.frame(minWidth: 30)

					Button(action: onPrevious) {
						Image(systemName: "chevron.up")
							.font(.system(size: 12, weight: .semibold))
					}
					.buttonStyle(.borderless)
					.disabled(matchCount == 0)

					Button(action: onNext) {
						Image(systemName: "chevron.down")
							.font(.system(size: 12, weight: .semibold))
					}
					.buttonStyle(.borderless)
					.disabled(matchCount == 0)
				}

				Button(action: onClose) {
					Image(systemName: "xmark")
						.font(.system(size: 12, weight: .medium))
						.foregroundColor(.secondary)
				}
				.buttonStyle(.borderless)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 8)
			.background(.ultraThinMaterial)
			.cornerRadius(10)
			.padding(.horizontal, 6)
			.padding(.top, 6)

			Spacer()
		}
	}

}