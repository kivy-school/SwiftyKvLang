import PySwiftAST

/// Widget class rule definition
///
/// Represents a rule that applies to widget classes, defining their properties,
/// children, canvas instructions, and event handlers.
///
/// Example from style.kv:
/// ```
/// <Button>:
///     background_normal: 'atlas://...'
///     canvas:
///         Color:
///             rgba: self.color
/// ```
///
/// Reference: parser.py lines 303-362 (ParserRule class)
public struct KvRule: KvNode, Sendable {
    /// Selector determining which widgets this rule applies to
    public let selector: KvSelector
    
    /// Properties defined in this rule
    public let properties: [KvProperty]
    
    /// Child widgets to create
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
    
    /// If true, avoid applying previous rules for this selector
    /// Indicated by - prefix in selector: <-Button>
    public let avoidPrevious: Bool
    
    // Position tracking
    public let line: Int
    public let column: Int
    public let endLine: Int?
    public let endColumn: Int?
    
    public init(
        selector: KvSelector,
        properties: [KvProperty] = [],
        children: [KvWidget] = [],
        canvasBefore: KvCanvas? = nil,
        canvas: KvCanvas? = nil,
        canvasAfter: KvCanvas? = nil,
        handlers: [KvProperty] = [],
        conditionals: [KvConditional] = [],
        avoidPrevious: Bool = false,
        line: Int,
        column: Int = 0,
        endLine: Int? = nil,
        endColumn: Int? = nil
    ) {
        self.selector = selector
        self.properties = properties
        self.children = children
        self.canvasBefore = canvasBefore
        self.canvas = canvas
        self.canvasAfter = canvasAfter
        self.handlers = handlers
        self.conditionals = conditionals
        self.avoidPrevious = avoidPrevious
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
    
    public init(selector: KvSelector, body: KvBody, avoidPrevious: Bool = false, line: Int) {
        self.init(
            selector: selector,
            properties: body.properties,
            children: body.children,
            canvasBefore: body.canvasBefore,
            canvas: body.canvas,
            canvasAfter: body.canvasAfter,
            handlers: body.handlers,
            conditionals: body.conditionals,
            avoidPrevious: avoidPrevious,
            line: line
        )
    }
    
    /// Body contents as a single value
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

extension KvRule: TreeDisplayable {
    public func treeDescription(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        let avoid = avoidPrevious ? "-" : ""
        var result = "\(prefix)<\(avoid)\(selector.primaryName)> [line \(line)]:\n"
        
        if !properties.isEmpty {
            result += "\(prefix)  Properties (\(properties.count)):\n"
            for prop in properties {
                result += prop.treeDescription(indent: indent + 2)
            }
        }
        
        if !handlers.isEmpty {
            result += "\(prefix)  Handlers (\(handlers.count)):\n"
            for handler in handlers {
                result += handler.treeDescription(indent: indent + 2)
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
            result += "\(prefix)  Children (\(children.count)):\n"
            for child in children {
                result += child.treeDescription(indent: indent + 2)
            }
        }
        
        if !conditionals.isEmpty {
            result += "\(prefix)  Conditionals (\(conditionals.count)):\n"
            for conditional in conditionals {
                result += conditional.treeDescription(indent: indent + 2)
            }
        }
        
        return result
    }
    
    /// Detailed tree content for deep traversal
    internal func detailedContent(depth: Int, parentBranches: [Bool]) -> String {
        body.detailedContent(depth: depth, parentBranches: parentBranches)
    }
}

/// Template definition (deprecated but still supported)
///
/// Templates create dynamic classes that can be instantiated like regular widgets.
/// Syntax: [TemplateName@BaseClass] or [TemplateName@Base1+Base2]
///
/// Reference: parser.py lines 434-452 (_build_template method)
public struct KvTemplate: KvNode, Sendable {
    /// Name of the template
    public let name: String
    
    /// Base classes to inherit from
    public let baseClasses: [String]
    
    /// Rule defining the template's structure
    public let rule: KvRule
    
    // Position tracking
    public let line: Int
    public let column: Int
    public let endLine: Int?
    public let endColumn: Int?
    
    public init(
        name: String,
        baseClasses: [String],
        rule: KvRule,
        line: Int,
        column: Int = 0,
        endLine: Int? = nil,
        endColumn: Int? = nil
    ) {
        self.name = name
        self.baseClasses = baseClasses
        self.rule = rule
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
}

extension KvTemplate: TreeDisplayable {
    public func treeDescription(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        let bases = baseClasses.joined(separator: "+")
        var result = "\(prefix)[\(name)@\(bases)] [line \(line)]:\n"
        result += rule.treeDescription(indent: indent + 1)
        return result
    }
}
