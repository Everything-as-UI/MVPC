//
//  CoordinatorAssembly.swift
//  
//
//  Created by Denis Koryttsev on 1.04.23.
//

import CoreUI
import DocumentUI
import SwiftLangUI

public struct CoordinatorAssembly: TextDocument {
    public let typeName: String
    public let interface: ProtocolDecl
    public let dependencies: [ClosureDecl.Arg]
    public let modifiers: [Keyword]

    public init(typeName: String,
                interface: ProtocolDecl,
                dependencies: [ClosureDecl.Arg] = [],
                modifiers: [Keyword] = []) {
        self.typeName = typeName
        self.interface = interface
        self.dependencies = dependencies
        self.modifiers = modifiers
    }

    public static let interfaceImplementation = ImplementationIdentifier("\(CoordinatorAssembly.self).interface")

    @Environment(\.indentation) private var indentation

    public var textBody: some TextDocument {
        interface.endingWithNewline(2)
        TypeDecl(name: typeName, modifiers: modifiers + [.final, .class], inherits: [interface.decl.name])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            String.dependencies.commented().endingWithNewline()
            dependencyProperties.endingWithNewline(2)
            Mark.initialization.endingWithNewline(2)
            ClosureDecl(name: "init", args: dependencies, modifiers: modifiers)
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                ForEach(dependencies, separator: .newline) { arg in
                    "self.\(arg.label) = \(arg.argName ?? arg.label)"
                }
            }.endingWithNewline(2)
            Mark(name: interface.decl.name)
            interface.implementation(inExtension: false, with: .context(Self.interfaceImplementation, template: self)).startingWithNewline(2)
        }
    }

    @TextDocumentBuilder
    private var dependencyProperties: some TextDocument {
        if dependencies.isEmpty {
            VarDecl(name: "someDep", type: "Lazy<ISomeDep>", modifiers: [.private]).commented()
        } else {
            ForEach(dependencies, separator: .newline) { dep in
                VarDecl(name: dep.label!, type: dep.type, modifiers: [.private, .let])
            }
        }
    }
}
