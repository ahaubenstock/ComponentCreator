import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("Exactly one file and one directory must be specified.")
}
let storyboardPath = CommandLine.arguments[1]
let swiftDirPath = CommandLine.arguments[2]
let storyboardURL = URL(fileURLWithPath: storyboardPath)
guard let storyboard = try? XMLDocument(contentsOf: storyboardURL, options: []) else {
    fatalError("Unable to read the storyboard file.")
}
let viewControllerProperties = (try! storyboard.objects(forXQuery: "for $vc in //viewController[@customClass] return data($vc/@customClass)"))
	.map { $0 as! String }
	.map {(
		$0,
		(try! storyboard.nodes(forXPath: "//scene[objects/viewController/@customClass='\($0)']//*[userDefinedRuntimeAttributes/userDefinedRuntimeAttribute/@keyPath='variableName']")).map { $0 as! XMLElement }
	)}
	.map {(
		viewController: $0.0,
		properties: $0.1
			.map {(
				class: $0.attribute(forName: "customClass")?.stringValue ?? typeMap[$0.name!]!,
				name: ((try! $0.nodes(forXPath: "./userDefinedRuntimeAttributes/userDefinedRuntimeAttribute[@keyPath='variableName']")).first as! XMLElement).attribute(forName: "value")!.stringValue!,
				id: $0.attribute(forName: "id")!.stringValue!
			)}
	)}
viewControllerProperties
	.map {(
		$0.viewController,
		"\t" + $0.properties
			.map { "@IBOutlet weak var \($0.name): \($0.class)!" }
			.joined(separator: "\n\t")
	)}
	.forEach { (subclass: String, variables: String) in
		let swiftPath = "\(swiftDirPath)\(subclass).swift"
		let swiftURL = URL(fileURLWithPath: swiftPath)
		guard var swift = try? String(contentsOf: swiftURL, encoding: .utf8) else {
			return
		}
		if swift.isEmpty { swift = "import UIKit" }
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
		let output =
		"""
		\(before)
		\(variables)
		\(after)
		"""
		print("Writing to \(swiftPath)")
		do {
			try output.write(to: swiftURL, atomically: true, encoding: .utf8)
		} catch let error {
			print("⚠️ \(error.localizedDescription)")
		}
	}
viewControllerProperties
	.map {(
		viewController: $0.viewController,
		properties: $0.properties.map {(
			name: $0.name,
			id: $0.id
		)}
	)}
	.forEach {
		let connections = XMLNode.element(withName: "connections") as! XMLElement
		connections.setChildren(
			$0.properties
				.map {
					let node = XMLNode.element(withName: "outlet") as! XMLElement
					node.setAttributesWith([
						"property": $0.name,
						"destination": $0.id,
						"id": id()
					])
					return node
				}
		)
		let vcNode = try! storyboard.nodes(forXPath: "//viewController[@customClass='\($0.viewController)']").first as! XMLElement
		if let _connections = try? vcNode.nodes(forXPath: "./connections").first {
			vcNode.removeChild(at: _connections.index)
		}
		vcNode.addChild(connections)
	}
print("Writing to \(storyboardPath)")
do {
	try "\(storyboard)".write(to: storyboardURL, atomically: true, encoding: .utf8)
} catch let error {
	print("⚠️ \(error.localizedDescription)")
}

