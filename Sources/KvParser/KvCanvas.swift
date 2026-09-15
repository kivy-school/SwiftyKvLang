/// Canvas instruction layer
///
/// KV supports three canvas layers:
/// - canvas.before: Rendered before the widget
/// - canvas: Main canvas (default)
/// - canvas.after: Rendered after the widget
///
/// Each layer contains graphics instructions (Color, Rectangle, Line, etc.)
///
/// Example from style.kv:
/// ```
/// canvas:
///     Color:
///         rgba: 1, 1, 1, 1
///     Rectangle:
///         pos: self.pos
///         size: self.size
/// ```
public struct KvCanvas: KvNode, Sendable {
    /// Graphics instructions in this canvas layer
    public let instructions: [KvCanvasInstruction]
    
    // Position tracking
    public let line: Int
    public let column: Int
    public let endLine: Int?
    public let endColumn: Int?
    
    public init(
        instructions: [KvCanvasInstruction] = [],
        line: Int,
        column: Int = 0,
        endLine: Int? = nil,
        endColumn: Int? = nil
    ) {
        self.instructions = instructions
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
}

extension KvCanvas: TreeDisplayable {
    public func treeDescription(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var result = ""
        
        if instructions.isEmpty {
            result += "\(prefix)(empty)\n"
        } else {
            for instruction in instructions {
                result += instruction.treeDescription(indent: indent)
            }
        }
        
        return result
    }
    
    /// Detailed tree content for deep traversal
    internal func detailedContent(depth: Int, parentBranches: [Bool]) -> String {
        var result = ""
        
        for (index, instruction) in instructions.enumerated() {
            let isLast = index == instructions.count - 1
            let prefix = TreeFormatter.prefix(depth: depth, isLast: isLast, parentBranches: parentBranches)
            result += "\(prefix)\(instruction.instructionType) [instruction, line \(instruction.line)]\n"
            
            // Add properties of the instruction
            for (propIndex, prop) in instruction.properties.enumerated() {
                let isPropLast = propIndex == instruction.properties.count - 1
                let propPrefix = TreeFormatter.prefix(depth: depth + 1, isLast: isPropLast, parentBranches: parentBranches + [!isLast])
                result += "\(propPrefix)\(prop.name): \(prop.displayValue) [property, line \(prop.line)]\n"
            }
        }
        
        return result
    }
}

/// Canvas graphics instruction
///
/// Represents a single graphics instruction within a canvas layer.
/// Common instructions include: Color, Rectangle, Ellipse, Line,
/// BorderImage, PushMatrix, PopMatrix, Rotate, Translate, etc.
///
/// Example:
/// ```
/// Rectangle:
///     pos: self.x, self.y
///     size: self.width, self.height
/// ```
public struct KvCanvasInstruction: KvNode, Sendable {
    /// Instruction type (e.g., "Color", "Rectangle", "Line")
    public let instructionType: String
    
    /// Properties of this instruction
    public let properties: [KvProperty]
    
    // Position tracking
    public let line: Int
    public let column: Int
    public let endLine: Int?
    public let endColumn: Int?
    
    public init(
        instructionType: String,
        properties: [KvProperty] = [],
        line: Int,
        column: Int = 0,
        endLine: Int? = nil,
        endColumn: Int? = nil
    ) {
        self.instructionType = instructionType
        self.properties = properties
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
}

extension KvCanvasInstruction: TreeDisplayable {
    public func treeDescription(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var result = "\(prefix)\(instructionType): [line \(line)]\n"
        
        for prop in properties {
            result += prop.treeDescription(indent: indent + 1)
        }
        
        return result
    }
}

/// Known canvas instruction types from Kivy
///
/// Reference: Kivy graphics module
public enum KnownCanvasInstruction: String, CaseIterable {
    // Context instructions
    case pushMatrix = "PushMatrix"
    case popMatrix = "PopMatrix"
    case rotate = "Rotate"
    case translate = "Translate"
    case scale = "Scale"
    case matrixInstruction = "MatrixInstruction"
    
    // Stencil instructions
    case stencilPush = "StencilPush"
    case stencilPop = "StencilPop"
    case stencilUse = "StencilUse"
    case stencilUnUse = "StencilUnUse"
    
    // Color instruction
    case color = "Color"
    
    // Shape instructions
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case line = "Line"
    case bezier = "Bezier"
    case triangle = "Triangle"
    case quad = "Quad"
    case roundedRectangle = "RoundedRectangle"
    
    // Image instructions
    case borderImage = "BorderImage"
    
    // Mesh instruction
    case mesh = "Mesh"
    
    public static func isKnown(_ name: String) -> Bool {
        return KnownCanvasInstruction(rawValue: name) != nil
    }
}
