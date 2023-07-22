//
//  Coordinator.swift
//  
//
//  Created by Denis Koryttsev on 1.04.23.
//

import CoreUI
import DocumentUI
import SwiftLangUI

public struct Coordinator: TextDocument {
    public let typeName: String
    public let interface: ProtocolDecl
    public let inputs: [ClosureDecl.Arg]
    public let outputs: [ProtocolDecl]
    public let dependencies: [ClosureDecl.Arg]
    public let args: [ClosureDecl.Arg]
    public let modifiers: [Keyword]

    public init(typeName: String,
                interface: ProtocolDecl,
                inputs: [ClosureDecl.Arg] = [],
                outputs: [ProtocolDecl] = [],
                dependencies: [ClosureDecl.Arg] = [],
                args: [ClosureDecl.Arg] = [],
                modifiers: [Keyword] = []) {
        self.typeName = typeName
        self.interface = interface
        self.inputs = inputs
        self.outputs = outputs
        self.dependencies = dependencies
        self.args = args
        self.modifiers = modifiers
    }

    public static let interfaceImplementation = ImplementationIdentifier("\(Self.self).interface")
    public static let outputImplementation = ImplementationIdentifier("\(Self.self).output")

    @Environment(\.indentation) private var indentation

    public var textBody: some TextDocument {
        interface.endingWithNewline(2)
        TypeDecl(name: typeName, modifiers: modifiers + [.final, .class], inherits: [interface.decl.name])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            Group {
                String.dependencies.commented().endingWithNewline()
                dependencyProperties.endingWithNewline(2)
                String.properties.commented().endingWithNewline()
                argsProperties.endingWithNewline()
            }.endingWithNewline(2)
            Group {
                Mark.initialization.endingWithNewline(2)
                ClosureDecl(name: "init", args: dependencies + args, modifiers: modifiers)
                Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                    ForEach(dependencies + args, separator: .newline) { arg in
                        "self.\(arg.label) = \(arg.argName ?? arg.label)"
                    }
                }
            }.endingWithNewline(2)
            Group {
                Mark(name: interface.decl.name).endingWithNewline(2)
                interface.implementation(inExtension: false, with: .context(Self.interfaceImplementation, template: self))
            }
        }
        ForEach(outputs, separator: .newline + .newline) { output in
            Mark(name: output.decl.name).endingWithNewline(2)
            output.extension(type: typeName, with: .context(Self.outputImplementation, template: self))
        }.startingWithNewline(2)
    }

    private var moduleInputs: [VarDecl] {
        inputs.map {
            VarDecl(name: $0.label, type: "\($0.type)?", modifiers: [.weak, .var])
        }
    }

    @TextDocumentBuilder
    private var dependencyProperties: some TextDocument {
        Joined(separator: String.newline, elements: moduleInputs + dependencies.map {
            VarDecl(name: $0.label, type: $0.type, modifiers: [.private, .let])
        })
    }

    @TextDocumentBuilder
    private var argsProperties: some TextDocument {
        Joined(separator: String.newline, elements: args.map {
            VarDecl(name: $0.label, type: $0.type, modifiers: [.private, .let])
        })
    }
}
