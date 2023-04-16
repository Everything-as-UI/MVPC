//
//  Presenter.swift
//  
//
//  Created by Denis Koryttsev on 1.04.23.
//

import CoreUI
import DocumentUI
import SwiftLangUI

public struct Presenter: TextDocument {
    public let typeName: String
    public let interface: ProtocolDecl
    public let viewInterfaceName: String
    public let input: ProtocolDecl?
    public let output: ProtocolDecl?
    public let dependencies: [ClosureDecl.Arg]
    public let args: [ClosureDecl.Arg]
    public let modifiers: [Keyword]

    public init(typeName: String,
                interface: ProtocolDecl,
                viewInterfaceName: String,
                input: ProtocolDecl? = nil,
                output: ProtocolDecl? = nil,
                dependencies: [ClosureDecl.Arg] = [],
                args: [ClosureDecl.Arg] = [],
                modifiers: [Keyword] = []) {
        self.typeName = typeName
        self.interface = interface
        self.viewInterfaceName = viewInterfaceName
        self.input = input
        self.output = output
        self.dependencies = dependencies
        self.args = args
        self.modifiers = modifiers
    }

    public static let interfaceImplementation = ImplementationIdentifier("\(Self.self).inteface")
    public static let inputImplementation = ImplementationIdentifier("\(Self.self).input")

    @Environment(\.indentation) private var indentation

    public var textBody: some TextDocument {
        input.endingWithNewline(2)
        output.endingWithNewline(2)
        interface.endingWithNewline(2)
        TypeDecl(name: typeName, modifiers: modifiers + [.final, .class], inherits: [interface.decl.name])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            String.dependencies.commented().endingWithNewline()
            Joined(separator: String.newline, elements: dependencyProperties).endingWithNewline(2)
            String.properties.commented().endingWithNewline()
            argsProperties.endingWithNewline(2)
            Mark.initialization.endingWithNewline(2)
            ClosureDecl(name: "init", args: dependencies + args, modifiers: modifiers)
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                ForEach(dependencies + args, separator: .newline) { arg in
                    "self.\(arg.name) = \(arg.argName ?? arg.name)"
                }
            }.endingWithNewline(2)
            Mark(name: interface.decl.name)
            interface.implementation(inExtension: false, with: .context(Self.interfaceImplementation, template: self))
                .startingWithNewline(2)
        }
        if let input {
            Mark(name: input.decl.name).startingWithNewline(2).endingWithNewline(2)
            input.extension(type: typeName, with: .context(Self.inputImplementation, template: self))
        }
    }

    private var dependencyProperties: [VarDecl] {
        var vars = [VarDecl(name: "view", type: "\(viewInterfaceName)?", modifiers: [.weak, .var])]
        if let output {
            vars.append(VarDecl(name: "output", type: output.decl.name + "?", modifiers: [.weak, .var]))
        }
        return vars + dependencies.map({ VarDecl(name: $0.name, type: $0.type, modifiers: [.private, .let]) })
    }

    @TextDocumentBuilder
    private var argsProperties: some TextDocument {
        if args.isEmpty {
            VarDecl(name: "someArg", type: "SomeType", modifiers: [.private]).commented()
        } else {
            ForEach(args, separator: .newline) {
                VarDecl(name: $0.name, type: $0.type, modifiers: [.private, .let])
            }
        }
    }
}
