import Foundation
import RxSwift

guard CommandLine.arguments.count == 3 else {
    fatalError("Exactly two files must be specified.")
}
let storyboardPath = CommandLine.arguments[1]
let swiftPath = CommandLine.arguments[2]
let storyboardURL = URL(fileURLWithPath: storyboardPath)
guard let storyboardData = try? Data(contentsOf: storyboardURL) else {
    fatalError("Unable to read the storyboard file.")
}
let storyboardParser = XMLParser(data: storyboardData)
let subclass = storyboardParser.rx.didStartElement
    .filter { $0.element == "viewController" }
    .map { $0.attributes }
    .map { $0["customClass"]! }
    .filter { $0.hasSuffix("Component") }
    .take(1)
let typeMap = [
	"label": "UILabel",
	"button": "UIButton",
	"segmentedControl": "UISegmentedControl",
	"textField": "UITextField",
	"slider": "UISlider",
	"switch": "UISwitch",
	"activityIndicatorView": "UIActivityIndicatorView",
	"progressView": "UIProgressView",
	"pageControl": "UIPageControl",
	"stepper": "UIStepper",
	"stackView": "UIStackView",
	"tableView": "UITableView",
	"imageView": "UIImageView",
	"collectionView": "UICollectionView",
	"textView": "UITextView",
	"scrollView": "UIScrollView",
	"datePicker": "UIDatePicker",
	"pickerView": "UIPickerView",
	"mapView": "MKMapView",
	"wkWebView": "WKWebView",
	"view": "UIView",
	"containerView": "UIView",
	"searchBar": "UISearchBar",
	"tabBar": "UITabBar",
	"tabBarItem": "UITabBarItem",
	"toolbar": "UIToolbar",
	"barButtonItem": "UIBarButtonItem",
	"navigationBar": "UINavigationBar",
	"navigationItem": "UINavigationItem",
    "constraint": "NSLayoutConstraint",
	"tapGestureRecognizer": "UITapGestureRecognizer",
	"pinchGestureRecognizer": "UIPinchGestureRecognizer",
	"rotationGestureRecognizer": "UIRotationGestureRecognizer",
	"swipeGestureRecognizer": "UISwipeGestureRecognizer",
	"panGestureRecognizer": "UIPanGestureRecognizer",
	"screenEdgePanGestureRecognizer": "UIScreenEdgePanGestureRecognizer",
	"pongPressGestureRecognizer": "UILongPressGestureRecognizer", // Bug in Xcode?
	"longPressGestureRecognizer": "UILongPressGestureRecognizer",
	"gestureRecognizer": "UIGestureRecognizer",
]
let tagNames = Set(typeMap.keys)
let types = storyboardParser.rx.didStartElement
    .filter { tagNames.contains($0.element) }
	.map { $0.attributes["customClass", default: typeMap[$0.element]!] }
let variables = storyboardParser.rx.didStartElement
    .filter { $0.element == "userDefinedRuntimeAttribute" }
    .map { $0.attributes }
    .filter { $0.keys.contains("keyPath") }
    .filter { $0["keyPath"] == "variableName" }
    .map { $0["value"]! }
    .withLatestFrom(types) { (name: $0, type: $1) }
    .map { "@IBOutlet weak var \($0.name): \($0.type)!" }
    .takeUntil(storyboardParser.rx.didEndDocument)
    .toArray()
    .asObservable()
	.map { $0.joined(separator: "\n\t") }
	.map { "\t\($0)" }
let original = Observable.just(swiftPath)
	.map { URL(fileURLWithPath: $0) }
	.map { try? String(contentsOf: $0, encoding: .utf8) }
	.map { $0 ?? "import UIKit" }
let surrounding = Observable.zip(original, subclass)
	.map { (swift: String, subclass: String) -> (String, String) in
		let regex = try! NSRegularExpression(pattern: #"class +\#(subclass) *: *Component.*?\{"#, options: .dotMatchesLineSeparators)
		let searchRange = NSRange(location: 0, length: swift.count)
		let before: String
		let after: String
		if let range = regex.firstMatch(in: swift, range: searchRange)?.range {
			let indexOfClassOpeningBrace = range.location + range.length - 1
			let fromOpeningBrace = swift.suffix(swift.count - indexOfClassOpeningBrace)
			let indexOfClassClosingBrace = indexOfClassOpeningBrace + endOfCurlyBraceEnclosure(in: fromOpeningBrace)
			before = String(swift.prefix(indexOfClassOpeningBrace + 1))
			let start = swift.index(swift.startIndex, offsetBy: indexOfClassOpeningBrace + 1)
			let end = swift.index(swift.startIndex, offsetBy: indexOfClassClosingBrace)
			let restOfClass = swift[start...end]
				.split(separator: "\n")
				.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("@IBOutlet") }
				.joined(separator: "\n")
			let restOfFile = swift.suffix(swift.count - indexOfClassClosingBrace)
			after = "\(restOfClass)\(restOfFile)"
		} else {
			before =
			"""
			\(swift)
			
			class \(subclass): Component {
			"""
			after =
			"""
			}
			
			"""
		}
		return (before, after)
	}
let swift = Observable.zip(variables, surrounding) { ($0, $1.0, $1.1) }
	.map { (variables: String, before: String, after: String) in
		"""
		\(before)
		\(variables)
		\(after)
		"""
	}
_ = swift
	.bind(onNext: {
		do {
			try $0.write(toFile: swiftPath, atomically: true, encoding: .utf8)
		} catch let error {
			print("⚠️ \(error.localizedDescription)")
		}
	})

if !storyboardParser.parse() {
    fatalError("Unable to parse the storyboard file.")
}
