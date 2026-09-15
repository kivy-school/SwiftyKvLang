import PySwiftAST

/// Widget instance in KV language
///
/// Represents a widget instance, either as a root widget or child widget.
/// Contains properties, child widgets, canvas instructions, and event handlers.
///
/// Example from style.kv:
/// ```
/// Image:
///     id: my_image
///     source: 'image.png'
///     size: 100, 100
/// ```
///
/// Similar to YAML mappings but with widget-specific semantics
public struct KvWidget: KvNode, Sendable {
    /// Widget class name (e.g., "Button", "Label")
    public let name: String
    
    /// Optional identifier for referencing this widget
    public let id: String?
    
    /// Properties assigned to this widget
    public let properties: [KvProperty]
    
    /// Child widgets nested under this widget
    public let children: [KvWidget]
    
    /// Canvas instructions rendered before widget
    public let canvasBefore: KvCanvas?
    
    /// Main canvas instructions
    public let canvas: KvCanvas?
    
    /// Canvas instructions rendered after widget
    public let canvasAfter: KvCanvas?
    
    /// Event handlers (properties starting with on_)
    public let handlers: [KvProperty]
    
    /// Conditional blocks (if/else, try/expect)
    public let conditionals: [KvConditional]
    
    /// Indentation level in source (0 = root)
    public let level: Int
    
    // Position tracking
    public let line: Int
    public let column: Int
    public let endLine: Int?
    public let endColumn: Int?
    
    public init(
        name: String,
        id: String? = nil,
        properties: [KvProperty] = [],
        children: [KvWidget] = [],
        canvasBefore: KvCanvas? = nil,
        canvas: KvCanvas? = nil,
        canvasAfter: KvCanvas? = nil,
        handlers: [KvProperty] = [],
        conditionals: [KvConditional] = [],
        level: Int = 0,
        line: Int,
        column: Int = 0,
        endLine: Int? = nil,
        endColumn: Int? = nil
    ) {
        self.name = name
        self.id = id
        self.properties = properties
        self.children = children
        self.canvasBefore = canvasBefore
        self.canvas = canvas
        self.canvasAfter = canvasAfter
        self.handlers = handlers
        self.conditionals = conditionals
        self.level = level
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
    
    public init(name: String, id: String? = nil, body: KvBody, level: Int = 0, line: Int) {
        self.init(
            name: name,
            id: id,
            properties: body.properties,
            children: body.children,
            canvasBefore: body.canvasBefore,
            canvas: body.canvas,
            canvasAfter: body.canvasAfter,
            handlers: body.handlers,
            conditionals: body.conditionals,
            level: level,
            line: line
        )
    }
    
    /// Body contents as a single value (id excluded)
    public var body: KvBody {
        KvBody(
            properties: properties,
            handlers: handlers,
            canvasBefore: canvasBefore,
            canvas: canvas,
            canvasAfter: canvasAfter,
            children: children,
            conditionals: conditionals
        )
    }
}

extension KvWidget: TreeDisplayable {
    public func treeDescription(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var result = "\(prefix)\(name):"
        if let id = id {
            result += " (id: \(id))"
        }
        result += " [line \(line), level \(level)]\n"
        
        if !properties.isEmpty {
            for prop in properties {
                result += prop.treeDescription(indent: indent + 1)
            }
        }
        
        if !handlers.isEmpty {
            for handler in handlers {
                result += handler.treeDescription(indent: indent + 1)
            }
        }
        
        if let canvas = canvasBefore {
            result += "\(prefix)  canvas.before:\n"
            result += canvas.treeDescription(indent: indent + 2)
        }
        
        if let canvas = canvas {
            result += "\(prefix)  canvas:\n"
            result += canvas.treeDescription(indent: indent + 2)
        }
        
        if let canvas = canvasAfter {
            result += "\(prefix)  canvas.after:\n"
            result += canvas.treeDescription(indent: indent + 2)
        }
        
        if !children.isEmpty {
            for child in children {
                result += child.treeDescription(indent: indent + 1)
            }
        }
        
        for conditional in conditionals {
            result += conditional.treeDescription(indent: indent + 1)
        }
        
        return result
    }
    
    /// Detailed tree content for deep traversal
    internal func detailedContent(depth: Int, parentBranches: [Bool]) -> String {
        body.detailedContent(depth: depth, parentBranches: parentBranches)
    }
}

/// Property assignment in KV language
///
/// Represents a property-value pair, similar to YAML key-value mappings
/// but with Python expressions as values and reactive binding support.
///
/// Example: `size: self.width, self.height`
///
/// Reference: parser.py lines 136-302 (ParserRuleProperty class)
public struct KvProperty: KvNode, Sendable {
    /// Property name (e.g., "size", "color", "on_press")
    public let name: String
    
    /// Raw value string as written in source
    public let value: String
    
    /// Compiled representation of the value
    public let compiledValue: KvCompiledValue
    
    /// Watched keys for reactive binding (e.g., [["self", "width"], ["root", "x"]])
    /// Extracted from property value expressions
    public let watchedKeys: [[String]]?
    
    /// If true, clear previous rules targeting this property
    /// Used for property overrides
    public let ignorePrevious: Bool
    
    /// Written as `name: |` with an indented code block: the value is a
    /// function body (returning the value, or the handler's statements),
    /// not an expression.
    public let isBlock: Bool
    
    /// Python AST for event handlers and blocks, parsed as statement(s)
    public let pythonAST: [Statement]?
    
    // Position tracking
    public let line: Int
    public let column: Int
    public let endLine: Int?
    public let endColumn: Int?
    
    public init(
        name: String,
        value: String,
        compiledValue: KvCompiledValue = .expression(""),
        watchedKeys: [[String]]? = nil,
        ignorePrevious: Bool = false,
        isBlock: Bool = false,
        pythonAST: [Statement]? = nil,
        line: Int,
        column: Int = 0,
        endLine: Int? = nil,
        endColumn: Int? = nil
    ) {
        self.name = name
        self.value = value
        self.compiledValue = compiledValue
        self.watchedKeys = watchedKeys
        self.ignorePrevious = ignorePrevious
        self.isBlock = isBlock
        self.pythonAST = pythonAST
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
}

extension KvProperty {
    /// The value on one line: blocks are summarised by their line count
    public var displayValue: String {
        guard isBlock else { return value }
        let count = value.isEmpty ? 0 : value.split(separator: "\n", omittingEmptySubsequences: false).count
        return "| (\(count) line\(count == 1 ? "" : "s"))"
    }
}

extension KvProperty: TreeDisplayable {
    public func treeDescription(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var result = "\(prefix)\(name): \(displayValue)"
        
        if let watched = watchedKeys, !watched.isEmpty {
            let keys = watched.map { $0.joined(separator: ".") }.joined(separator: ", ")
            result += " [watches: \(keys)]"
        }
        
        result += " [line \(line)]\n"
        return result
    }
}

/// Compiled representation of a property value
///
/// Property values can be:
/// - Literal constants (pre-evaluated at parse time)
/// - Python expressions (evaluated reactively)
/// - Python code blocks (executed for event handlers)
///
/// Reference: parser.py lines 158-226 (precompile method)
public enum KvCompiledValue: Sendable {
    /// Pre-evaluated constant value
    case literal(String)
    
    /// Python expression to evaluate (eval mode)
    case expression(String)
    
    /// Python code to execute (exec mode, for on_* handlers)
    case code(String)
}
