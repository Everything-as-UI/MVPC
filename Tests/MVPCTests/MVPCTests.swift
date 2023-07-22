import XCTest
@testable import MVPC
import SwiftLangUI
import DocumentUI

final class MVPCTests: XCTestCase {
    struct DataSourceImplementationResolver: ImplementationResolver {
        let inheritedResolver: ImplementationResolver

        init(inheritedResolver: ImplementationResolver = DefaultImplementationResolver()) {
            self.inheritedResolver = inheritedResolver
        }

        func combined(with other: ImplementationResolver) -> Self {
            Self(inheritedResolver: other)
        }

        func resolve(for variable: VarDecl, inExtension: Bool, mutable: Bool, with context: ImplementationResolverContext) -> AnyTextDocument {
            guard variable.name == "dataSource" else {
                return inheritedResolver.resolve(for: variable, inExtension: inExtension, mutable: mutable, with: context)
            }

            return Group {
                variable.appendingModifiers(mutable ? [.var] : [.let])
                " = "
                "[0, 1, 2, 3, 4, 5]"
            }.erased
        }
    }

    func testScreenModule() throws {
        let name = "SomeModule"
        let module = ScreenModule(name: name,
                                  input: ProtocolDecl(name: "\(name)Input", funcs: [Function(name: "update")]),
                                  output: ProtocolDecl(name: "\(name)Output", funcs: [Function(name: "showNextScreen")]),
                                  args: [ClosureDecl.Arg(label: "title", type: "String")],
                                  dependencies: [ClosureDecl.Arg(label: "imageResolver", type: "UIImageAsset")],
                                  presenterInterface: .presenter(name: "I\(name)Presenter", vars: [
                                    ProtocolDecl.Var(name: "dataSource", type: "[Int]"),
                                    ProtocolDecl.Var(name: "title", type: "String")
                                  ]),
                                  viewInterface: .view(name: "I\(name)View", funcs: [Function(name: "reload")]))
        let coordinator = module.coordinator()
        let moduleImplResolver = module.defaultImplementationResolver()
        let coordinatorImplResolver = coordinator.defaultImplementationResolver(startModule: module)
        let moduleImpl = module
            .environment(\.indentation, 2)
            .implementationResolver(moduleImplResolver)
            .implementationResolver(DataSourceImplementationResolver())
        let coordinatorAssembly = coordinator.assembly()
            .implementationResolver(coordinatorImplResolver)
        let coordinatorWithImpl = coordinator.implementationResolver(coordinatorImplResolver)
        print("\(moduleImpl)", "\(coordinatorWithImpl)", "\(coordinatorAssembly)", separator: "\n\n/// -------------------------\n\n")
    }

    func testService() {
        let service = Service(
            typeName: "SomeModelLoadingService",
            interface: ProtocolDecl(
                name: "ISomeModelLoadingService",
                funcs: [
                    Function(
                        name: "loadModel",
                        args: [
                            ClosureDecl.Arg(label: "for", type: "String", argName: "modelID")
                        ],
                        result: "Model",
                        traits: [.async, .throws]
                    )
                ]
            ),
            dependencies: [ClosureDecl.Arg(label: "requestProcessor", type: "IRequestProcessor")],
            modifiers: []
        )

        print("\(service)")
    }

    func testRouter() {
        let router = Router(
            typeName: "SomeScreenRouter",
            interface: ProtocolDecl(
                name: "ISomeScreenRouter",
                funcs: [
                    Function(
                        name: "showSheet",
                        args: [
                            ClosureDecl.Arg(label: "for", type: "String", argName: "text")
                        ]
                    )
                ]
            ),
            dependencies: [ClosureDecl.Arg(label: "transitionHandler", type: "UIViewController")],
            modifiers: []
        )

        print("\(router)")
    }
}
