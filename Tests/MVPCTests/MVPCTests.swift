import XCTest
@testable import MVPC
import SwiftLangUI

final class MVPCTests: XCTestCase {
    func testExample() throws {
        let module = ScreenModule(name: "SomeModule",
                                  hasInput: true,
                                  output: ProtocolDecl(name: "SomeModuleOutput", funcs: [Function(name: "showNextScreen")]),
                                  args: [ClosureDecl.Arg(name: "title", type: "String")],
                                  dependencies: [ClosureDecl.Arg(name: "imageResolver", type: "UIImageAsset")])
        print("\(module.assembly().environment(\.indentation, 2))", "\(module.presenter())", "\(module.view())", "\(module.coordinator())", "\(module.coordinatorAssembly())", separator: "\n\n/// -------------------------\n\n")
    }
}

// MARK: - SwiftLang

extension MVPCTests {
    func testProtocol() {
        let var1 = ProtocolDecl.Var(name: "dataSource", type: "[String]")
        let func1 = Function(name: "viewDidLoad")
        let protocolDecl = ProtocolDecl(name: "SomeModuleInput", vars: [var1], funcs: [func1])
        print("\(protocolDecl)")
    }

    func testProtocolImplementation() {
        let var1 = ProtocolDecl.Var(name: "dataSource", type: "[String]", mutable: false)
        let func1 = Function(name: "viewDidLoad", result: "Void")
        let protocolDecl = ProtocolDecl(name: "SomeModuleInput", vars: [var1], funcs: [func1])
        let defImpl = protocolDecl.defaultImplementation(storedProperties: true)
        print("\(defImpl)")
    }
}
