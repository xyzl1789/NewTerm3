//
//  ToolbarKey+Extensions.swift
//  NewTerm (iOS)
//
//  Created on 24/7/2026.
//

import Foundation

/// Serializable representation for toolbar layout configuration.
struct ToolbarSectionConfig: Codable, Equatable {
	var keys: [String] // rawValue strings of ToolbarKey
}

extension ToolbarKey {

	/// Unique string identifier for serialization.
	var rawValue: String {
		switch self {
		case .fixedSpace(let id):   return "fixedSpace:\(id)"
		case .variableSpace(let id): return "variableSpace:\(id)"
		case .arrows:               return "arrows"
		case .control:              return "control"
		case .escape:               return "escape"
		case .tab:                  return "tab"
		case .more:                 return "more"
		case .Delete:               return "Delete"
		case .up:                   return "up"
		case .down:                 return "down"
		case .left:                 return "left"
		case .right:                return "right"
		case .home:                 return "home"
		case .end:                  return "end"
		case .pageUp:               return "pageUp"
		case .pageDown:             return "pageDown"
		case .delete:               return "delete"
		case .fnKeys:               return "fnKeys"
		case .fnKey(let index):     return "fnKey:\(index)"
		case .copy:                 return "copy"
		case .paste:                return "paste"
		case .clear:                return "clear"
		case .selectAll:            return "selectAll"
		case .quickActions:         return "quickActions"
		}
	}

	/// Create from raw string. Returns nil for unknown values.
	init?(rawValue: String) {
		switch rawValue {
		case "arrows":          self = .arrows
		case "control":         self = .control
		case "escape":          self = .escape
		case "tab":             self = .tab
		case "more":            self = .more
		case "Delete":          self = .Delete
		case "up":              self = .up
		case "down":            self = .down
		case "left":            self = .left
		case "right":           self = .right
		case "home":            self = .home
		case "end":             self = .end
		case "pageUp":          self = .pageUp
		case "pageDown":        self = .pageDown
		case "delete":          self = .delete
		case "fnKeys":          self = .fnKeys
		case "copy":            self = .copy
		case "paste":           self = .paste
		case "clear":           self = .clear
		case "selectAll":       self = .selectAll
		case "quickActions":    self = .quickActions
		default:
			if rawValue.hasPrefix("fixedSpace:"), let id = Int(rawValue.dropFirst("fixedSpace:".count)) {
				self = .fixedSpace(id: id)
			} else if rawValue.hasPrefix("variableSpace:"), let id = Int(rawValue.dropFirst("variableSpace:".count)) {
				self = .variableSpace(id: id)
			} else if rawValue.hasPrefix("fnKey:"), let index = Int(rawValue.dropFirst("fnKey:".count)) {
				self = .fnKey(index: index)
			} else {
				return nil
			}
		}
	}
}

/// Map toolbar name → list of key raw values for the custom layout preference.
struct CustomToolbarLayout: Codable, Equatable {
	var primary: [String] = Toolbar.primary.keys.map { $0.rawValue }
	var secondary: [String] = Toolbar.secondary.keys.map { $0.rawValue }
	var quickActions: [String] = Toolbar.quickActions.keys.map { $0.rawValue }

	static let `default` = CustomToolbarLayout()

	func decodeKeys(for section: [String]) -> [ToolbarKey] {
		section.compactMap { ToolbarKey(rawValue: $0) }
	}
}