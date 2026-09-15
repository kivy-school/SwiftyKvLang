import Foundation

/// Compilation mode for property values
public enum KvCompilationMode: Sendable {
    /// Expression mode (eval) - property assignment
    case eval
    /// Statement mode (exec) - event handler
    case exec
}

/// Compiled property value with watched keys
public struct KvCompiledPropertyValue: Sendable {
    /// Original value string
    public let value: String
    
    /// Compilation mode
    public let mode: KvCompilationMode
    
    /// Watched keys (dotted paths like "self.width", "root.opacity")
    /// These are the keys that trigger re-evaluation when changed
    public let watchedKeys: [[String]]
    
    /// Whether this is a constant value (no watched keys)
    public var isConstant: Bool {
        watchedKeys.isEmpty
    }
    
    public init(value: String, mode: KvCompilationMode, watchedKeys: [[String]]) {
        self.value = value
        self.mode = mode
        self.watchedKeys = watchedKeys
    }
}

/// Property value compiler
/// Analyzes KV property values to extract watched keys for reactive bindings
/// Reference: parser.py ParserRuleProperty.precompile() lines 171-222
public struct KvCompiler {
    
    // MARK: - Regex Patterns
    
    /// String literals (single, double, triple-quoted, raw, f-strings)
    private static let stringPattern = #"""
        (?:'''(?:[^\\']|\\.)*?''')|
        (?:"""(?:[^\\"]|\\.)*?""")|
        (?:'(?:[^\\'\n]|\\.)*?')|
        (?:"(?:[^\\"\n]|\\.)*?")
        """#
    
    /// Identifiers (variable names)
    private static let keyPattern = #"[a-zA-Z_][a-zA-Z0-9_]*"#
    
    /// Dotted attribute access (e.g., self.width, root.opacity)
    private static let keyValuePattern = #"[a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*){1,}"#
    
    /// Translation function _()
    private static let translationPattern = #"_\("#
    
    /// F-string pattern (with optional whitespace due to token reconstruction)
    private static let fstringPattern = #"[fF]\s*(?:'''(?:[^\\']|\\.)*?'''|"""(?:[^\\"]|\\.)*?"""|'(?:[^\\'\n]|\\.)*?'|"(?:[^\\"\n]|\\.)*?")"#
    
    private static let stringRegex = try! NSRegularExpression(pattern: stringPattern, options: [.dotMatchesLineSeparators])
    private static let keyValueRegex = try! NSRegularExpression(pattern: keyValuePattern, options: [])
    private static let translationRegex = try! NSRegularExpression(pattern: translationPattern, options: [])
    private static let fstringRegex = try! NSRegularExpression(pattern: fstringPattern, options: [.dotMatchesLineSeparators])
    
    // MARK: - Public API
    
    /// Compile a property value and extract watched keys
    /// - Parameters:
    ///   - propertyName: Name of the property
    ///   - value: Property value expression
    /// - Returns: Compiled value with watched keys
    public static func compile(propertyName: String, value: String) -> KvCompiledPropertyValue {
        // Determine compilation mode based on property name
        // Event handlers (on_*) use exec mode, others use eval mode
        let mode: KvCompilationMode = propertyName.hasPrefix("on_") ? .exec : .eval
        
        // For exec mode, we don't need to watch any keys
        // Event handlers are called explicitly, not reactively
        // (a `name: |` block that computes a value is eval mode and still watches)
        if mode == .exec {
            return KvCompiledPropertyValue(value: value, mode: mode, watchedKeys: [])
        }
        
        // Extract watched keys for eval mode
        let watchedKeys = extractWatchedKeys(from: value)
        
        return KvCompiledPropertyValue(value: value, mode: mode, watchedKeys: watchedKeys)
    }
    
    // MARK: - Key Extraction
    
    /// Extract watched keys from a property value
    /// Finds all attribute access patterns like "self.width", "root.opacity"
    /// Reference: parser.py lines 197-222
    private static func extractWatchedKeys(from value: String) -> [[String]] {
        var keys = Set<String>()
        
        // First, remove all string literals from the value
        // We don't want to match patterns inside strings
        let withoutStrings = removeStrings(from: value)
        
        // Remove comments, line by line so a block keeps its later lines
        let withoutComments = withoutStrings
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                if let commentIndex = line.firstIndex(of: "#") { return line[..<commentIndex] }
                return line
            }
            .joined(separator: "\n")
        
        // Extract dotted attribute paths (e.g., self.width, root.opacity)
        let keyValueMatches = Self.keyValueRegex.matches(
            in: withoutComments,
            options: [],
            range: NSRange(withoutComments.startIndex..., in: withoutComments)
        )
        
        for match in keyValueMatches {
            if let range = Range(match.range, in: withoutComments) {
                let key = String(withoutComments[range])
                keys.insert(key)
            }
        }
        
        // Check for translation function _()
        // If present, add special "_" key to trigger updates on locale changes
        let hasTranslation = Self.translationRegex.firstMatch(
            in: withoutComments,
            options: [],
            range: NSRange(withoutComments.startIndex..., in: withoutComments)
        ) != nil
        
        if hasTranslation {
            keys.insert("_")
        }
        
        // TODO: Extract keys from f-strings (requires Python AST parsing)
        // For now, we'll use simple pattern matching for common cases in f-strings
        extractFStringKeys(from: value, into: &keys)
        
        // Convert dotted keys to arrays (e.g., "self.width" -> ["self", "width"])
        return keys.sorted().map { $0.split(separator: ".").map(String.init) }
    }
    
    /// Remove string literals from value
    private static func removeStrings(from value: String) -> String {
        let nsRange = NSRange(value.startIndex..., in: value)
        return Self.stringRegex.stringByReplacingMatches(
            in: value,
            options: [],
            range: nsRange,
            withTemplate: ""
        )
    }
    
    /// Extract keys from f-strings
    /// F-strings can contain expressions like f"{self.width}"
    private static func extractFStringKeys(from value: String, into keys: inout Set<String>) {
        let nsRange = NSRange(value.startIndex..., in: value)
        let matches = Self.fstringRegex.matches(in: value, options: [], range: nsRange)
        
        for match in matches {
            if let range = Range(match.range, in: value) {
                let fstring = String(value[range])
                
                // Extract expressions from f-string braces
                // Pattern: {expression}
                let bracePattern = #"\{([^}]+)\}"#
                if let braceRegex = try? NSRegularExpression(pattern: bracePattern, options: []) {
                    let fstringRange = NSRange(fstring.startIndex..., in: fstring)
                    let braceMatches = braceRegex.matches(in: fstring, options: [], range: fstringRange)
                    
                    for braceMatch in braceMatches {
                        // Extract the expression inside braces
                        if braceMatch.numberOfRanges > 1,
                           let exprRange = Range(braceMatch.range(at: 1), in: fstring) {
                            let expression = String(fstring[exprRange])
                            
                            // Find dotted attribute access in the expression
                            let exprNSRange = NSRange(expression.startIndex..., in: expression)
                            let keyMatches = Self.keyValueRegex.matches(
                                in: expression,
                                options: [],
                                range: exprNSRange
                            )
                            
                            for keyMatch in keyMatches {
                                if let keyRange = Range(keyMatch.range, in: expression) {
                                    let key = String(expression[keyRange])
                                    keys.insert(key)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Module Compilation

extension KvModule {
    /// Compile all properties in the module
    /// This traverses the AST and compiles all property values
    public func compile() -> CompiledKvModule {
        var compiledRules: [CompiledKvRule] = []
        
        for rule in rules {
            let compiledProperties = rule.properties.map { property in
                let compiled = KvCompiler.compile(propertyName: property.name, value: property.value)
                return CompiledKvProperty(
                    name: property.name,
                    value: property.value,
                    compiled: compiled,
                    line: property.line
                )
            }
            
            let compiledHandlers = rule.handlers.map { handler in
                let compiled = KvCompiler.compile(propertyName: handler.name, value: handler.value)
                return CompiledKvProperty(
                    name: handler.name,
                    value: handler.value,
                    compiled: compiled,
                    line: handler.line
                )
            }
            
            compiledRules.append(CompiledKvRule(
                selector: rule.selector,
                avoidPrevious: rule.avoidPrevious,
                properties: compiledProperties,
                handlers: compiledHandlers,
                canvas: rule.canvas,
                canvasBefore: rule.canvasBefore,
                canvasAfter: rule.canvasAfter,
                children: rule.children,
                line: rule.line
            ))
        }
        
        return CompiledKvModule(
            directives: directives,
            rules: compiledRules,
            templates: templates,
            dynamicClasses: dynamicClasses,
            rootWidget: root
        )
    }
}

/// Compiled property with watched keys
public struct CompiledKvProperty: Sendable {
    public let name: String
    public let value: String
    public let compiled: KvCompiledPropertyValue
    public let line: Int
    
    public init(name: String, value: String, compiled: KvCompiledPropertyValue, line: Int) {
        self.name = name
        self.value = value
        self.compiled = compiled
        self.line = line
    }
}

/// Compiled rule with compiled properties
public struct CompiledKvRule: Sendable {
    public let selector: KvSelector
    public let avoidPrevious: Bool
    public let properties: [CompiledKvProperty]
    public let handlers: [CompiledKvProperty]
    public let canvas: KvCanvas?
    public let canvasBefore: KvCanvas?
    public let canvasAfter: KvCanvas?
    public let children: [KvWidget]
    public let line: Int
    
    public init(
        selector: KvSelector,
        avoidPrevious: Bool,
        properties: [CompiledKvProperty],
        handlers: [CompiledKvProperty],
        canvas: KvCanvas?,
        canvasBefore: KvCanvas?,
        canvasAfter: KvCanvas?,
        children: [KvWidget],
        line: Int
    ) {
        self.selector = selector
        self.avoidPrevious = avoidPrevious
        self.properties = properties
        self.handlers = handlers
        self.canvas = canvas
        self.canvasBefore = canvasBefore
        self.canvasAfter = canvasAfter
        self.children = children
        self.line = line
    }
}

/// Compiled module with all properties compiled
public struct CompiledKvModule: Sendable {
    public let directives: [KvDirective]
    public let rules: [CompiledKvRule]
    public let templates: [KvTemplate]
    public let dynamicClasses: [String: String]
    public let rootWidget: KvWidget?
    
    public init(
        directives: [KvDirective],
        rules: [CompiledKvRule],
        templates: [KvTemplate],
        dynamicClasses: [String: String],
        rootWidget: KvWidget?
    ) {
        self.directives = directives
        self.rules = rules
        self.templates = templates
        self.dynamicClasses = dynamicClasses
        self.rootWidget = rootWidget
    }
}
