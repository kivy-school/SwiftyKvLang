/// AST Visitor Protocol
///
/// Implements the Visitor pattern for traversing and operating on KV AST nodes.
/// This enables separation of concerns: AST structure vs. operations on AST.
///
/// Example usage:
/// ```swift
/// struct PropertyCollector: KvVisitor {
///     var properties: [String] = []
///     
///     mutating func visitProperty(_ property: KvProperty) {
///         properties.append(property.name)
///     }
/// }
/// ```
public protocol KvVisitor: AnyObject {
    /// Visit a module (root node)
    func visitModule(_ module: KvModule)
    
    /// Visit a directive
    func visitDirective(_ directive: KvDirective)
    
    /// Visit a rule
    func visitRule(_ rule: KvRule)
    
    /// Visit a selector
    func visitSelector(_ selector: KvSelector)
    
    /// Visit a template
    func visitTemplate(_ template: KvTemplate)
    
    /// Visit a widget instance
    func visitWidget(_ widget: KvWidget)
    
    /// Visit a property
    func visitProperty(_ property: KvProperty)
    
    /// Visit a conditional block (if/else, try/expect)
    func visitConditional(_ conditional: KvConditional)
    
    /// Visit the contents of a rule, widget, or conditional branch body
    func visitBody(_ body: KvBody)
    
    /// Visit canvas
    func visitCanvas(_ canvas: KvCanvas)
    
    /// Visit a canvas instruction
    func visitCanvasInstruction(_ instruction: KvCanvasInstruction)
}

// MARK: - Default Implementations

extension KvVisitor {
    /// Default implementation: traverse children
    public func visitModule(_ module: KvModule) {
        for directive in module.directives {
            visitDirective(directive)
        }
        for rule in module.rules {
            visitRule(rule)
        }
        for template in module.templates {
            visitTemplate(template)
        }
        if let root = module.root {
            visitWidget(root)
        }
    }
    
    /// Default implementation: no-op
    public func visitDirective(_ directive: KvDirective) {}
    
    /// Default implementation: traverse body
    public func visitRule(_ rule: KvRule) {
        visitSelector(rule.selector)
        visitBody(rule.body)
    }
    
    /// Default implementation: no-op
    public func visitSelector(_ selector: KvSelector) {}
    
    /// Default implementation: traverse the rule
    public func visitTemplate(_ template: KvTemplate) {
        visitRule(template.rule)
    }
    
    /// Default implementation: traverse body
    public func visitWidget(_ widget: KvWidget) {
        visitBody(widget.body)
    }
    
    /// Default implementation: no-op
    public func visitProperty(_ property: KvProperty) {}
    
    /// Default implementation: traverse both branches
    public func visitConditional(_ conditional: KvConditional) {
        visitBody(conditional.body)
        if let elseBody = conditional.elseBody {
            visitBody(elseBody)
        }
    }
    
    /// Default implementation: traverse every member of the body
    public func visitBody(_ body: KvBody) {
        for property in body.properties {
            visitProperty(property)
        }
        for handler in body.handlers {
            visitProperty(handler)
        }
        
        if let canvas = body.canvas {
            visitCanvas(canvas)
        }
        if let canvasBefore = body.canvasBefore {
            visitCanvas(canvasBefore)
        }
        if let canvasAfter = body.canvasAfter {
            visitCanvas(canvasAfter)
        }
        
        for child in body.children {
            visitWidget(child)
        }
        for conditional in body.conditionals {
            visitConditional(conditional)
        }
    }
    
    /// Default implementation: traverse instructions
    public func visitCanvas(_ canvas: KvCanvas) {
        for instruction in canvas.instructions {
            visitCanvasInstruction(instruction)
        }
    }
    
    /// Default implementation: traverse properties
    public func visitCanvasInstruction(_ instruction: KvCanvasInstruction) {
        for property in instruction.properties {
            visitProperty(property)
        }
    }
}

// MARK: - Node Extensions for Visitor Pattern

extension KvModule {
    /// Accept a visitor
    public func accept<V: KvVisitor>(visitor: V) {
        visitor.visitModule(self)
    }
}

extension KvDirective {
    /// Accept a visitor
    public func accept<V: KvVisitor>(visitor: V) {
        visitor.visitDirective(self)
    }
}

extension KvRule {
    /// Accept a visitor
    public func accept<V: KvVisitor>(visitor: V) {
        visitor.visitRule(self)
    }
}

extension KvSelector {
    /// Accept a visitor
    public func accept<V: KvVisitor>(visitor: V) {
        visitor.visitSelector(self)
    }
}

extension KvTemplate {
    /// Accept a visitor
    public func accept<V: KvVisitor>(visitor: V) {
        visitor.visitTemplate(self)
    }
}

extension KvWidget {
    /// Accept a visitor
    public func accept<V: KvVisitor>(visitor: V) {
        visitor.visitWidget(self)
    }
}

extension KvProperty {
    /// Accept a visitor
    public func accept<V: KvVisitor>(visitor: V) {
        visitor.visitProperty(self)
    }
}

extension KvCanvas {
    /// Accept a visitor
    public func accept<V: KvVisitor>(visitor: V) {
        visitor.visitCanvas(self)
    }
}

extension KvConditional {
    /// Accept a visitor
    public func accept<V: KvVisitor>(visitor: V) {
        visitor.visitConditional(self)
    }
}

extension KvCanvasInstruction {
    /// Accept a visitor
    public func accept<V: KvVisitor>(visitor: V) {
        visitor.visitCanvasInstruction(self)
    }
}

// MARK: - Built-in Visitors

/// Collects all property names in the AST
public class PropertyNameCollector: KvVisitor {
    public var propertyNames: [String] = []
    
    public init() {}
    
    public func visitProperty(_ property: KvProperty) {
        propertyNames.append(property.name)
    }
}

/// Collects all widget names in the AST
public class WidgetNameCollector: KvVisitor {
    public var widgetNames: [String] = []
    
    public init() {}
    
    public func visitWidget(_ widget: KvWidget) {
        widgetNames.append(widget.name)
        visitBody(widget.body)
    }
}

/// Collects all selectors in rules
public class SelectorCollector: KvVisitor {
    public var selectors: [String] = []
    
    public init() {}
    
    public func visitSelector(_ selector: KvSelector) {
        selectors.append(selector.primaryName)
    }
}

/// Finds properties with watched keys (reactive bindings)
public class WatchedPropertyFinder: KvVisitor {
    public var watchedProperties: [(rule: String, property: String, keys: [[String]])] = []
    private var currentRule: String?
    
    public init() {}
    
    public func visitRule(_ rule: KvRule) {
        currentRule = rule.selector.primaryName
        visitBody(rule.body)
        currentRule = nil
    }
    
    public func visitConditional(_ conditional: KvConditional) {
        if case .if(_, let keys) = conditional.kind, !keys.isEmpty {
            watchedProperties.append((rule: currentRule ?? "unknown", property: "if", keys: keys))
        }
        visitBody(conditional.body)
        if let elseBody = conditional.elseBody {
            visitBody(elseBody)
        }
    }
    
    public func visitProperty(_ property: KvProperty) {
        // Check if property has watched keys
        if case .expression(let value) = property.compiledValue {
            let compiled = KvCompiler.compile(propertyName: property.name, value: value)
            if !compiled.watchedKeys.isEmpty {
                watchedProperties.append((
                    rule: currentRule ?? "unknown",
                    property: property.name,
                    keys: compiled.watchedKeys
                ))
            }
        }
    }
}

/// Statistics collector for AST analysis
public class ASTStatistics: KvVisitor {
    public var ruleCount = 0
    public var templateCount = 0
    public var widgetCount = 0
    public var propertyCount = 0
    public var canvasInstructionCount = 0
    public var directiveCount = 0
    public var conditionalCount = 0
    
    public init() {}
    
    public func visitDirective(_ directive: KvDirective) {
        directiveCount += 1
    }
    
    public func visitRule(_ rule: KvRule) {
        ruleCount += 1
        visitBody(rule.body)
    }
    
    public func visitTemplate(_ template: KvTemplate) {
        templateCount += 1
        visitRule(template.rule)
    }
    
    public func visitWidget(_ widget: KvWidget) {
        widgetCount += 1
        visitBody(widget.body)
    }
    
    public func visitProperty(_ property: KvProperty) {
        propertyCount += 1
    }
    
    public func visitConditional(_ conditional: KvConditional) {
        conditionalCount += 1
        visitBody(conditional.body)
        if let elseBody = conditional.elseBody {
            visitBody(elseBody)
        }
    }
    
    public func visitCanvasInstruction(_ instruction: KvCanvasInstruction) {
        canvasInstructionCount += 1
        
        // Count properties in canvas instructions
        for property in instruction.properties {
            visitProperty(property)
        }
    }
    
    public var summary: String {
        """
        AST Statistics:
          Directives: \(directiveCount)
          Rules: \(ruleCount)
          Templates: \(templateCount)
          Widgets: \(widgetCount)
          Properties: \(propertyCount)
          Canvas Instructions: \(canvasInstructionCount)
          Conditionals: \(conditionalCount)
        """
    }
}
