func endOfCurlyBraceEnclosure<T: StringProtocol>(in text: T) -> Int {
	var stack: [String] = []
	let braces = Set(["{", "}"])
	let opposite = [
		"{": "}",
		"}": "{"
	]
	var offset = 0
	for element in text {
		offset += 1
		let char = String(element)
		if let top = stack.last, char == opposite[top] {
			_ = stack.popLast()
		} else if braces.contains(char) {
			stack.append(char)
		}
		if stack.isEmpty {
			break
		}
	}
	return offset
}

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
	"\("pong" /*Bug in Xcode?*/)PressGestureRecognizer": "UILongPressGestureRecognizer",
	"\("long" /*Just in case*/)PressGestureRecognizer": "UILongPressGestureRecognizer",
	"gestureRecognizer": "UIGestureRecognizer",
]
let tagNames = Set(typeMap.keys)

private let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
func id() -> String {
	func rand(length: Int) -> String {
		return Array(1...length).map { _ in String(chars.randomElement()!) }.joined()
	}
	return "\(rand(length: 3))-\(rand(length: 2))-\(rand(length: 3))"
}
