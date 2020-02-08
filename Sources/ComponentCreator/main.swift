import Foundation
import RxSwift

guard CommandLine.arguments.count > 1 else {
    fatalError("No file was specified.")
}
let file = CommandLine.arguments[1]
let url = URL(fileURLWithPath: file)
guard let data = try? Data(contentsOf: url) else {
    fatalError("Unable to read the file.")
}
let parser = XMLParser(data: data)
let subclass = parser.rx.didStartElement
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
let types = parser.rx.didStartElement
    .filter { tagNames.contains($0.element) }
    .map { $0.element }
    .map { typeMap[$0]! }
let variables = parser.rx.didStartElement
    .filter { $0.element == "userDefinedRuntimeAttribute" }
    .map { $0.attributes }
    .filter { $0.keys.contains("keyPath") }
    .filter { $0["keyPath"] == "variableName" }
    .map { $0["value"]! }
    .withLatestFrom(types) { (name: $0, type: $1) }
    .map { "@IBOutlet weak var \($0.name): \($0.type)!" }
    .takeUntil(parser.rx.didEndDocument)
    .toArray()
    .asObservable()
let swift = Observable.zip(subclass, variables)
    .map {
        """
        //
        // Last Generated: \(Date())
        //
        
        class \($0): Component {
            \($1.joined(separator: "\n\t"))
        }
        
        """
    }
_ = swift
    .subscribe(onNext: { print($0) })
if !parser.parse() {
    fatalError("Parsing failed.")
}
