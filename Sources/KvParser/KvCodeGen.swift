/// KV Code Generator
///
/// Generates valid KV language source code from AST nodes.
/// Enables round-trip conversion: parse → AST → generate → parse
///
/// Example:
/// ```swift
/// let source = try KvCodeGen.generate(from: module)
/// ```
public struct KvCodeGen {
    
    // MARK: - Module Generation
    
    /// Generate KV source code from a module
    public static func generate(from module: KvModule, indent: String = "    ") -> String {
        var output = ""
        
        // Generate directives
        for directive in module.directives {
            output += generate(from: directive)
            output += "\n"
        }
        
        if !module.directives.isEmpty && (!module.rules.isEmpty || !module.templates.isEmpty || module.root != nil) {
            output += "\n"
        }
        
        // Generate rules
        for (index, rule) in module.rules.enumerated() {
            output += generate(from: rule, baseIndent: indent)
            if index < module.rules.count - 1 || !module.templates.isEmpty || module.root != nil {
                output += "\n"
            }
        }
        
        // Generate templates
        for (index, template) in module.templates.enumerated() {
            output += generate(from: template, baseIndent: indent)
            if index < module.templates.count - 1 || module.root != nil {
                output += "\n"
            }
        }
        
        // Generate root widget
        if let root = module.root {
            output += generate(from: root, level: 0, baseIndent: indent)
        }
        
        return output
    }
    
    // MARK: - Directive Generation
    
    private static func generate(from directive: KvDirective) -> String {
        return directive.sourceText
    }
    
    // MARK: - Rule Generation
    
    private static func generate(from rule: KvRule, baseIndent: String) -> String {
        let avoidPrefix = rule.avoidPrevious ? "-" : ""
        return "<\(avoidPrefix)\(generate(from: rule.selector))>\n"
            + generate(from: rule.body, level: 1, baseIndent: baseIndent)
    }
    
    // MARK: - Selector Generation
    
    private static func generate(from selector: KvSelector) -> String {
        switch selector {
        case .name(let name):
            return name
        case .className(let name):
            return ".\(name)"
        case .multiple(let selectors):
            return selectors.map { generate(from: $0) }.joined(separator: ",")
        case .dynamicClass(let name, let bases):
            let basesStr = bases.joined(separator: "+")
            return "\(name)@\(basesStr)"
        }
    }
    
    // MARK: - Template Generation
    
    private static func generate(from template: KvTemplate, baseIndent: String) -> String {
        let basesStr = template.baseClasses.joined(separator: "+")
        return "[\(template.name)@\(basesStr)]:\n"
            + generate(from: template.rule.body, level: 1, baseIndent: baseIndent)
    }
    
    // MARK: - Widget Generation
    
    private static func generate(from widget: KvWidget, level: Int, baseIndent: String) -> String {
        let indent = String(repeating: baseIndent, count: level)
        var output = indent + "\(widget.name):\n"
        
        if let id = widget.id {
            output += indent + baseIndent + "id: \(id)\n"
        }
        
        output += generate(from: widget.body, level: level + 1, baseIndent: baseIndent)
        return output
    }
    
    // MARK: - Body Generation
    
    /// Generate the contents of an indented block at `level`
    private static func generate(from body: KvBody, level: Int, baseIndent: String) -> String {
        var output = ""
        let indent = String(repeating: baseIndent, count: level)
        
        if let canvasBefore = body.canvasBefore {
            output += indent + "canvas.before:\n"
            output += generate(from: canvasBefore, level: level + 1, baseIndent: baseIndent)
        }
        
        for property in body.properties {
            output += indent + generate(from: property, level: level, baseIndent: baseIndent)
        }
        
        if let canvas = body.canvas {
            output += indent + "canvas:\n"
            output += generate(from: canvas, level: level + 1, baseIndent: baseIndent)
        }
        
        if let canvasAfter = body.canvasAfter {
            output += indent + "canvas.after:\n"
            output += generate(from: canvasAfter, level: level + 1, baseIndent: baseIndent)
        }
        
        for handler in body.handlers {
            output += indent + generate(from: handler, level: level, baseIndent: baseIndent)
        }
        
        for child in body.children {
            output += generate(from: child, level: level, baseIndent: baseIndent)
        }
        
        for conditional in body.conditionals {
            output += generate(from: conditional, level: level, baseIndent: baseIndent)
        }
        
        return output
    }
    
    // MARK: - Conditional Generation
    
    private static func generate(from conditional: KvConditional, level: Int, baseIndent: String) -> String {
        let indent = String(repeating: baseIndent, count: level)
        var output = indent + "\(conditional.headerText):\n"
        output += generate(from: conditional.body, level: level + 1, baseIndent: baseIndent)
        
        if let elseBody = conditional.elseBody {
            output += indent + "\(conditional.elseKeyword):\n"
            output += generate(from: elseBody, level: level + 1, baseIndent: baseIndent)
        }
        
        return output
    }
    
    // MARK: - Property Generation
    
    /// `name: value`, or `name: |` with the block re-indented one level deeper
    private static func generate(from property: KvProperty, level: Int, baseIndent: String) -> String {
        guard property.isBlock else {
            return "\(property.name): \(property.value)\n"
        }
        let inner = String(repeating: baseIndent, count: level + 1)
        let lines = property.value
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : inner + $0 }
            .joined(separator: "\n")
        return "\(property.name): |\n" + lines + "\n"
    }
    
    // MARK: - Canvas Generation
    
    private static func generate(from canvas: KvCanvas, level: Int, baseIndent: String) -> String {
        var output = ""
        let indent = String(repeating: baseIndent, count: level)
        
        for instruction in canvas.instructions {
            output += indent + generate(from: instruction, level: level, baseIndent: baseIndent)
        }
        
        return output
    }
    
    // MARK: - Canvas Instruction Generation
    
    private static func generate(from instruction: KvCanvasInstruction, level: Int, baseIndent: String) -> String {
        var output = ""
        
        // Generate instruction type
        output += "\(instruction.instructionType):\n"
        
        // Generate properties
        if !instruction.properties.isEmpty {
            let indent = String(repeating: baseIndent, count: level + 1)
            for property in instruction.properties {
                output += indent + generate(from: property, level: level + 1, baseIndent: baseIndent)
            }
        }
        
        return output
    }
}

// MARK: - Module Extension

extension KvModule {
    /// Generate KV source code from this module
    public func generate(indent: String = "    ") -> String {
        return KvCodeGen.generate(from: self, indent: indent)
    }
}
