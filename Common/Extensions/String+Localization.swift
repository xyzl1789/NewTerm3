//
//  String+Localization.swift
//  NewTerm (iOS)
//
//  Created by Adam Demasi on 3/4/21.
//

import Foundation
import UIKit

// MARK: - Convenience shorthand macros

/// Localized string shorthand. Usage: `L("TERMINAL")`
public func L(_ key: String) -> String {
    String.localize(key, comment: "")
}

/// Localized string with format arguments. Usage: `LF("LOCALE_SYSTEM", localeName)`
public func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: String.localize(key, comment: ""), arguments: args)
}

public extension String {
	static func localize(_ key: String, bundle: Bundle? = nil, tableName: String? = nil, comment: String = "") -> String {
		NSLocalizedString(key, tableName: tableName, bundle: bundle ?? .main, comment: comment)
	}

	private static let uikitBundle = Bundle(for: UIView.self)

	static var ok: String     { .localize("OK",     bundle: uikitBundle) }
	static var done: String   { .localize("Done",   bundle: uikitBundle) }
	static var cancel: String { .localize("Cancel", bundle: uikitBundle) }
	static var close: String  { .localize("Close",  bundle: uikitBundle) }
}
