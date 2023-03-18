//
//  File.swift
//  
//
//  Created by Denis Koryttsev on 11.03.23.
//

import CoreUI
import DocumentUI

extension TextDocument {
    var asAny: AnyTextDocument { AnyTextDocument(self) }
}

private enum IndentationKey: EnvironmentKey {
    static let defaultValue: Int = 4
}

extension EnvironmentValues {
    public var indentation: Int {
        get { self[IndentationKey.self] }
        set { self[IndentationKey.self] = newValue }
    }
}

public protocol ImplementationResolver {
    func resolve(for variable: VarDecl, stored: Bool, mutable: Bool) -> AnyTextDocument
    func resolve(for function: Function) -> AnyTextDocument
}
extension ImplementationResolver {
    func resolve(for variable: VarDecl, stored: Bool, mutable: Bool) -> AnyTextDocument { AnyTextDocument(NullDocument()) }
    func resolve(for function: Function) -> AnyTextDocument { AnyTextDocument(NullDocument()) }

    func resolve(for variable: ProtocolDecl.Var) -> AnyTextDocument {
        resolve(for: variable.decl, stored: false, mutable: variable.mutable)
    }
}
struct DefaultImplementationResolver: ImplementationResolver {
    @Environment(\.indentation) private var indentation

    func resolve(for variable: VarDecl, stored: Bool, mutable: Bool) -> AnyTextDocument {
        guard !stored else {
            return variable.type.map { type in
                Group {
                    " = "
                    type
                    Parenthesis.round
                }
            }.asAny
        }
        return Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            if mutable {
                Group {
                    "get { fatalError(\"unimplemented\") }"
                    "set {}".startingWithNewline()
                }
            }
        }.asAny
    }
    func resolve(for function: Function) -> AnyTextDocument {
        guard function.decl.result != nil else { return NullDocument().asAny }
        return AnyTextDocument("fatalError(\"unimplemented\")")
    }
}

private enum ImplementationResolverKey: EnvironmentKey {
    static let defaultValue: ImplementationResolver = DefaultImplementationResolver()
}

extension EnvironmentValues {
    public var implementationResolver: ImplementationResolver {
        get { self[ImplementationResolverKey.self] }
        set { self[ImplementationResolverKey.self] = newValue }
    }
}
