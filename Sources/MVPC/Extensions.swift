//
//  String.swift
//  
//
//  Created by Denis Koryttsev on 8.03.23.
//

import Foundation
import DocumentUI
import CoreUI
import SwiftLangUI

extension Mark {
    static let initialization = Mark(name: "Initialization")
}

extension String {
    static let properties = "Properties"
    static let dependencies = "Dependencies"
}

// MARK: SwiftLangUI

public extension ProtocolDecl {
    static func assembly(name: String, args: [ClosureDecl.Arg] = [], result: String, modifiers: [Keyword] = []) -> Self {
        Self(name: name,
             funcs: [Function(name: "assemble", args: args, result: result)],
             modifiers: modifiers)
    }

    static func presenter(name: String, vars: [Var] = [], funcs: [Function] = [], modifiers: [Keyword] = []) -> Self {
        Self(name: name,
             vars: vars,
             funcs: [Function(name: "viewDidLoad")] + funcs,
             modifiers: modifiers)
    }

    static func view(name: String, vars: [Var] = [], funcs: [Function] = [], modifiers: [Keyword] = [], inherits: [String] = []) -> Self {
        Self(name: name,
             vars: vars,
             funcs: funcs,
             modifiers: modifiers,
             inherits: ["AnyObject"] + inherits)
    }

    static func coordinator(name: String, transitionHandlerType: String = "UIViewController", modifiers: [Keyword] = [], inherits: [String] = []) -> Self {
        Self(name: name,
             vars: [
                ProtocolDecl.Var(name: "children", type: "[AnyObject]"), // TODO: remove it
                ProtocolDecl.Var(name: "transitionHandler", type: "\(transitionHandlerType)?")
             ],
             funcs: [Function(name: "start")],
             modifiers: modifiers,
             inherits: ["AnyObject"] + inherits)
    }
}
