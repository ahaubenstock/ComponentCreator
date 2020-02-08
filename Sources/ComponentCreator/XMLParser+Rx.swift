//
//  File.swift
//  
//
//  Created by Adam E. Haubenstock on 2/8/20.
//

import Foundation
import RxSwift
import RxCocoa

class XMLParserDelegateProxy
    : DelegateProxy<XMLParser, XMLParserDelegate>
    , DelegateProxyType
    , XMLParserDelegate {
    static func currentDelegate(for object: XMLParser) -> XMLParserDelegate? {
        return object.delegate
    }
    
    static func setCurrentDelegate(_ delegate: XMLParserDelegate?, to object: XMLParser) {
        object.delegate = delegate
    }
        
    init(parentObject: XMLParser) {
        super.init(parentObject: parentObject, delegateProxy: XMLParserDelegateProxy.self)
    }
    
    public static func registerKnownImplementations() {
        self.register { XMLParserDelegateProxy(parentObject: $0) }
    }
}

extension Reactive where Base: XMLParser {
    var delegate: XMLParserDelegateProxy {
        XMLParserDelegateProxy.proxy(for: base)
    }
    
    var didStartElement: Observable<(element: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String])> {
        return delegate.methodInvoked(#selector(XMLParserDelegate.parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)))
            .map { ($0[1] as! String, $0[2] as? String, $0[3] as? String, $0[4] as! [String: String]) }
    }
    
    var didEndDocument: Observable<Void> {
        return delegate.methodInvoked(#selector(XMLParserDelegate.parserDidEndDocument(_:)))
            .map { _ in }
    }
}
