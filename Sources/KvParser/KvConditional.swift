/// Contents of an indented block: rule body, widget body, or conditional branch
///
/// Sibling kinds are stored in separate arrays; use each node's `line` to
/// recover source order when it matters (e.g. where an `if` block sits
/// between child widgets).
public struct KvBody: Sendable {
    public var properties: [KvProperty]
    public var handlers: [KvProperty]
    public var canvasBefore: KvCanvas?
    public var canvas: KvCanvas?
    public var canvasAfter: KvCanvas?
    public var children: [KvWidget]
    public var conditionals: [KvConditional]
    
    public init(
        properties: [KvProperty] = [],
        handlers: [KvProperty] = [],
        canvasBefore: KvCanvas? = nil,
        canvas: KvCanvas? = nil,
        canvasAfter: KvCanvas? = nil,
        children: [KvWidget] = [],
        conditionals: [KvConditional] = []
    ) {
        self.properties = properties
        self.handlers = handlers
        self.canvasBefore = canvasBefore
        self.canvas = canvas
        self.canvasAfter = canvasAfter
        self.children = children
        self.conditionals = conditionals
    }
    
    public var isEmpty: Bool {
        properties.isEmpty && handlers.isEmpty && canvasBefore == nil && canvas == nil
            && canvasAfter == nil && children.isEmpty && conditionals.isEmpty
    }
}

/// Conditional block inside a rule or widget body
///
/// Two forms, each with an optional alternate branch:
/// ```
/// if self.disabled_state:      try:
///     Label:                       Button:
///         text: "no press"             text: "success"
/// else:                        expect:
///     Button:                      Label:
///         text: "press me"             text: "failed"
/// ```
/// `if` bodies are applied while the condition holds (reactively, via `watchedKeys`);
/// `try` bodies are applied unless building them fails, in which case the
/// `expect` branch (also spelled `except`) is applied instead.
public struct KvConditional: KvNode, Sendable {
    public enum Kind: Sendable, Equatable {
        /// if <condition>: ... else: ...
        case `if`(condition: String, watchedKeys: [[String]])
        /// try: ... expect: ...
        case `try`
    }
    
    public let kind: Kind
    
    /// Body applied when the condition holds / the try succeeds
    public let body: KvBody
    
    /// Body of the `else` / `expect` branch, if present
    public let elseBody: KvBody?
    
    // Position tracking
    public let line: Int
    public let column: Int
    public let endLine: Int?
    public let endColumn: Int?
    
    public init(
        kind: Kind,
        body: KvBody,
        elseBody: KvBody? = nil,
        line: Int,
        column: Int = 0,
        endLine: Int? = nil,
        endColumn: Int? = nil
    ) {
        self.kind = kind
        self.body = body
        self.elseBody = elseBody
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
    
    /// Condition expression for `if` blocks, nil for `try`
    public var condition: String? {
        if case .if(let condition, _) = kind { return condition }
        return nil
    }
    
    /// Source keyword opening the main branch: "if <cond>" or "try"
    public var headerText: String {
        switch kind {
        case .if(let condition, _): return "if \(condition)"
        case .try: return "try"
        }
    }
    
    /// Source keyword opening the alternate branch: "else" or "expect"
    public var elseKeyword: String {
        switch kind {
        case .if: return "else"
        case .try: return "expect"
        }
    }
}

extension KvConditional: TreeDisplayable {
    public func treeDescription(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var result = "\(prefix)\(headerText): [line \(line)]\n"
        result += body.treeDescription(indent: indent + 1)
        if let elseBody = elseBody {
            result += "\(prefix)\(elseKeyword):\n"
            result += elseBody.treeDescription(indent: indent + 1)
        }
        return result
    }
    
    /// Detailed tree content for deep traversal
    internal func detailedContent(depth: Int, parentBranches: [Bool]) -> String {
        guard let elseBody = elseBody else {
            return body.detailedContent(depth: depth, parentBranches: parentBranches)
        }
        var result = ""
        let thenPrefix = TreeFormatter.prefix(depth: depth, isLast: false, parentBranches: parentBranches)
        result += "\(thenPrefix)then\n"
        result += body.detailedContent(depth: depth + 1, parentBranches: parentBranches + [true])
        let elsePrefix = TreeFormatter.prefix(depth: depth, isLast: true, parentBranches: parentBranches)
        result += "\(elsePrefix)\(elseKeyword)\n"
        result += elseBody.detailedContent(depth: depth + 1, parentBranches: parentBranches + [false])
        return result
    }
}

extension KvBody: TreeDisplayable {
    public func treeDescription(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var result = ""
        
        for prop in properties {
            result += prop.treeDescription(indent: indent)
        }
        for handler in handlers {
            result += handler.treeDescription(indent: indent)
        }
        if let canvas = canvasBefore {
            result += "\(prefix)canvas.before:\n"
            result += canvas.treeDescription(indent: indent + 1)
        }
        if let canvas = canvas {
            result += "\(prefix)canvas:\n"
            result += canvas.treeDescription(indent: indent + 1)
        }
        if let canvas = canvasAfter {
            result += "\(prefix)canvas.after:\n"
            result += canvas.treeDescription(indent: indent + 1)
        }
        for child in children {
            result += child.treeDescription(indent: indent)
        }
        for conditional in conditionals {
            result += conditional.treeDescription(indent: indent)
        }
        
        return result
    }
    
    /// Detailed tree content for deep traversal
    /// Shared by KvRule and KvWidget, whose bodies have the same shape.
    internal func detailedContent(depth: Int, parentBranches: [Bool]) -> String {
        var result = ""
        var childIndex = 0
        
        let totalItems = properties.count + handlers.count +
                        (canvasBefore != nil ? 1 : 0) +
                        (canvas != nil ? 1 : 0) +
                        (canvasAfter != nil ? 1 : 0) +
                        children.count + conditionals.count
        
        func next() -> (isLast: Bool, prefix: String) {
            let isLast = childIndex == totalItems - 1
            childIndex += 1
            return (isLast, TreeFormatter.prefix(depth: depth, isLast: isLast, parentBranches: parentBranches))
        }
        
        for prop in properties {
            let (_, prefix) = next()
            result += "\(prefix)\(prop.name): \(prop.displayValue) [property, line \(prop.line)]\n"
        }
        
        for handler in handlers {
            let (isLast, prefix) = next()
            result += "\(prefix)\(handler.name): \(handler.displayValue) [handler, line \(handler.line)]\n"
            if let ast = handler.pythonAST, !ast.isEmpty {
                result += KvPythonParser.formatTree(ast, depth: depth + 1, parentBranches: parentBranches + [!isLast])
            }
        }
        
        if let canvasBefore = canvasBefore {
            let (isLast, prefix) = next()
            result += "\(prefix)canvas.before [canvas, line \(canvasBefore.line)]\n"
            result += canvasBefore.detailedContent(depth: depth + 1, parentBranches: parentBranches + [!isLast])
        }
        
        if let canvas = canvas {
            let (isLast, prefix) = next()
            result += "\(prefix)canvas [canvas, line \(canvas.line)]\n"
            result += canvas.detailedContent(depth: depth + 1, parentBranches: parentBranches + [!isLast])
        }
        
        if let canvasAfter = canvasAfter {
            let (isLast, prefix) = next()
            result += "\(prefix)canvas.after [canvas, line \(canvasAfter.line)]\n"
            result += canvasAfter.detailedContent(depth: depth + 1, parentBranches: parentBranches + [!isLast])
        }
        
        for child in children {
            let (isLast, prefix) = next()
            let idInfo = child.id != nil ? ", id: \(child.id!)" : ""
            result += "\(prefix)\(child.name) [widget, line \(child.line)\(idInfo)]\n"
            result += child.detailedContent(depth: depth + 1, parentBranches: parentBranches + [!isLast])
        }
        
        for conditional in conditionals {
            let (isLast, prefix) = next()
            result += "\(prefix)\(conditional.headerText) [conditional, line \(conditional.line)]\n"
            result += conditional.detailedContent(depth: depth + 1, parentBranches: parentBranches + [!isLast])
        }
        
        return result
    }
}
