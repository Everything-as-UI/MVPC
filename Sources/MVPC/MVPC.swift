//
//  MVPC.swift
//
//
//  Created by Denis Koryttsev on 5.02.23.
//

import CoreUI
import DocumentUI
import SwiftLangUI

public struct AssemblyTemplate: TextDocument {
    public let moduleName: String
    public let hasInput: Bool
    public let outputTypeName: String?
    public let dependencies: [ClosureDecl.Arg]
    public let args: [ClosureDecl.Arg]
    public let modifiers: [Keyword]

    @Environment(\.indentation) private var indentation

    public init(moduleName: String, hasInput: Bool = false, outputTypeName: String? = nil,
                dependencies: [ClosureDecl.Arg] = [], args: [ClosureDecl.Arg] = [], modifiers: [Keyword] = []) {
        self.moduleName = moduleName
        self.hasInput = hasInput
        self.outputTypeName = outputTypeName
        self.args = args
        self.modifiers = modifiers
        self.dependencies = dependencies
    }

    public var interfaceTypeName: String {
        "I\(moduleName)Assembly"
    }

    public var typeName: String {
        "I\(moduleName)Assembly"
    }

    public var textBody: some TextDocument {
        TypeDecl(name: interfaceTypeName, modifiers: modifiers + [.protocol])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            assembleFunc
        }.endingWithNewline(2)
        TypeDecl(name: typeName, modifiers: modifiers + [.final, .class], inherits: [interfaceTypeName])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            String.dependencies.commented().endingWithNewline()
            dependencyProperties.endingWithNewline(2)
            Mark.initialization.endingWithNewline(2)
            ClosureDecl(name: "init", args: dependencies, modifiers: modifiers)
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                ForEach(dependencies, separator: .newline) { arg in
                    "self.\(arg.name) = \(arg.argName ?? arg.name)"
                }
            }.endingWithNewline(2)
            Mark(name: interfaceTypeName).endingWithNewline(2)
            assembleFunc
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                """
                let presenter = \(presenterInit)
                let view = \(moduleName)ViewController(presenter: presenter)
                presenter.view = view
                """.endingWithNewline()
                if outputTypeName != nil {
                    "presenter.output = output".endingWithNewline()
                }
                """
                return \(hasInput ? "Module(viewController: view, moduleInput: presenter)" : "view")
                """.startingWithNewline()
            }
        }
    }

    @TextDocumentBuilder
    private var assembleFunc: some TextDocument {
        ClosureDecl(name: "assemble", args: assemblyArgs, result: assemblyResult, modifiers: modifiers + [.func])
    }

    private var assemblyResult: String {
        hasInput ? "Module<\(moduleName)Input>" : "UIViewController"
    }

    private var assemblyArgs: [ClosureDecl.Arg] {
        guard let outputTypeName else { return args }
        return args + [ClosureDecl.Arg(name: "output", type: outputTypeName)]
    }

    @TextDocumentBuilder
    private var dependencyProperties: some TextDocument {
        if dependencies.isEmpty {
            VarDecl(name: "someDep", type: "Lazy<ISomeDep>", modifiers: [.private]).commented()
        } else {
            ForEach(dependencies, separator: .newline) { dep in
                VarDecl(name: dep.name, type: dep.type, modifiers: [.private, .let])
            }
        }
    }

    @TextDocumentBuilder
    private var presenterInit: some TextDocument {
        "\(moduleName)Presenter"
        Brackets(parenthesis: .round) {
            ForEach(dependencies + args, separator: .commaSpace) { dep in
                "\(dep.name): \(dep.name)"
            }
        }
    }
}


public struct PresenterTemplate: TextDocument {
    public let moduleName: String
    public let hasInput: Bool
    public let output: ProtocolDecl?
    public let dependencies: [ClosureDecl.Arg]
    public let args: [ClosureDecl.Arg]
    public let funcs: [ClosureDecl]
    public let modifiers: [Keyword]

    public init(moduleName: String, hasInput: Bool = false, output: ProtocolDecl? = nil,
         dependencies: [ClosureDecl.Arg] = [], args: [ClosureDecl.Arg] = [], funcs: [ClosureDecl] = [],
         modifiers: [Keyword] = []) {
        self.moduleName = moduleName
        self.hasInput = hasInput
        self.output = output
        self.dependencies = dependencies
        self.args = args
        self.funcs = funcs
        self.modifiers = modifiers
    }

    public var interfaceTypeName: String {
        "I\(moduleName)Presenter"
    }

    public var typeName: String {
        "\(moduleName)Presenter"
    }

    @Environment(\.indentation) private var indentation

    public var textBody: some TextDocument {
        if hasInput {
            inputProtocol.endingWithNewline(2)
        }
        if let output {
            output.endingWithNewline(2)
        }
        TypeDecl(name: interfaceTypeName, modifiers: modifiers + [.protocol])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            Joined(separator: String.newline, elements: funcs)
        }.endingWithNewline(2)
        TypeDecl(name: typeName, modifiers: modifiers + [.final, .class], inherits: [interfaceTypeName])
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
            Mark(name: interfaceTypeName)
            ForEach(funcs, separator: .newline.repeating(2)) {
                $0
                Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {}
            }.startingWithNewline(2)
        }
        if hasInput {
            Mark(name: "\(moduleName)Input").startingWithNewline(2).endingWithNewline(2)
            TypeDecl(name: typeName, modifiers: [.extension], inherits: ["\(moduleName)Input"])
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {}
        }
    }

    private var dependencyProperties: [VarDecl] {
        var vars = [VarDecl(name: "view", type: "I\(moduleName)View?", modifiers: [.weak, .var])]
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

    @TextDocumentBuilder
    private var inputProtocol: some TextDocument {
        TypeDecl(name: "\(moduleName)Input", modifiers: modifiers + [.protocol], inherits: ["AnyObject"])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {}
    }
}


public struct ViewTemplate: TextDocument {
    public let moduleName: String
    public let dependencies: [ClosureDecl.Arg]
    public let funcs: [ClosureDecl]
    public let modifiers: [Keyword]

    public init(moduleName: String, dependencies: [ClosureDecl.Arg] = [], funcs: [ClosureDecl] = [], modifiers: [Keyword] = []) {
        self.moduleName = moduleName
        self.dependencies = dependencies
        self.funcs = funcs
        self.modifiers = modifiers
    }

    public var interfaceTypeName: String {
        "I\(moduleName)View"
    }

    public var typeName: String {
        "\(moduleName)ViewController"
    }

    @Environment(\.indentation) private var indentation

    public var textBody: some TextDocument {
        TypeDecl(name: interfaceTypeName, modifiers: modifiers + [.protocol], inherits: ["AnyObject"])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            Joined(separator: String.newline, elements: funcs)
        }.endingWithNewline(2)
        TypeDecl(name: typeName, modifiers: modifiers + [.final, .class], inherits: ["UIViewController", interfaceTypeName])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            String.dependencies.commented().endingWithNewline()
            dependencyProperties.endingWithNewline(2)
            if !dependencies.isEmpty {
                Mark.initialization.endingWithNewline(2)
                ClosureDecl(name: "init", args: dependencies, modifiers: modifiers)
                Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                    ForEach(dependencies, separator: .newline) { arg in
                        "self.\(arg.name) = \(arg.argName ?? arg.name)"
                    }.endingWithNewline()
                    "super.init(nibName: nil, bundle: nil)"
                }.endingWithNewline(2)
                """
                required init?(coder: NSCoder) {
                    fatalError("init(coder:) has not been implemented")
                }

                """
            }
            """
            // MARK: Lifecycle

            override func viewDidLoad() {
                super.viewDidLoad()
                setupUI()
                presenter.viewDidLoad()
            }

            // MARK: Private

            private func setupUI() {
            }
            """.endingWithNewline(2)
            Mark(name: interfaceTypeName)
            ForEach(funcs, separator: .newline.repeating(2)) {
                $0.parenthical(.curve.prefixed(.space))
            }.startingWithNewline(2).endingWithNewline(2)
        }
    }

    @TextDocumentBuilder
    private var dependencyProperties: some TextDocument {
        let presenterDep = ClosureDecl.Arg(name: "presenter", type: "I\(moduleName)Presenter")
        ForEach([presenterDep] + dependencies, separator: "\n") {
            VarDecl(name: $0.name, type: $0.type, modifiers: [.private, .let])
        }
    }
}


public struct CoordinatorTemplate: TextDocument {
    public let moduleName: String
    public let startAssembly: StartAssembly
    public let dependencies: [ClosureDecl.Arg]
    public let args: [ClosureDecl.Arg]
    public let modifiers: [Keyword]

    public struct StartAssembly {
        public let isModule: Bool
        public let output: ProtocolDecl?

        public init(isModule: Bool, output: ProtocolDecl? = nil) {
            self.isModule = isModule
            self.output = output
        }
    }

    public init(moduleName: String, startAssembly: StartAssembly, dependencies: [ClosureDecl.Arg] = [], args: [ClosureDecl.Arg] = [], modifiers: [Keyword] = []) {
        self.moduleName = moduleName
        self.startAssembly = startAssembly
        self.dependencies = dependencies
        self.args = args
        self.modifiers = modifiers
    }

    public var interfaceTypeName: String {
        "I\(moduleName)Coordinator"
    }

    public var typeName: String {
        "\(moduleName)Coordinator"
    }

    @Environment(\.indentation) private var indentation

    public var textBody: some TextDocument {
        TypeDecl(name: interfaceTypeName, modifiers: modifiers + [.protocol], inherits: ["AnyObject"])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            "\(transitionHandler(inProtocol: true)) { get set }".endingWithNewline()
            startFunc
        }.endingWithNewline(2)
        TypeDecl(name: typeName, modifiers: modifiers + [.final, .class], inherits: [interfaceTypeName])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            String.dependencies.commented().endingWithNewline()
            dependencyProperties.endingWithNewline(2)
            String.properties.commented().endingWithNewline()
            argsProperties.endingWithNewline(2)
            Mark.initialization.endingWithNewline(2)
            ClosureDecl(name: "init", args: dependencies + args, modifiers: modifiers)
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                ForEach(dependencies + args, separator: .newline) { arg in
                    "self.\(arg.name) = \(arg.argName ?? arg.name)"
                }
            }.endingWithNewline(2)
            Mark(name: interfaceTypeName).endingWithNewline(2)
            startFunc
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                "let \(startAssembly.isModule ? "module" : "viewController") = \(moduleName.startsLowercased())Assembly.assemble"
                Brackets(parenthesis: .round) {
                    ForEach(args, separator: .commaSpace) { dep in
                        "\(dep.name): \(dep.name)"
                    }
                    ", output: self"
                }.endingWithNewline()
                if startAssembly.isModule {
                    "self.\(moduleName.startsLowercased())Input = module.moduleInput".endingWithNewline()
                }
                "transitionHandler?.present(\(startAssembly.isModule ? "module.viewController" : "viewController"), animated: true)" // TODO: transition type
            }
        }
        if let output = startAssembly.output {
            Mark(name: output.decl.name).startingWithNewline(2).endingWithNewline(2)
            output.extension(type: typeName)
        }
    }

    private func transitionHandler(inProtocol: Bool = false) -> VarDecl {
        VarDecl(name: "transitionHandler", type: "UIViewController?", modifiers: inProtocol ? [.var] : [.weak, .var])
    }

    private var moduleInput: VarDecl? {
        VarDecl(name: "\(moduleName.startsLowercased())Input", type: "\(moduleName)Input?", modifiers: [.weak, .var])
    }

    @TextDocumentBuilder
    private var startFunc: some TextDocument {
        ClosureDecl(name: "start", modifiers: [.func])
    }

    @TextDocumentBuilder
    private var dependencyProperties: some TextDocument {
        Joined(separator: String.newline, elements: [transitionHandler(), moduleInput] + dependencies.map {
            VarDecl(name: $0.name, type: $0.type, modifiers: [.private, .let])
        })
    }

    @TextDocumentBuilder
    private var argsProperties: some TextDocument {
        Joined(separator: String.newline, elements: args.map {
            VarDecl(name: $0.name, type: $0.type, modifiers: [.private, .let])
        })
    }
}


public struct CoordinatorAssemblyTemplate: TextDocument {
    public let moduleName: String
    public let dependencies: [ClosureDecl.Arg]
    public let args: [ClosureDecl.Arg]
    public let modifiers: [Keyword]

    public init(moduleName: String, dependencies: [ClosureDecl.Arg] = [], args: [ClosureDecl.Arg] = [], modifiers: [Keyword] = []) {
        self.moduleName = moduleName
        self.dependencies = dependencies
        self.args = args
        self.modifiers = modifiers
    }

    public var interfaceTypeName: String {
        "I" + typeName
    }

    public var typeName: String {
        "\(moduleName)CoordinatorAssembly"
    }

    @Environment(\.indentation) private var indentation

    public var textBody: some TextDocument {
        TypeDecl(name: interfaceTypeName, modifiers: modifiers + [.protocol])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            assembleFunc
        }.endingWithNewline(2)
        TypeDecl(name: typeName, modifiers: modifiers + [.final, .class], inherits: [interfaceTypeName])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            String.dependencies.commented().endingWithNewline()
            dependencyProperties.endingWithNewline(2)
            Mark.initialization.endingWithNewline(2)
            ClosureDecl(name: "init", args: dependencies, modifiers: modifiers)
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                ForEach(dependencies, separator: .newline) { arg in
                    "self.\(arg.name) = \(arg.argName ?? arg.name)"
                }
            }.endingWithNewline(2)
            Mark(name: interfaceTypeName).endingWithNewline(2)
            assembleFunc
            Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
                "let coordinator = \(moduleName)Coordinator"
                Brackets(parenthesis: .round) {
                    ForEach(dependencies + args, separator: ", ") {
                        "\($0.name): \($0.name)"
                    }
                }.endingWithNewline()
                "coordinator.transitionHandler = transitionHandler".endingWithNewline()
                "return coordinator"
            }
        }
    }

    @TextDocumentBuilder
    private var assembleFunc: some TextDocument {
        ClosureDecl(name: "assemble", args: assemblyArgs, result: "I" + moduleName + "Coordinator", modifiers: modifiers + [.func])
    }

    private var assemblyArgs: [ClosureDecl.Arg] {
        return args + [ClosureDecl.Arg(name: "transitionHandler", type: "UIViewController")]
    }

    @TextDocumentBuilder
    private var dependencyProperties: some TextDocument {
        if dependencies.isEmpty {
            VarDecl(name: "someDep", type: "Lazy<ISomeDep>", modifiers: [.private]).commented()
        } else {
            ForEach(dependencies, separator: .newline) { dep in
                VarDecl(name: dep.name, type: dep.type, modifiers: [.private, .let])
            }
        }
    }
}


public struct ScreenModule {
    public let name: String
    public let hasInput: Bool
    public let output: ProtocolDecl?
    public let args: [ClosureDecl.Arg]
    public let dependencies: [ClosureDecl.Arg]

    public init(name: String, hasInput: Bool = false, output: ProtocolDecl? = nil, args: [ClosureDecl.Arg] = [], dependencies: [ClosureDecl.Arg] = []) {
        self.name = name
        self.hasInput = hasInput
        self.output = output
        self.args = args
        self.dependencies = dependencies
    }

    public var assemblyDependency: ClosureDecl.Arg {
        ClosureDecl.Arg(name: "\(name.startsLowercased())Assembly", type: assembly().interfaceTypeName)
    }

    public func assembly(accessLevel: Keyword? = nil) -> AssemblyTemplate {
        AssemblyTemplate(moduleName: name,
                         hasInput: hasInput,
                         outputTypeName: output?.decl.name,
                         dependencies: dependencies,
                         args: args,
                         modifiers: accessLevel.map({ [$0] }) ?? [])
    }

    public func presenter(accessLevel: Keyword? = nil, funcs: [ClosureDecl] = []) -> PresenterTemplate {
        PresenterTemplate(moduleName: name,
                          hasInput: hasInput,
                          output: output,
                          dependencies: dependencies,
                          args: args,
                          funcs: funcs,
                          modifiers: accessLevel.map({ [$0] }) ?? [])
    }

    public func view(accessLevel: Keyword? = nil, dependencies: [ClosureDecl.Arg] = [], funcs: [ClosureDecl] = []) -> ViewTemplate {
        ViewTemplate(moduleName: name,
                     dependencies: dependencies,
                     funcs: funcs,
                     modifiers: accessLevel.map({ [$0] }) ?? [])
    }

    public func coordinator(accessLevel: Keyword? = nil, dependencies: [ClosureDecl.Arg] = []) -> CoordinatorTemplate {
        CoordinatorTemplate(
            moduleName: name,
            startAssembly: CoordinatorTemplate.StartAssembly(isModule: hasInput, output: output),
            dependencies: dependencies + [assemblyDependency],
            args: args,
            modifiers: accessLevel.map({ [$0] }) ?? []
        )
    }

    public func coordinatorAssembly(accessLevel: Keyword? = nil, dependencies: [ClosureDecl.Arg] = []) -> CoordinatorAssemblyTemplate {
        CoordinatorAssemblyTemplate(
            moduleName: name,
            dependencies: dependencies + [assemblyDependency],
            args: args,
            modifiers: accessLevel.map({ [$0] }) ?? []
        )
    }
}
