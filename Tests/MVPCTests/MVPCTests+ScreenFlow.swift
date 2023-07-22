//
//  MVPCTests+ScreenFlow.swift
//  
//
//  Created by Denis Koryttsev on 8.04.23.
//

import XCTest
@testable import MVPC
import SwiftLangUI
import DocumentUI

extension MVPCTests {
    func testScreenFlow() {
        let didTapFunc = Function(name: "didTapActionButton")
        let transitionHandlerType = "UINavigationController"
        let transitionHandlerArg = ClosureDecl.Arg(label: "transitionHandler", type: transitionHandlerType)
        let flow = [
            ScreenModule(name: "FirstScreen", args: [], presenterInterface: .presenter(name: "IFirstScreenPresenter", funcs: [didTapFunc])),
            ScreenModule(name: "SecondScreen", args: [ClosureDecl.Arg(label: "title", type: "String")], presenterInterface: .presenter(name: "ISecondScreenPresenter", funcs: [didTapFunc])),
            ScreenModule(name: "ThirdScreen", args: [ClosureDecl.Arg(label: "image", type: "UIImage")], presenterInterface: .presenter(name: "IThirdScreenPresenter", funcs: [didTapFunc]))
        ]

        let screens = flow.enumerated().map { (i, module) in
            let nextScreen = i < flow.count - 1 ? flow[i+1] : nil
            let screen = nextScreen.map {
                module.withOutput(makeOutput(for: module, with: $0))
            } ?? module
            print("\(screen.implementationResolver(ScreenImplementationResolver(module: screen, nextScreen: nextScreen)))")

            let coordinator = screen.coordinator(
                dependencies: nextScreen.map { [$0.defaultCoordinatorAssemblyDependency] } ?? [],
                transitionHandlerType: transitionHandlerType)
            let coordinatorAssembly = coordinator.assembly([transitionHandlerArg])
            let nextCoordinatorAssembly = nextScreen?.coordinator(transitionHandlerType: transitionHandlerType).assembly([transitionHandlerArg])
            let implResolver = CoordinatorImplResolver(
                startModule: screen,
                coordinator: coordinator,
                nextCoordinatorAssembly: nextCoordinatorAssembly)
            print("\(coordinatorAssembly.implementationResolver(implResolver))")
            print("\(coordinator.implementationResolver(implResolver))")
            return screen
        }

        let mainCoordinator = Coordinator(
            typeName: "MainFlowCoordinator",
            interface: .coordinator(name: "IMainFlowCoordinator", transitionHandlerType: transitionHandlerType),
            inputs: [],
            outputs: [],
            dependencies: flow.map(\.assemblyDependency),
            args: [],
            modifiers: []
        )
        print("\(mainCoordinator.implementationResolver(MainCoordinatorImplementationResolver(coordinator: mainCoordinator, startModule: screens[0])))")
        for (i, screen) in screens.enumerated() {
            if let output = screen.output, i < screens.count - 1 {
                let ext = output.extension(type: mainCoordinator.typeName, with: .context(""))
                    .implementationResolver(MainCoordinatorExtensionImplementationResolver(module: screens[i + 1]))
                print("\(ext)")
            }
        }
    }
}
extension MVPCTests {
    private func makeOutput(for screen: ScreenModule, with next: ScreenModule) -> ProtocolDecl {
        ProtocolDecl(name: screen.name + "Output",
                     funcs: [
                        Function(name: "showNextScreen", args: next.args),
                        Function(name: "show\(next.name)", args: next.args)
                     ],
                     inherits: ["AnyObject"])
    }
}

struct CoordinatorImplResolver: CoordinatorImplementationResolver {
    let startModule: ScreenModule
    let coordinator: Coordinator
    let nextCoordinatorAssembly: CoordinatorAssembly?

    func resolve(for function: Function, with context: ImplementationResolverContext) -> AnyTextDocument {
        guard let next = nextCoordinatorAssembly, function.decl.name == "showNextScreen" else {
            return inheritedResolver.resolve(for: function, with: context)
        }
        let assemblyCall = next.interface.funcs[0]
            .call(in: next.typeName.startsLowercased())
            .implementationResolver(ArgsResolver())
        return """
        guard let transitionHandler else { return }
        let coordinator = \(assemblyCall)
        coordinator.start()
        children.append(coordinator)
        """
    }

    var coordinatorStartFunc: AnyTextDocument {
        StartFuncImplementation(module: startModule, transition: .push).erased
    }
}

struct ArgsResolver: ImplementationResolver {
    func resolve(for arg: ClosureDecl.Arg, with context: ImplementationResolverContext) -> AnyTextDocument {
        arg.label.erased
    }
}

struct ScreenImplementationResolver: ScreenModuleImplementationResolver {
    let module: ScreenModule
    let nextScreen: ScreenModule?

    private var rgb: Double {
        Double((0...255).randomElement()!) / 255.0
    }

    func resolve(for function: Function, with context: ImplementationResolverContext) -> AnyTextDocument {
        switch function.decl.name {
        case "didTapActionButton":
            guard let nextScreen else { return "print(\"no next screen\")" }
            return Function(name: "showNextScreen", args: nextScreen.args).call(in: "output?").erased
        default: return inheritedResolver.resolve(for: function, with: context)
        }
    }

    func resolve(with context: ImplementationResolverContext) -> AnyTextDocument {
        switch context.identifier {
        case View.privateFunctions:
            return """
            private func setupUI() {
                view.backgroundColor = UIColor(red: \(rgb), green: \(rgb), blue: \(rgb), alpha: 1.0)
                let button = UIButton()
                button.translatesAutoresizingMaskIntoConstraints = false
                button.setTitle("\(nextScreen.map { "Show " + $0.name } ?? "Print")", for: .normal)
                button.addTarget(self, action: #selector(actionButtonTouchUpInside), for: .touchUpInside)
                view.addSubview(button)
                NSLayoutConstraint.activate([
                    button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
                ])
            }

            @objc private func actionButtonTouchUpInside() {
                presenter.didTapActionButton()
            }
            """
        case View.viewDidLoad:
            return """
            setupUI()
            """.suffix(
                inheritedResolver.resolve(with: context).startingWithNewline()
            ).erased
        default:
            return NullDocument().erased
        }
    }
}

struct MainCoordinatorImplementationResolver: CoordinatorImplementationResolver {
    let coordinator: Coordinator
    let startModule: ScreenModule

    func resolve(for protocolDecl: ProtocolDecl, inExtension: Bool, with context: ImplementationResolverContext) -> AnyTextDocument {
        Joined(separator: String.newline) {
            protocolDecl.vars[0].decl.withModifiers([.var]).suffix(" = []")
            protocolDecl.vars[1].decl.withModifiers([.weak, .var]).endingWithNewline()
            DeclWithBody(decl: protocolDecl.funcs[0]) {
                StartFuncImplementation(module: startModule, transition: .push)
            }
        }.erased
    }
}

struct MainCoordinatorExtensionImplementationResolver: ImplementationResolver {
    let module: ScreenModule
    func resolve(for function: Function, with context: ImplementationResolverContext) -> AnyTextDocument {
        switch function.decl.name {
        case "showNextScreen":
            return function.withName("show\(module.name)").call(in: nil).erased
        case "show\(module.name)":
            return Group {
                "let viewController = \(module.assembly().interface.funcs[0].call(in: module.assemblyDependency.label))".endingWithNewline()
                "transitionHandler?.pushViewController(viewController, animated: true)"
            }.erased
        default: return inheritedResolver.resolve(for: function, with: context)
        }
    }

    func resolve(for arg: ClosureDecl.Arg, with context: ImplementationResolverContext) -> AnyTextDocument {
        guard arg.label != "output" else { return "self" }
        return arg.label.erased
    }
}
