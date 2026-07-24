//
//  TerminalSessionViewController.swift
//  NewTerm
//
//  Created by Adam Demasi on 10/1/18.
//  Copyright © 2018 HASHBANG Productions. All rights reserved.
//

import UIKit
import os.log
import CoreServices
import SwiftUIX
import SwiftUI
import SwiftTerm
import NewTermCommon
import Combine

// MARK: - Search State

class SearchState: ObservableObject {
	@Published var query = ""
	@Published var matchCount = 0
	@Published var currentIndex = 0
	var matchingRows = [Int]()
}

class TerminalSessionViewController: BaseTerminalSplitViewControllerChild {

    var keyboardToolbarHeightChanged: ((Double) -> Void)?

	var initialCommand: String?

	override var isSplitViewResizing: Bool {
		didSet { updateIsSplitViewResizing() }
	}
	override var showsTitleView: Bool {
		didSet { updateShowsTitleView() }
	}
	override var screenSize: ScreenSize? {
		get { terminalController.screenSize }
		set { terminalController.screenSize = newValue }
	}

	private var terminalController = TerminalController()
	private var keyInput = TerminalKeyInput(frame: .zero)
    private var textView: UIView!
    private var tableView: UITableView!
	private var textViewTapGestureRecognizer: UITapGestureRecognizer!
    private var pinchGestureRecognizer: UIPinchGestureRecognizer!
    private var pinchStartFontSize: Double = 12
    
	private var state = TerminalState()
    private var lines = [BufferLine]()
    private var cursor = (x:Int(-1), y:Int(-1))

	private var hudState = HUDViewState()
	private var hudView: UIHostingView<AnyView>!

	// Search state
	private var searchVisible = false
	private var searchView: UIHostingView<AnyView>!
	private let searchState = SearchState()

	// Quick Commands state
	private var quickCommandsButton: UIButton!
	private var quickCommandsPanel: UIHostingView<AnyView>?
	private var quickCommandsPanelVisible = false

	private var hasAppeared = false
	private var hasStarted = false
	private var failureError: Error?

	private var lastAutomaticScrollOffset = CGPoint.zero
	private var invertScrollToTop = false
    private var isPickingFileForUpload = false

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

		terminalController.delegate = self

		do {
			try terminalController.startSubProcess()
			hasStarted = true
		} catch {
			failureError = error
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		super.loadView()

		title = .localize("TERMINAL", comment: "Generic title displayed before the terminal sets a proper title.")

		preferencesUpdated()

        tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.separatorInset = .zero
        tableView.backgroundColor = UIColor.clear

        textView = tableView

		textViewTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTextViewTap(_:)))
		textViewTapGestureRecognizer.delegate = self
		textView.addGestureRecognizer(textViewTapGestureRecognizer)

        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinchGesture(_:)))
        pinchGestureRecognizer.delegate = self
        textView.addGestureRecognizer(pinchGestureRecognizer)

		keyInput.frame = view.bounds
		keyInput.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		keyInput.textView = textView
        keyInput.keyboardToolbarHeightChanged = { height in
            self.keyboardToolbarHeightChanged?(height)
        }
		keyInput.terminalInputDelegate = terminalController
		view.addSubview(keyInput)

		// Floating Quick Commands button + panel
		let qcButton = UIButton(type: .system)
		qcButton.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
		qcButton.tintColor = .tint
		qcButton.translatesAutoresizingMaskIntoConstraints = false
		qcButton.addTarget(self, action: #selector(toggleQuickCommandsPanel), for: .touchUpInside)
		view.addSubview(qcButton)
		self.quickCommandsButton = qcButton
		NSLayoutConstraint.activate([
			qcButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
			qcButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
			qcButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),
			qcButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
		])
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		hudView = UIHostingView(rootView: AnyView(
			HUDView()
				.environmentObject(self.hudState)
		))
		hudView.translatesAutoresizingMaskIntoConstraints = false
		hudView.shouldResizeToFitContent = true
		hudView.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
		hudView.setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
		view.addSubview(hudView)

		NSLayoutConstraint.activate([
			hudView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			hudView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
		])

		// Search overlay
		searchView = UIHostingView(rootView: AnyView(
			SearchOverlayView(
				query: self.searchState.$query,
				matchCount: self.searchState.matchCount,
				currentIndex: self.searchState.currentIndex,
				onNext: { [weak self] in self?.searchNext() },
				onPrevious: { [weak self] in self?.searchPrevious() },
				onClose: { [weak self] in self?.hideSearch() },
				onQueryChange: { [weak self] q in self?.runSearch(query: q) }
			)
			.environmentObject(self.searchState)
		))
		searchView.translatesAutoresizingMaskIntoConstraints = false
		searchView.backgroundColor = UIColor.clear
		searchView.isUserInteractionEnabled = true
		searchView.isHidden = true
		view.addSubview(searchView)

		NSLayoutConstraint.activate([
			searchView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			searchView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			searchView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			searchView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])

		addKeyCommand(UIKeyCommand(title: .localize("CLEAR_TERMINAL", comment: "VoiceOver label for a button that clears the terminal."),
															 image: UIImage(systemName: "text.badge.xmark"),
															 action: #selector(self.clearTerminal),
															 input: "k",
															 modifierFlags: .command))

		// Cmd+F toggles search
		addKeyCommand(UIKeyCommand(title: "Find…",
															 image: UIImage(systemName: "magnifyingglass"),
															 action: #selector(self.toggleSearch),
															 input: "f",
															 modifierFlags: .command))

		#if !targetEnvironment(macCatalyst)
		addKeyCommand(UIKeyCommand(title: .localize("PASSWORD_MANAGER", comment: "VoiceOver label for the password manager button."),
															 image: UIImage(systemName: "key.fill"),
															 action: #selector(self.activatePasswordManager),
															 input: "f",
															 modifierFlags: [ .command ]))
		#endif

		if UIApplication.shared.supportsMultipleScenes {
			NotificationCenter.default.addObserver(self, selector: #selector(self.sceneDidEnterBackground), name: UIWindowScene.didEnterBackgroundNotification, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(self.sceneWillEnterForeground), name: UIWindowScene.willEnterForegroundNotification, object: nil)
		}

		NotificationCenter.default.addObserver(self, selector: #selector(self.preferencesUpdated), name: Preferences.didChangeNotification, object: nil)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		keyInput.becomeFirstResponder()
		terminalController.terminalWillAppear()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		hasAppeared = true

		if let error = failureError {
			didReceiveError(error: error)
		} else {
			if let initialCommand = initialCommand?.data(using: .utf8) {
				terminalController.write(initialCommand + EscapeSequences.return)
			}
		}

		initialCommand = nil
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		keyInput.resignFirstResponder()
		terminalController.terminalWillDisappear()
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		hasAppeared = false
	}
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if UIDevice.current.userInterfaceIdiom == .pad {
            if keyInput.isFirstResponder {
                keyInput.resignFirstResponder()
            }
        }
    }

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		updateScreenSize()
	}

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

	override func viewSafeAreaInsetsDidChange() {
		super.viewSafeAreaInsetsDidChange()
	}

	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
	}

	override func removeFromParent() {
		if hasStarted {
			do {
				try terminalController.stopSubProcess()
			} catch {
				Logger().error("Failed to stop subprocess: \(String(describing: error))")
			}
		}

		super.removeFromParent()
	}

	// MARK: - Screen

	func updateScreenSize() {
		if isSplitViewResizing {
			return
		}

		// Determine the screen size based on the font size
        var layoutSize = self.view.safeAreaLayoutGuide.layoutFrame.size
		layoutSize.width -= TerminalView.horizontalSpacing * 2
		layoutSize.height -= TerminalView.verticalSpacing * 2

		if layoutSize.width <= 0 || layoutSize.height <= 0 {
			// Not laid out yet. We’ll be called again when we are.
			return
		}
        
        let layoutFrame1 = self.view.safeAreaLayoutGuide.layoutFrame
        if layoutFrame1.origin.x < 0 || layoutFrame1.origin.y < 0 {
            //in layouting
            return
        }
        let layoutFrame2 = self.textView.safeAreaLayoutGuide.layoutFrame
        if layoutFrame2.origin.x < 0 || layoutFrame2.origin.y < 0 {
            //in layouting
            return
        }

		let glyphSize = terminalController.fontMetrics.boundingBox
		if glyphSize.width == 0 || glyphSize.height == 0 {
			fatalError("Failed to get glyph size")
		}

		let newSize = ScreenSize(cols: UInt16(layoutSize.width / glyphSize.width),
														 rows: UInt16(layoutSize.height / glyphSize.height.rounded(.up)),
														 cellSize: glyphSize)
		if screenSize != newSize {
			screenSize = newSize
			delegate?.terminal(viewController: self, screenSizeDidChange: newSize)
		}
        else {
            //when layout size changes, always scroll even if rows/columns don't change
            self.scroll(animated: true)
        }
	}

	@objc func clearTerminal() {
		terminalController.clearTerminal()
	}

	// MARK: - Search

	@objc func toggleSearch() {
		if searchView.isHidden {
			showSearch()
		} else {
			hideSearch()
		}
	}

	private func showSearch() {
		searchView.isHidden = false
		searchVisible = true
		searchState.query = ""
		searchState.matchCount = 0
		searchState.currentIndex = 0
		searchState.matchingRows = []
		// Focus the field by finding the SwiftUI-hosted UITextField
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
			guard let self = self else { return }
			if let textField = self.findFirstSubview(ofType: UITextField.self, in: self.searchView) {
				textField.becomeFirstResponder()
			}
		}
	}

	/// Recursively search for the first subview matching the given type.
	private func findFirstSubview<T: UIView>(ofType type: T.Type, in view: UIView) -> T? {
		if let typed = view as? T { return typed }
		for sub in view.subviews {
			if let found = findFirstSubview(ofType: type, in: sub) {
				return found
			}
		}
		return nil
	}

	private func hideSearch() {
		searchView.isHidden = true
		searchVisible = false
		searchState.query = ""
		searchState.matchCount = 0
		searchState.currentIndex = 0
		searchState.matchingRows = []
		tableView.reloadData()
	}

	private func runSearch(query: String) {
		guard !query.isEmpty else {
			searchState.matchingRows = []
			searchState.matchCount = 0
			searchState.currentIndex = 0
			tableView.reloadData()
			return
		}
		// Run on terminal queue to read buffer safely
		terminalController.terminalQueue.async { [weak self] in
			let rows = self?.terminalController.searchLines(matching: query) ?? []
			DispatchQueue.main.async {
				guard let self = self else { return }
				self.searchState.matchingRows = rows
				self.searchState.matchCount = rows.count
				self.searchState.currentIndex = rows.isEmpty ? 0 : 0
				self.tableView.reloadData()
				if !rows.isEmpty {
					self.scrollToMatch(index: 0)
				}
			}
		}
	}

	private func searchNext() {
		guard !searchState.matchingRows.isEmpty else { return }
		let next = (searchState.currentIndex + 1) % searchState.matchingRows.count
		searchState.currentIndex = next
		scrollToMatch(index: next)
	}

	private func searchPrevious() {
		guard !searchState.matchingRows.isEmpty else { return }
		let prev = (searchState.currentIndex - 1 + searchState.matchingRows.count) % searchState.matchingRows.count
		searchState.currentIndex = prev
		scrollToMatch(index: prev)
	}

	private func scrollToMatch(index: Int) {
		guard index >= 0 && index < searchState.matchingRows.count else { return }
		let row = searchState.matchingRows[index]
		guard row >= 0 && row < lines.count else { return }
		tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .middle, animated: true)
	}

	var isSearchVisible: Bool { searchVisible }
	var currentSearchMatchingRows: [Int] { searchState.matchingRows }

	// MARK: - Quick Commands

	@objc func toggleQuickCommandsPanel() {
		if quickCommandsPanelVisible {
			hideQuickCommandsPanel()
		} else {
			showQuickCommandsPanel()
		}
	}

	private func showQuickCommandsPanel() {
		guard quickCommandsPanel == nil else { return }
		let panel = QuickCommandsPanelView(
			commands: Preferences.shared.quickCommands,
			onSend: { [weak self] cmd in self?.sendQuickCommand(cmd) },
			onDismiss: { [weak self] in self?.hideQuickCommandsPanel() }
		)
		let host = UIHostingView(rootView: AnyView(panel))
		host.translatesAutoresizingMaskIntoConstraints = false
		host.backgroundColor = UIColor.clear
		host.layer.cornerRadius = 16
		host.clipsToBounds = true
		view.addSubview(host)
		NSLayoutConstraint.activate([
			host.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
			host.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
			host.widthAnchor.constraint(lessThanOrEqualToConstant: 320)
		])
		quickCommandsPanel = host
		quickCommandsPanelVisible = true
	}

	private func hideQuickCommandsPanel() {
		quickCommandsPanel?.removeFromSuperview()
		quickCommandsPanel = nil
		quickCommandsPanelVisible = false
	}

	private func sendQuickCommand(_ cmd: String) {
		let payload = cmd + "\r"
		if let data = payload.data(using: .utf8) {
			terminalController.write(data)
		}
		hideQuickCommandsPanel()
	}

	private func updateIsSplitViewResizing() {
		state.isSplitViewResizing = isSplitViewResizing

		if !isSplitViewResizing {
			updateScreenSize()
		}
	}

	private func updateShowsTitleView() {
		updateScreenSize()
	}

	// MARK: - Gestures

	@objc private func handleTextViewTap(_ gestureRecognizer: UITapGestureRecognizer) {
		guard gestureRecognizer.state == .ended else { return }

		let point = gestureRecognizer.location(in: tableView)

		// Try URL detection first
		if let indexPath = tableView.indexPathForRow(at: point),
			 indexPath.row < lines.count,
			 let terminal = terminalController.terminal {
			let text = getLineText(row: indexPath.row, terminal: terminal)
			if let urls = detectURLs(in: text) {
				let cellWidth = terminalController.fontMetrics.boundingBox.width
				if cellWidth > 0 {
					let column = max(0, Int(point.x / cellWidth))
					for urlResult in urls {
						let nsRange = urlResult.range
						if column >= nsRange.location && column < nsRange.location + nsRange.length {
							UIApplication.shared.open(urlResult.url)
							return
						}
					}
				}
			}
		}

		// No URL tapped, activate keyboard as before
		if !keyInput.isFirstResponder {
			keyInput.becomeFirstResponder()
			delegate?.terminalDidBecomeActive(viewController: self)
		}
	}

	// MARK: - URL Detection

	private func detectURLs(in text: String) -> [(url: URL, range: NSRange)]? {
		let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
		let nsText = text as NSString
		let matches = detector?.matches(in: text, range: NSRange(location: 0, length: nsText.length))
		return matches?.compactMap {
			guard let url = $0.url else { return nil }
			return (url, $0.range)
		}
	}

	private func getLineText(row: Int, terminal: Terminal) -> String {
		let cols = Int(terminal.cols)
		let start = Position(col: 0, row: row)
		let end = Position(col: cols, row: row + 1)
		return terminal.getText(start: start, end: end)
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}

    @objc private func handlePinchGesture(_ gestureRecognizer: UIPinchGestureRecognizer) {
        let prefs = Preferences.shared
        switch gestureRecognizer.state {
        case .began:
            pinchStartFontSize = prefs.fontSize
            gestureRecognizer.scale = 1
        case .changed:
            let scale = gestureRecognizer.scale
            let newSize = max(6, min(36, round(pinchStartFontSize * scale)))
            prefs.fontSize = newSize
        default:
            break
        }
    }

	// MARK: - Lifecycle

	@objc private func sceneDidEnterBackground(_ notification: Notification) {
		if notification.object as? UIWindowScene == view.window?.windowScene {
			terminalController.windowDidEnterBackground()
		}
	}

	@objc private func sceneWillEnterForeground(_ notification: Notification) {
		if notification.object as? UIWindowScene == view.window?.windowScene {
			terminalController.windowWillEnterForeground()
		}
	}

	@objc private func preferencesUpdated() {
		state.fontMetrics = terminalController.fontMetrics
		state.colorMap = terminalController.colorMap
		state.backgroundImagePath = Preferences.shared.backgroundImagePath
		state.backgroundImageAlpha = Preferences.shared.backgroundImageAlpha
		state.backgroundImageBlur = Preferences.shared.backgroundImageBlur
	}
}

extension TerminalSessionViewController: TerminalControllerDelegate {

    func refresh(lines: inout [AnyView]) {
        state.lines = lines
        self.scroll()
    }
    
    func refresh(lines: inout [BufferLine], cursor: (Int,Int)) {
        self.lines = lines
        self.cursor = cursor
        self.tableView.reloadData()
        self.scroll()
	}

    func scroll(animated: Bool = false) {
        state.scroll += 1

        let lastRow = self.tableView.numberOfRows(inSection: 0) - 1
        if lastRow >= 0 {
            let indexPath = IndexPath(row: lastRow, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
        }
    }

	func activateBell() {
		if Preferences.shared.bellHUD {
			hudState.isVisible = true
		}

		HapticController.playBell()
	}

	func titleDidChange(_ title: String?, isDirty: Bool, hasBell: Bool) {
		let newTitle = title ?? .localize("TERMINAL", comment: "Generic title displayed before the terminal sets a proper title.")
		delegate?.terminal(viewController: self,
											 titleDidChange: newTitle,
											 isDirty: isDirty,
											 hasBell: hasBell)
	}

	func currentFileDidChange(_ url: URL?, inWorkingDirectory workingDirectoryURL: URL?) {
		#if targetEnvironment(macCatalyst)
		if let windowScene = view.window?.windowScene {
			windowScene.titlebar?.representedURL = url
		}
		#endif
	}

	func saveFile(url: URL) {
		let viewController = UIDocumentPickerViewController(forExporting: [url], asCopy: false)
		viewController.delegate = self
		present(viewController, animated: true, completion: nil)
	}

	func fileUploadRequested() {
		isPickingFileForUpload = true

		let viewController = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .directory])
		viewController.delegate = self
		present(viewController, animated: true, completion: nil)
	}

	@objc func activatePasswordManager() {
		keyInput.activatePasswordManager()
	}

	@objc func close() {
		if let splitViewController = parent as? TerminalSplitViewController {
			splitViewController.remove(viewController: self)
		}
	}

	func didReceiveError(error: Error) {
		if !hasAppeared {
			failureError = error
			return
		}
		failureError = nil

		let alertController = UIAlertController(title: .localize("TERMINAL_LAUNCH_FAILED_TITLE", comment: "Alert title displayed when a terminal could not be launched."),
																						message: .localize("TERMINAL_LAUNCH_FAILED_BODY", comment: "Alert body displayed when a terminal could not be launched."),
																						preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: .ok, style: .cancel, handler: nil))
		present(alertController, animated: true, completion: nil)
	}

}

extension TerminalSessionViewController: UIGestureRecognizerDelegate {

	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		// This allows the tap-to-activate-keyboard gesture to work without conflicting with UIKit’s
		// internal text view/scroll view gestures… as much as we can avoid conflicting, at least.
		return gestureRecognizer == textViewTapGestureRecognizer
			&& (!(otherGestureRecognizer is UITapGestureRecognizer) || keyInput.isFirstResponder)
	}
}

extension TerminalSessionViewController: UIDocumentPickerDelegate {

	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		guard isPickingFileForUpload,
					let url = urls.first else {
			return
		}
		terminalController.uploadFile(url: url)
		isPickingFileForUpload = false
	}

	func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
		if isPickingFileForUpload {
			isPickingFileForUpload = false
			terminalController.cancelUploadRequest()
		} else {
			// The system will clean up the temp directory for us eventually anyway, but still delete the
			// downloads temp directory now so the file doesn’t linger around till then.
			terminalController.deleteDownloadCache()
		}
	}

}

class SwiftUITableViewCell: UITableViewCell {
    func configure(with view: AnyView) {
        let hostingView = UIHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
//            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        self.backgroundColor = UIColor.clear
        contentView.backgroundColor = UIColor.clear
        hostingView.backgroundColor = UIColor.clear
    }
}

extension TerminalSessionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
}

extension TerminalSessionViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.lines.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = SwiftUITableViewCell()
        let line = self.lines[indexPath.row]
        let view = terminalController.stringSupplier.attributedString(line: line, cursorX: indexPath.row==cursor.y ? cursor.x : -1)
        // Wrap with search highlight if needed
        if searchVisible && searchState.matchingRows.contains(indexPath.row) {
            let isCurrent = searchState.matchingRows.indices.contains(searchState.currentIndex) && searchState.matchingRows[searchState.currentIndex] == indexPath.row
            let bgColor: SwiftUI.Color = isCurrent ? SwiftUI.Color.yellow.opacity(0.45) : SwiftUI.Color.yellow.opacity(0.25)
            cell.configure(with: AnyView(view.background(bgColor)))
            return cell
        }
        cell.configure(with: view)
        return cell
    }
    
}
