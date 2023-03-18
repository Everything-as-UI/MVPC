//
//  SwiftLang.swift
//
//
//  Created by Denis Koryttsev on 4.02.23.
//

import CoreUI
import DocumentUI

public enum Keyword: String { // TODO: separate to different enums
    case `class`, `enum`, `func`, `protocol`, `struct`, `typealias`, `extension`
    case `fileprivate`, `internal`, `private`, `public`, `open`
    case `let`, `var`
    case `lazy`, `static`, `weak`, `unowned`
    case `async`, `await`, `throws`, `rethrows`
    case `final`
    case propertyWrapper, main
}
extension Keyword: TextDocument {
    public var textBody: some TextDocument { rawValue }
}

public struct Comment {
    public enum CommentType {
        case singleLine(documented: Bool)
        case block
    }

    let type: CommentType
}
extension Comment: TextDocumentModifier {
    public func modify(content: inout String) {
        switch type {
        case .block:
            content = "/*" + content + "*/"
        case .singleLine(let documented):
            let prefix = documented ? "/// " : "// "
            content = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                .map { prefix + $0 }
                .joined(separator: "\n")
        }
    }
}
extension TextDocument {
    public func commented(_ type: Comment.CommentType = .singleLine(documented: false)) -> _ModifiedDocument<Self, Comment> {
        _ModifiedDocument(self, modifier: Comment(type: type))
    }
}

public struct BoundModifier: TextDocumentModifier {
    let open: String
    let close: String

    public func modify(content: inout String) {
        content = open + content + close
    }
}

extension TextDocument {
    public func bouned(open: String, close: String) -> _ModifiedDocument<Self, BoundModifier> {
        modifier(BoundModifier(open: open, close: close))
    }
    public func parenthical(_ parenthesis: Parenthesis) -> _ModifiedDocument<Self, BoundModifier> {
        modifier(BoundModifier(open: parenthesis.open, close: parenthesis.close))
    }
}

public struct Parenthesis {
    public let open: String
    public let close: String

    public static let curve = Self(open: "{", close: "}")
    public static let triangular = Self(open: "<", close: ">")
    public static let round = Self(open: "(", close: ")")

    public func prefixed(_ prefix: String) -> Self {
        Self(open: prefix + open, close: close)
    }
}
extension Parenthesis: TextDocument {
    public var textBody: some TextDocument {
        open
        close
    }
}

public struct Brackets<Content: TextDocument>: TextDocument {
    public let open: String
    public let close: String
    public let indentation: Int?
    @TextDocumentBuilder public let content: () -> Content

    public init(open: String, close: String, indentation: Int? = nil, @TextDocumentBuilder content: @escaping () -> Content) {
        self.open = open
        self.close = close
        self.indentation = indentation
        self.content = content
    }

    public init(parenthesis: Parenthesis, indentation: Int? = nil, @TextDocumentBuilder content: @escaping () -> Content) {
        self.open = parenthesis.open
        self.close = parenthesis.close
        self.indentation = indentation
        self.content = content
    }

    public var textBody: some TextDocument {
        open
        if let indentation {
            content().indent(indentation).prefix("\n").suffix("\n")
        } else {
            content()
        }
        close
    }
}

public struct Mark: TextDocument {
    let name: String

    public init(name: String) {
        self.name = name
    }

    public var textBody: some TextDocument {
        "// MARK: - "
        name
    }
}

public struct Todo: TextDocument {
    public let version: String
    public let author: String?
    public let text: String

    public init(version: String, author: String?, text: String) {
        self.version = version
        self.author = author
        self.text = text
    }

    public var textBody: some TextDocument {
        "// TODO: "
        Joined(separator: ", ", elements: [version, author, text])
    }
}

public struct Generic: TextDocument {
    public let name: String
    public let constraints: [String]

    public init(name: String, constraints: [String] = []) {
        self.name = name
        self.constraints = constraints
    }

    public var textBody: some TextDocument {
        name
        ForEach(constraints, separator: " & ", content: { $0 }).prefix(": ")
    }
}

public struct VarDecl: TextDocument {
    public let name: String
    public let type: String?
    public let modifiers: [Keyword]
    public let attributes: [String]

    public init(name: String, type: String? = nil, modifiers: [Keyword] = [], attributes: [String] = []) {
        self.name = name
        self.type = type
        self.modifiers = modifiers
        self.attributes = attributes
    }

    public var textBody: some TextDocument {
        ForEach(attributes, separator: "\n", content: { "@\($0)" }).suffix("\n")
        ForEach(modifiers, separator: " ", content: { $0 }).suffix(" ")
        name
        type.prefix(": ")
    }
}
extension VarDecl {
    func withModifiers(_ modifiers: [Keyword]) -> Self {
        Self(name: name, type: type, modifiers: modifiers, attributes: attributes)
    }
}

public struct TypeDecl: TextDocument {
    public let name: String
    public let modifiers: [Keyword]
    public let inherits: [String]
    public let generics: [Generic]
    public let attributes: [String]

    public init(name: String, modifiers: [Keyword] = [], inherits: [String] = [], generics: [Generic] = [], attributes: [String] = []) {
        self.name = name
        self.modifiers = modifiers
        self.inherits = inherits
        self.generics = generics
        self.attributes = attributes
    }

    public var textBody: some TextDocument {
        ForEach(attributes, separator: "\n", content: { "@\($0)" }).suffix("\n")
        ForEach(modifiers, separator: " ", content: { $0 }).suffix(" ")
        name
        ForEach(generics, separator: ", ", content: { $0 }).parenthical(.triangular)
        ForEach(inherits, separator: ", ", content: { $0 }).prefix(": ")
    }
}

public struct ClosureDecl: TextDocument {
    public let name: String?
    public let args: [Arg]
    public let result: String?
    public let generics: [Generic]
    public let modifiers: [Keyword]
    public let traits: [Keyword]
    public let attributes: [String]

    public init(name: String? = nil, args: [Arg] = [], result: String? = nil, generics: [Generic] = [], modifiers: [Keyword] = [], traits: [Keyword] = [], attributes: [String] = []) {
        self.name = name
        self.args = args
        self.result = result
        self.generics = generics
        self.modifiers = modifiers
        self.traits = traits
        self.attributes = attributes
    }

    public var textBody: some TextDocument {
        ForEach(attributes, separator: .newline, content: { "@\($0)" }).suffix("\n")
        ForEach(modifiers, separator: .space, content: { $0 }).suffix(" ")
        name
        ForEach(generics, separator: ", ", content: { $0 })
            .parenthical(.triangular)
        Brackets(parenthesis: .round) {
            ForEach(args, separator: ", ", content: { $0 })
        }
        ForEach(traits, separator: .space, content: { $0 }).prefix(String.space)
        result.prefix(" -> ")
    }

    public struct Arg: TextDocument {
        public let name: String
        public let type: String
        public let argName: String?
        public let attributes: [String]

        public init(name: String, type: String, argName: String? = nil, attributes: [String] = []) {
            self.name = name
            self.type = type
            self.argName = argName
            self.attributes = attributes
        }

        public var textBody: some TextDocument {
            Joined(separator: " ", elements: attributes).suffix(" ")
            ForEach([name, argName], separator: " ", content: { $0 })
            type.prefix(": ")
        }
    }
}


public struct DeclWithBody<Decl, Body>: TextDocument where Decl: TextDocument, Body: TextDocument {
    public let decl: Decl
    @TextDocumentBuilder let body: () -> Body

    public init(decl: Decl, @TextDocumentBuilder body: @escaping () -> Body) {
        self.decl = decl
        self.body = body
    }

    @Environment(\.indentation) private var indentation

    public var textBody: some TextDocument {
        decl
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation, content: body)
    }
}
extension TextDocument {
    func withBody<Body: TextDocument>(@TextDocumentBuilder _ body: @escaping () -> Body) -> some TextDocument {
        DeclWithBody(decl: self, body: body)
    }
}


public struct Function: TextDocument {
    public let decl: ClosureDecl

    public init(name: String, args: [ClosureDecl.Arg] = [], result: String? = nil, generics: [Generic] = [], modifiers: [Keyword] = [], traits: [Keyword] = [], attributes: [String] = []) {
        self.decl = ClosureDecl(name: name, args: args, result: result, generics: generics, modifiers: modifiers + [.func], traits: traits, attributes: attributes)
    }

    public var textBody: some TextDocument {
        decl
    }

    @Environment(\.implementationResolver) private var implementationResolver

    @TextDocumentBuilder
    public var defaultImplementation: some TextDocument {
        DeclWithBody(decl: self) {
            implementationResolver.resolve(for: self)
        }
    }
}


public struct ProtocolDecl: TextDocument {
    public let decl: TypeDecl
    public let vars: [Var]
    public let funcs: [Function]

    public init(name: String, vars: [Var] = [], funcs: [Function] = [], modifiers: [Keyword] = [],
         inherits: [String] = [], generics: [Generic] = [], attributes: [String] = []) {
        self.decl = TypeDecl(name: name, modifiers: modifiers + [.protocol], inherits: inherits, generics: generics, attributes: attributes)
        self.vars = vars
        self.funcs = funcs
    }

    @Environment(\.indentation) private var indentation

    public var textBody: some TextDocument {
        DeclWithBody(decl: decl) {
            Joined(separator: String.newline, elements: vars)
            Joined(separator: String.newline, elements: funcs).startingWithNewline(vars.isEmpty ? 0 : 1)
        }
    }

    public struct Var: TextDocument {
        public let decl: VarDecl
        public let mutable: Bool

        public init(decl: VarDecl, mutable: Bool) {
            self.decl = decl
            self.mutable = mutable
        }

        public init(name: String, type: String, modifiers: [Keyword] = [], attributes: [String] = [], mutable: Bool = false) {
            self.decl = VarDecl(name: name, type: type, modifiers: modifiers + [.var], attributes: attributes)
            self.mutable = mutable
        }

        @Environment(\.implementationResolver) private var implementationResolver

        public var textBody: some TextDocument {
            decl
            mutable ? " { get set }" : " { get }"
        }

        @TextDocumentBuilder
        public func defaultImplementation(stored: Bool = false) -> some TextDocument {
            decl.withModifiers(mutable ? decl.modifiers : decl.modifiers.dropLast() + [.let])
            implementationResolver.resolve(for: decl, stored: stored, mutable: mutable)
        }
    }
}

extension ProtocolDecl {
    @TextDocumentBuilder
    public func `extension`(type name: String? = nil) -> some TextDocument {
        TypeDecl(name: name ?? decl.name, modifiers: [.extension], inherits: name != nil ? [decl.name] : [])
        Brackets(parenthesis: .curve.prefixed(.space), indentation: indentation) {
            defaultImplementation()
        }
    }

    @TextDocumentBuilder
    public func defaultImplementation(storedProperties: Bool = false) -> some TextDocument {
        ForEach(vars, separator: .newline) { $0.defaultImplementation(stored: storedProperties) }
        ForEach(funcs, separator: .newline) { $0.defaultImplementation }
            .startingWithNewline(vars.isEmpty ? 0 : 2)
    }
}
