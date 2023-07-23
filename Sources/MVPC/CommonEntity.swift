//
//  CommonEntity.swift
//  
//
//  Created by Denis Koryttsev on 22.07.23.
//

import CoreUI
import DocumentUI
import SwiftLangUI

public struct CommonEntity<Token>: TextDocument {
    public let typeName: String
    public let interface: ProtocolDecl
    public let dependencies: [ClosureDecl.Arg]
    public let modifiers: [Keyword]

    public static var interfaceImplementation: ImplementationIdentifier { ImplementationIdentifier("\(Self.self).inteface") }

    public init(typeName: String, interface: ProtocolDecl, dependencies: [ClosureDecl.Arg] = [], modifiers: [Keyword] = []) {
        self.typeName = typeName
        self.interface = interface
        self.dependencies = dependencies
        self.modifiers = modifiers
    }

    @Environment(\.indentation) private var indentation

    public var textBody: some TextDocument {
        interface.endingWithNewline(2)
        TypeDecl(name: typeName, modifiers: modifiers + [.final, .class], inherits: [interface.decl.name])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            String.dependencies.commented().endingWithNewline()
            Joined(separator: String.newline, elements: dependencyProperties).endingWithNewline(2)
            Mark.initialization.endingWithNewline(2)
            ClosureDecl(name: "init", args: dependencies, modifiers: modifiers)
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                ForEach(dependencies, separator: .newline) { arg in
                    "self.\(arg.label) = \(arg.argName ?? arg.label)"
                }
            }.endingWithNewline(2)
            Mark(name: interface.decl.name)
            interface.implementation(inExtension: false, with: .context(Self.interfaceImplementation, template: self))
                .startingWithNewline(2)
        }
    }

    private var dependencyProperties: [VarDecl] {
        dependencies.map { VarDecl(name: $0.label, type: $0.type, modifiers: [.private, .let]) }
    }
}
