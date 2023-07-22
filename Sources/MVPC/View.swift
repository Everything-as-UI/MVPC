//
//  View.swift
//  
//
//  Created by Denis Koryttsev on 1.04.23.
//

import CoreUI
import DocumentUI
import SwiftLangUI

public struct View: TextDocument {
    public let typeName: String
    public let interface: ProtocolDecl
    public let dependencies: [ClosureDecl.Arg]
    public let modifiers: [Keyword]

    public init(typeName: String,
                interface: ProtocolDecl,
                dependencies: [ClosureDecl.Arg] = [],
                modifiers: [Keyword] = []) {
        self.typeName = typeName
        self.dependencies = dependencies
        self.modifiers = modifiers
        self.interface = interface
    }


    public static let interfaceImplementation: ImplementationIdentifier = "interface"
    public static let uiProperties = ImplementationIdentifier(rawValue: String(describing: Self.self) + ".uiProperties")
    public static let privateFunctions = ImplementationIdentifier(rawValue: String(describing: Self.self) + ".privateFunctions")
    public static let viewDidLoad = ImplementationIdentifier(rawValue: String(describing: Self.self) + ".viewDidLoad")

    @Environment(\.indentation) private var indentation
    @Environment(\.implementationResolver) private var implementationResolver

    public var textBody: some TextDocument {
        interface.endingWithNewline(2)
        TypeDecl(name: typeName, modifiers: modifiers + [.final, .class], inherits: ["UIViewController", interface.decl.name])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            Group {
                String.dependencies.commented().endingWithNewline()
                dependencyProperties.endingWithNewline(2)
                implementationResolver.resolve(with: .context(Self.uiProperties, template: self))
                    .prefix("UI".commented().endingWithNewline())
                    .endingWithNewline(2)
            }
            Mark.initialization.endingWithNewline(2)
            ClosureDecl(name: "init", args: dependencies, modifiers: modifiers)
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                ForEach(dependencies, separator: .newline) { arg in
                    "self.\(arg.label) = \(arg.argName ?? arg.label)"
                }.endingWithNewline()
                "super.init(nibName: nil, bundle: nil)"
            }.endingWithNewline(2)
            """
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            // MARK: Lifecycle

            override func viewDidLoad() {
            \(" ".repeating(indentation))super.viewDidLoad()
            \(implementationResolver.resolve(with: .context(Self.viewDidLoad, template: self)).indent(indentation))
            }


            """
            implementationResolver.resolve(with: .context(Self.privateFunctions, template: self))
                .prefix(Mark(name: "Private").endingWithNewline(2))
                .endingWithNewline(2)
            Group {
                Mark(name: interface.decl.name)
                interface.implementation(inExtension: false, with: .context(Self.interfaceImplementation, template: self))
                    .startingWithNewline(2)
            }
        }
    }

    @TextDocumentBuilder
    private var dependencyProperties: some TextDocument {
        ForEach(dependencies, separator: "\n") {
            VarDecl(name: $0.label, type: $0.type, modifiers: [.private, .let])
        }
    }
}
