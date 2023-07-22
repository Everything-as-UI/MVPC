//
//  MVPC.swift
//
//
//  Created by Denis Koryttsev on 5.02.23.
//

import CoreUI
import DocumentUI
import SwiftLangUI

public struct ScreenModule {
    public let name: String
    public let input: ProtocolDecl?
    public let output: ProtocolDecl?
    public let args: [ClosureDecl.Arg]
    public let dependencies: [ClosureDecl.Arg]
    public let presenterInterface: ProtocolDecl
    public let viewInterface: ProtocolDecl
    public let viewDependencies: [ClosureDecl.Arg]

    public init(name: String,
                input: ProtocolDecl? = nil,
                output: ProtocolDecl? = nil,
                args: [ClosureDecl.Arg] = [],
                dependencies: [ClosureDecl.Arg] = [],
                presenterInterface: ProtocolDecl? = nil,
                viewInterface: ProtocolDecl? = nil,
                viewDependencies: [ClosureDecl.Arg] = []) {
        self.name = name
        self.input = input
        self.output = output
        self.args = args
        self.dependencies = dependencies
        self.presenterInterface = presenterInterface ?? .presenter(name: "I\(name)Presenter")
        self.viewInterface = viewInterface ?? .view(name: "I\(name)View")
        self.viewDependencies = viewDependencies
    }

    public var assemblyTypeName: String {
        "\(name)Assembly"
    }
    public var assemblyInterfaceName: String {
        "I\(name)Assembly"
    }
    public var assemblyDependency: ClosureDecl.Arg {
        ClosureDecl.Arg(label: assemblyTypeName.startsLowercased(), type: assemblyInterfaceName)
    }
    public func assembly(accessLevel: Keyword? = nil) -> Assembly {
        Assembly(typeName: assemblyTypeName,
                         interface: .assembly(name: assemblyInterfaceName,
                                              args: args + (output.map { [ClosureDecl.Arg(label: "output", type: $0.decl.name)] } ?? []),
                                              result: input.map { "Module<\($0.decl.name)>" } ?? "UIViewController",
                                              modifiers: accessLevel.map({ [$0] }) ?? []),
                         dependencies: dependencies, // TODO: assembly can itself dependencies
                         args: args,
                         modifiers: accessLevel.map({ [$0] }) ?? [])
    }

    public var presenterTypeName: String {
        "\(name)Presenter"
    }
    public var presenterDependency: ClosureDecl.Arg {
        ClosureDecl.Arg(label: "presenter", type: presenterInterface.decl.name)
    }
    public func presenter(accessLevel: Keyword? = nil) -> Presenter {
        Presenter(typeName: presenterTypeName,
                          interface: presenterInterface,
                          viewInterfaceName: viewInterface.decl.name,
                          input: input,
                          output: output,
                          dependencies: dependencies,
                          args: args,
                          modifiers: accessLevel.map({ [$0] }) ?? [])
    }

    public var viewTypeName: String {
        "\(name)ViewController"
    }
    public var viewDependency: ClosureDecl.Arg {
        ClosureDecl.Arg(label: "view", type: viewInterface.decl.name)
    }
    public var allViewDependencies: [ClosureDecl.Arg] {
        [presenterDependency] + viewDependencies
    }
    public func view(accessLevel: Keyword? = nil) -> View {
        View(typeName: viewTypeName,
                     interface: viewInterface,
                     dependencies: allViewDependencies,
                     modifiers: accessLevel.map({ [$0] }) ?? [])
    }
}

extension ScreenModule: TextDocument {
    public var textBody: some TextDocument {
        Joined(separator: "\n\n/// -------------------------\n\n") {
            assembly()
            presenter()
            view()
        }
    }
}

public extension ScreenModule {
    func withOutput(_ output: ProtocolDecl) -> Self {
        Self(name: name, input: input, output: output, args: args, dependencies: dependencies, presenterInterface: presenterInterface, viewInterface: viewInterface, viewDependencies: viewDependencies)
    }
}
public extension ScreenModule {
    var defaultCoordinatorTypeName: String { "\(name)Coordinator" }
    var defaultCoordinatorInterfaceName: String { "I\(name)Coordinator" }
    var defaultCoordinatorAssemblyTypeName: String { "\(name)CoordinatorAssembly" }
    var defaultCoordinatorAssemblyInterfaceName: String { "I\(name)CoordinatorAssembly" }
    var defaultCoordinatorAssemblyDependency: ClosureDecl.Arg {
        ClosureDecl.Arg(label: defaultCoordinatorAssemblyTypeName.startsLowercased(),
                        type: defaultCoordinatorAssemblyInterfaceName)
    }
    func coordinator(dependencies: [ClosureDecl.Arg] = [],
                     transitionHandlerType: String = "UIViewController",
                     modifiers: [Keyword] = []) -> Coordinator {
        Coordinator(startsWith: self, dependencies: dependencies, transitionHandlerType: transitionHandlerType, modifiers: modifiers)
    }
}

public extension Coordinator {
    init(startsWith module: ScreenModule,
         dependencies: [ClosureDecl.Arg] = [],
         transitionHandlerType: String = "UIViewController",
         modifiers: [Keyword] = []) {
        self.init(typeName: module.defaultCoordinatorTypeName,
                  interface: .coordinator(name: module.defaultCoordinatorInterfaceName,
                                          transitionHandlerType: transitionHandlerType,
                                          modifiers: modifiers),
                  inputs: module.input.map({ [ClosureDecl.Arg(label: $0.decl.name.startsLowercased(), type: $0.decl.name)] }) ?? [],
                  outputs: module.output.map({ [$0] }) ?? [],
                  dependencies: [module.assemblyDependency] + dependencies,
                  args: module.args,
                  modifiers: modifiers)
    }

    func assembly(_ additionalArgs: [ClosureDecl.Arg] = [], modifiers: [Keyword] = []) -> CoordinatorAssembly {
        CoordinatorAssembly(coordinator: self, additionalArgs: additionalArgs, modifiers: modifiers)
    }
}
extension CoordinatorAssembly {
    init(coordinator: Coordinator, additionalArgs: [ClosureDecl.Arg] = [], modifiers: [Keyword] = []) {
        self.init(
            typeName: coordinator.typeName + "Assembly",
            interface: .assembly(name: coordinator.interface.decl.name + "Assembly",
                                 args: coordinator.args + additionalArgs,
                                 result: coordinator.interface.decl.name,
                                 modifiers: modifiers),
            dependencies: coordinator.dependencies,
            modifiers: modifiers
        )
    }
}

public protocol ScreenModuleImplementationResolver: ImplementationResolver {
    var module: ScreenModule { get }

    var assembleFunc: AnyTextDocument { get }
}
public extension ScreenModuleImplementationResolver {
    var `super`: any ImplementationResolver { ScreenModule.DefaultImplementationResolver(module: module) }
    var inheritedResolver: ImplementationResolver { `super` }

    func resolve(for protocolDecl: ProtocolDecl, inExtension: Bool, with context: ImplementationResolverContext) -> AnyTextDocument {
        switch context.identifier {
        case Assembly.interfaceImplementation:
            return DeclWithBody(decl: protocolDecl.funcs[0]) {
                assembleFunc
            }.erased
        default:
            return inheritedResolver.resolve(for: protocolDecl, inExtension: inExtension, with: context)
        }
    }

    func resolve(with context: ImplementationResolverContext) -> AnyTextDocument {
        guard context.identifier == View.viewDidLoad else {
            return inheritedResolver.resolve(with: context)
        }
        return "presenter.viewDidLoad()"
    }

    var assembleFunc: AnyTextDocument {
        Group {
            """
            let presenter = \(presenterInit)
            let view = \(module.viewTypeName)
            """
            Brackets(parenthesis: .round) {
                ForEach(module.allViewDependencies, separator: ", ") {
                    "\($0.label): \($0.label)"
                }
            }.endingWithNewline()
            """
            presenter.view = view
            """.endingWithNewline()
            if module.output != nil {
                "presenter.output = output".endingWithNewline()
            }
            """
            return \(module.input != nil ? "Module(viewController: view, moduleInput: presenter)" : "view")
            """
        }.erased
    }

    @TextDocumentBuilder
    private var presenterInit: some TextDocument {
        module.presenterTypeName
        Brackets(parenthesis: .round) {
            ForEach(module.dependencies + module.args, separator: .commaSpace) { dep in
                "\(dep.label): \(dep.label)"
            }
        }
    }
}

public protocol CoordinatorImplementationResolver: ImplementationResolver {
    var coordinator: Coordinator { get }
    var startModule: ScreenModule { get }

    var coordinatorStartFunc: AnyTextDocument { get }
    var coordinatorAssembleFunc: AnyTextDocument { get }
}

public extension CoordinatorImplementationResolver {
    var `super`: any ImplementationResolver {
        Coordinator.DefaultImplementationResolver(coordinator: coordinator, startModule: startModule)
    }
    var inheritedResolver: ImplementationResolver { `super` }

    func resolve(for protocolDecl: ProtocolDecl, inExtension: Bool, with context: ImplementationResolverContext) -> AnyTextDocument {
        switch context.identifier {
        case CoordinatorAssembly.interfaceImplementation:
            return DeclWithBody(decl: protocolDecl.funcs[0]) {
                coordinatorAssembleFunc
            }.erased
        case Coordinator.interfaceImplementation:
            return Joined(separator: String.newline) {
                protocolDecl.vars[0].decl.withModifiers([.var]).suffix(" = []") // TODO: unsafe access to vars, move variable resolver
                protocolDecl.vars[1].decl.withModifiers([.weak, .var]).endingWithNewline()
                DeclWithBody(decl: protocolDecl.funcs[0]) {
                    coordinatorStartFunc
                }
            }.erased
        default:
            return inheritedResolver.resolve(for: protocolDecl, inExtension: inExtension, with: context)
        }
    }

    var coordinatorStartFunc: AnyTextDocument {
        StartFuncImplementation(module: startModule, transition: .present).erased
    }

    var coordinatorAssembleFunc: AnyTextDocument {
        Group {
            "let coordinator = \(coordinator.typeName)"
            Brackets(parenthesis: .round) {
                ForEach(coordinator.dependencies + startModule.args, separator: .commaSpace) {
                    "\($0.label): \($0.label)"
                }
            }.endingWithNewline()
            """
            coordinator.transitionHandler = transitionHandler
            return coordinator
            """
        }.erased
    }
}

public struct StartFuncImplementation: TextDocument {
    let module: ScreenModule
    let transition: Transition

    public enum Transition {
        case push, present
    }

    public init(module: ScreenModule, transition: Transition) {
        self.module = module
        self.transition = transition
    }

    public var textBody: some TextDocument {
        "let \(module.input != nil ? "module" : "viewController") = \(module.assemblyDependency.label).assemble"
        Brackets(parenthesis: .round) {
            ForEach(module.args, separator: .commaSpace) { dep in
                "\(dep.label): \(dep.label)"
            }.suffix(module.output != nil ? ", " : "")
            if module.output != nil {
                "output: self"
            }
        }.endingWithNewline()
        if let input = module.input {
            "self.\(input.decl.name.startsLowercased()) = module.moduleInput".endingWithNewline()
        }
        "transitionHandler?.\(transitionFunc)(\(module.input != nil ? "module.viewController" : "viewController"), animated: true)"
    }

    private var transitionFunc: String {
        switch transition {
        case .push: return "pushViewController"
        case .present: return "present"
        }
    }
}

extension ScreenModule {
    public struct DefaultImplementationResolver: ScreenModuleImplementationResolver {
        public let module: ScreenModule
        public let inheritedResolver: ImplementationResolver

        public init(module: ScreenModule) {
            self.module = module
            self.inheritedResolver = SwiftLangUI.DefaultImplementationResolver()
        }

        init(module: ScreenModule, inheritedResolver: ImplementationResolver) {
            self.module = module
            self.inheritedResolver = inheritedResolver
        }

        public func combined(with other: ImplementationResolver) -> Self {
            Self(module: module, inheritedResolver: other)
        }
    }

    func defaultImplementationResolver() -> DefaultImplementationResolver {
        DefaultImplementationResolver(module: self)
    }
}

extension Coordinator {
    public struct DefaultImplementationResolver: CoordinatorImplementationResolver {
        public let coordinator: Coordinator
        public let startModule: ScreenModule
        public var inheritedResolver: ImplementationResolver

        public init(coordinator: Coordinator, startModule: ScreenModule) {
            self.coordinator = coordinator
            self.startModule = startModule
            self.inheritedResolver = SwiftLangUI.DefaultImplementationResolver()
        }
        init(coordinator: Coordinator, startModule: ScreenModule, inherits resolver: ImplementationResolver) {
            self.coordinator = coordinator
            self.startModule = startModule
            self.inheritedResolver = resolver
        }

        public func combined(with other: ImplementationResolver) -> Self {
            Self(coordinator: coordinator, startModule: startModule, inherits: other)
        }
    }

    func defaultImplementationResolver(startModule: ScreenModule) -> DefaultImplementationResolver {
        DefaultImplementationResolver(coordinator: self, startModule: startModule)
    }
}
