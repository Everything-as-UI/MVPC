//
//  File.swift
//  
//
//  Created by Denis Koryttsev on 11.03.23.
//

import DocumentUI

public extension String {
    static let space = " "
    static let newline = "\n"
    static let commaSpace = ", "

    func repeating(_ count: Int) -> Self {
        Self(repeating: self, count: count)
    }
}

public extension String {
    func startsLowercased() -> String {
        let first = String(prefix(1))
        let other = String(dropFirst())
        return first.lowercased() + other
    }
}

public extension TextDocument {
    func starting(with repeatingString: String, count: Int = 1) -> _ModifiedDocument<Self, Prefix<String>> {
        prefix(String(repeating: repeatingString, count: count))
    }
    func ending(with repeatingString: String, count: Int = 1) -> _ModifiedDocument<Self, Suffix<String>> {
        suffix(String(repeating: repeatingString, count: count))
    }

    func startingWithNewline(_ count: Int = 1) -> _ModifiedDocument<Self, Prefix<String>> {
        starting(with: .newline, count: count)
    }
    func endingWithNewline(_ count: Int = 1) -> _ModifiedDocument<Self, Suffix<String>> {
        ending(with: .newline, count: count)
    }
}
