/// Preprocessor directive in KV language
///
/// KV directives start with #: and control parsing behavior:
/// - kivy: Version requirement (e.g., #:kivy 1.0)
/// - import: Import Python modules (e.g., #:import math math)
/// - from: From-import with optional alias (e.g., #:from x.y import abc as cba)
/// - set: Define global constants (e.g., #:set MY_COLOR (1, 0, 0, 1))
/// - include: Include other .kv files (e.g., #:include other.kv)
/// - mode: Target dialect for the generator (e.g., #:mode carbonkivy)
///
/// Reference: parser.py lines 490-570 (execute_directives method)
public enum KvDirective: Sendable {
    /// Version requirement: #:kivy 1.0
    case kivy(version: String, line: Int)
    
    /// Import Python module: #:import alias module.path
    case `import`(alias: String, package: String, line: Int)
    
    /// From-import: #:from module.path import name [as alias]
    case from(module: String, name: String, alias: String?, line: Int)
    
    /// Set global constant: #:set name value
    case set(name: String, value: String, line: Int)
    
    /// Include another KV file: #:include [force] path
    case include(path: String, force: Bool, line: Int)
    
    /// Generator mode: #:mode default|carbonkivy|nucleant|swiftui
    case mode(name: String, line: Int)
    
    public var line: Int {
        switch self {
        case .kivy(_, let line),
             .import(_, _, let line),
             .from(_, _, _, let line),
             .set(_, _, let line),
             .include(_, _, let line),
             .mode(_, let line):
            return line
        }
    }
    
    /// Directive as it appears in source (without line info)
    public var sourceText: String {
        switch self {
        case .kivy(let version, _):
            return "#:kivy \(version)"
        case .import(let alias, let package, _):
            return "#:import \(alias) \(package)"
        case .from(let module, let name, let alias, _):
            let aliasStr = alias.map { " as \($0)" } ?? ""
            return "#:from \(module) import \(name)\(aliasStr)"
        case .set(let name, let value, _):
            return "#:set \(name) \(value)"
        case .include(let path, let force, _):
            return force ? "#:include force \(path)" : "#:include \(path)"
        case .mode(let name, _):
            return "#:mode \(name)"
        }
    }
}

/// Known generator modes selectable with #:mode
public enum KvMode: String, Sendable, CaseIterable {
    case `default`
    case carbonkivy
    case nucleant
    case swiftui
}

extension KvDirective: KvNode {
    public var column: Int { 0 }  // Directives always start at column 0
    public var endLine: Int? { line }
    public var endColumn: Int? { nil }
}

extension KvDirective: TreeDisplayable {
    public func treeDescription(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        switch self {
        case .set(let name, let value, let line):
            return "\(prefix)#:set \(name) = \(value) [line \(line)]\n"
        default:
            return "\(prefix)\(sourceText) [line \(line)]\n"
        }
    }
}
