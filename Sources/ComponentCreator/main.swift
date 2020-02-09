import Foundation
import RxSwift

guard CommandLine.arguments.count > 2 else {
    fatalError("Less than two files were specified.")
}
let storyboardPath = CommandLine.arguments[1]
let swiftPath = CommandLine.arguments[2]
let storyboardURL = URL(fileURLWithPath: storyboardPath)
guard let storyboardData = try? Data(contentsOf: storyboardURL) else {
    fatalError("Unable to read the file.")
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
    "view": "UIView",
    "constraint": "NSLayoutConstraint"
]
let tagNames = Set(typeMap.keys)
let types = storyboardParser.rx.didStartElement
    .filter { tagNames.contains($0.element) }
    .map { $0.element }
    .map { typeMap[$0]! }
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
let originalSwift = (try? String(contentsOf: URL(fileURLWithPath: swiftPath), encoding: .utf8)) ?? ""
let swift = Observable.zip(subclass, variables)
	.map { (subclass: String, variables: String) -> String in
		if let match = (try! NSRegularExpression(pattern: #"class +\#(subclass) *: *Component.*?\{"#, options: .dotMatchesLineSeparators))
			.firstMatch(in: originalSwift, range: NSRange(location: 0, length: originalSwift.count)) {
			let before = originalSwift.prefix(match.range.location + match.range.length)
			let after = originalSwift.suffix(from: originalSwift.index(originalSwift.startIndex, offsetBy: match.range.location + match.range.length))
			let remaining = after
				.split(separator: "\n")
				.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("@IBOutlet") }
				.joined(separator: "\n")
			return "\(before)\n\t\(variables)\n\(remaining)"
		} else {
			return
				"""
				class \(subclass): Component {
					\(variables)
				}
				
				"""
		}
	}
_ = swift
	.subscribe(onNext: { print($0) })
if !storyboardParser.parse() {
    fatalError("Parsing failed.")
}
