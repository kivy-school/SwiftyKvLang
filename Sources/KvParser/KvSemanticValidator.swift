/// Semantic validation for KV language AST
///
/// Validates:
/// - Widget class names against known Kivy widgets
/// - Property names for common widgets
/// - Undefined references in expressions
/// - Type consistency where possible
///
/// Design: Visitor-based validation with configurable rule sets

import Foundation

/// Validation issue severity
public enum ValidationSeverity {
    case error      // Must be fixed
    case warning    // Should be fixed
    case info       // Informational
}

/// Validation issue
public struct ValidationIssue: Sendable {
    public let line: Int
    public let column: Int
    public let severity: ValidationSeverity
    public let message: String
    public let suggestion: String?
    
    public init(line: Int, column: Int = 0, severity: ValidationSeverity, message: String, suggestion: String? = nil) {
        self.line = line
        self.column = column
        self.severity = severity
        self.message = message
        self.suggestion = suggestion
    }
}

/// Validation result
public struct ValidationResult: Sendable {
    public let issues: [ValidationIssue]
    
    public var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }
    
    public var hasWarnings: Bool {
        issues.contains { $0.severity == .warning }
    }
    
    public var isValid: Bool {
        !hasErrors
    }
    
    public init(issues: [ValidationIssue] = []) {
        self.issues = issues
    }
}

/// Semantic validator for KV AST
public class KvSemanticValidator: KvVisitor {
    private var issues: [ValidationIssue] = []
    private let knownWidgets: Set<String>
    private let commonProperties: Set<String>
    private var currentRule: String?
    
    /// Initialize with known widget types and properties
    public init(knownWidgets: Set<String>? = nil, commonProperties: Set<String>? = nil) {
        self.knownWidgets = knownWidgets ?? Self.defaultKivyWidgets
        self.commonProperties = commonProperties ?? Self.defaultCommonProperties
    }
    
    /// Validate a module and return issues
    public static func validate(_ module: KvModule, knownWidgets: Set<String>? = nil, commonProperties: Set<String>? = nil) -> ValidationResult {
        let validator = KvSemanticValidator(knownWidgets: knownWidgets, commonProperties: commonProperties)
        module.accept(visitor: validator)
        return ValidationResult(issues: validator.issues)
    }
    
    // MARK: - Visitor Implementation
    
    public func visitRule(_ rule: KvRule) {
        currentRule = rule.selector.primaryName
        
        // Validate selector
        validateSelector(rule.selector, line: rule.line)
        
        visitBody(rule.body)
        
        currentRule = nil
    }
    
    public func visitWidget(_ widget: KvWidget) {
        // Validate widget class name
        validateWidgetName(widget.name, line: widget.line)
        
        visitBody(widget.body)
    }
    
    public func visitConditional(_ conditional: KvConditional) {
        if let condition = conditional.condition {
            validateExpression(condition, propertyName: "if", line: conditional.line)
        }
        
        visitBody(conditional.body)
        if let elseBody = conditional.elseBody {
            visitBody(elseBody)
        }
    }
    
    public func visitProperty(_ property: KvProperty) {
        // Validate property name format
        validatePropertyName(property.name, line: property.line)
        
        // Check for undefined references in expressions using raw value
        validateExpression(property.value, propertyName: property.name, line: property.line)
    }
    
    public func visitCanvasInstruction(_ instruction: KvCanvasInstruction) {
        // Validate canvas instruction type
        validateCanvasInstruction(instruction.instructionType, line: instruction.line)
        
        // Validate properties
        for property in instruction.properties {
            visitProperty(property)
        }
    }
    
    // MARK: - Validation Methods
    
    private func validateSelector(_ selector: KvSelector, line: Int) {
        switch selector {
        case .name(let name):
            validateWidgetName(name, line: line)
            
        case .multiple(let selectors):
            for subSelector in selectors {
                validateSelector(subSelector, line: line)
            }
            
        case .dynamicClass(let name, let bases):
            // Validate base classes
            for base in bases {
                validateWidgetName(base, line: line)
            }
            
            // Check naming convention for dynamic classes
            if name.first?.isLowercase == true {
                issues.append(ValidationIssue(
                    line: line,
                    severity: .warning,
                    message: "Dynamic class '\(name)' should start with uppercase letter",
                    suggestion: "Rename to '\(name.prefix(1).uppercased())\(name.dropFirst())'"
                ))
            }
            
        case .className:
            // CSS-style class selector - no validation needed
            break
        }
    }
    
    private func validateWidgetName(_ name: String, line: Int) {
        // Skip if it looks like a custom widget
        if name.first?.isUppercase != true {
            return
        }
        
        // Check if it's a known widget or looks custom
        if !knownWidgets.contains(name) {
            // Allow custom widgets that follow naming convention
            if name.contains("Custom") || name.contains("My") || name.hasSuffix("View") {
                return
            }
            
            issues.append(ValidationIssue(
                line: line,
                severity: .warning,
                message: "Unknown widget type: '\(name)'",
                suggestion: "Verify this is a valid Kivy widget or custom class"
            ))
        }
    }
    
    private func validatePropertyName(_ name: String, line: Int) {
        // Event handlers are always valid
        if name.hasPrefix("on_") {
            return
        }
        
        // Check for common typos
        let commonTypos: [String: String] = [
            "colour": "color",
            "centre": "center",
            "widht": "width",
            "heigth": "height",
            "poistion": "position"
        ]
        
        if let correction = commonTypos[name] {
            issues.append(ValidationIssue(
                line: line,
                severity: .error,
                message: "Invalid property name: '\(name)'",
                suggestion: "Did you mean '\(correction)'?"
            ))
        }
        
        // Warn about uncommon properties (likely typos)
        if !commonProperties.contains(name) && !name.contains("_") {
            // Properties with underscores are often valid custom properties
            if name.count < 3 {
                issues.append(ValidationIssue(
                    line: line,
                    severity: .warning,
                    message: "Unusual property name: '\(name)'",
                    suggestion: "Verify this property exists for the widget type"
                ))
            }
        }
    }
    
    private func validateExpression(_ expression: String, propertyName: String, line: Int) {
        // Check for undefined 'app' reference without proper setup
        if expression.contains("app.") && !expression.contains("from ") {
            issues.append(ValidationIssue(
                line: line,
                severity: .info,
                message: "Property '\(propertyName)' references 'app'",
                suggestion: "Ensure App.get_running_app() is accessible"
            ))
        }
        
        // Check for undefined 'root' in rule context
        if expression.contains("root.") && currentRule != nil {
            issues.append(ValidationIssue(
                line: line,
                severity: .info,
                message: "Property '\(propertyName)' references 'root'",
                suggestion: "'root' refers to the root widget of this rule"
            ))
        }
        
        // Warn about complex expressions that might be better in Python
        let complexityIndicators = ["for ", " in ", "lambda ", "[x for x"]
        for indicator in complexityIndicators {
            if expression.contains(indicator) {
                issues.append(ValidationIssue(
                    line: line,
                    severity: .info,
                    message: "Complex expression in KV file",
                    suggestion: "Consider moving this logic to Python code"
                ))
                break
            }
        }
        
        // Check for common mistakes
        if expression.contains("self.self.") {
            issues.append(ValidationIssue(
                line: line,
                severity: .error,
                message: "Redundant 'self.self.' in expression",
                suggestion: "Use 'self.' instead"
            ))
        }
        
        // Check for assignment in expression context (common mistake)
        if propertyName != "on_" && !propertyName.hasPrefix("on_") {
            if expression.contains(" = ") && !expression.contains("==") && !expression.contains("!=") {
                issues.append(ValidationIssue(
                    line: line,
                    severity: .warning,
                    message: "Assignment operator '=' in property expression",
                    suggestion: "Did you mean comparison '=='?"
                ))
            }
        }
    }
    
    private func validateCanvasInstruction(_ instructionType: String, line: Int) {
        let knownInstructions: Set<String> = [
            "Color", "Rectangle", "Ellipse", "Line", "Triangle", "Quad",
            "Bezier", "Mesh", "Point", "BorderImage", "StencilPush", "StencilPop",
            "StencilUse", "StencilUnUse", "PushMatrix", "PopMatrix", "Rotate",
            "Scale", "Translate", "MatrixInstruction", "RenderContext", "Callback"
        ]
        
        if !knownInstructions.contains(instructionType) {
            issues.append(ValidationIssue(
                line: line,
                severity: .warning,
                message: "Unknown canvas instruction: '\(instructionType)'",
                suggestion: "Verify this is a valid Kivy graphics instruction"
            ))
        }
    }
    
    // MARK: - Known Widgets and Properties
    
    /// Default set of Kivy widgets (common ones)
    private static let defaultKivyWidgets: Set<String> = [
        // Layout widgets
        "BoxLayout", "FloatLayout", "GridLayout", "StackLayout", "AnchorLayout",
        "RelativeLayout", "PageLayout", "ScatterLayout",
        
        // Basic widgets
        "Widget", "Label", "Button", "Image", "Video", "Camera",
        "TextInput", "Slider", "ProgressBar", "Switch", "Checkbox",
        "Spinner", "ToggleButton", "ActionButton",
        
        // Container widgets
        "ScrollView", "TabbedPanel", "Carousel", "Accordion", "Splitter",
        
        // Behavior widgets  
        "ButtonBehavior", "ToggleButtonBehavior", "DragBehavior",
        
        // Special widgets
        "FileChooser", "FileChooserListView", "FileChooserIconView",
        "ColorPicker", "Popup", "ModalView", "Scatter",
        
        // Compound widgets
        "ActionBar", "ActionView", "ActionPrevious", "ActionOverflow",
        "ActionGroup", "Bubble", "BubbleButton", "BubbleContent",
        "EffectWidget", "RecycleView", "RecycleBoxLayout", "RecycleGridLayout"
    ]
    
    /// Default set of common properties
    private static let defaultCommonProperties: Set<String> = [
        // Size and position
        "pos", "size", "width", "height", "x", "y", "center", "center_x", "center_y",
        "top", "right", "bottom", "left",
        "size_hint", "size_hint_x", "size_hint_y", "size_hint_min", "size_hint_max",
        "pos_hint",
        
        // Appearance
        "color", "background_color", "background_normal", "background_down",
        "opacity", "canvas", "font_size", "font_name", "bold", "italic",
        
        // Layout
        "orientation", "spacing", "padding", "cols", "rows",
        
        // Common widget properties
        "text", "disabled", "state", "value", "min", "max", "step",
        "multiline", "readonly", "password", "hint_text",
        "source", "texture", "allow_stretch", "keep_ratio",
        
        // Behavior
        "do_scroll_x", "do_scroll_y", "scroll_type", "bar_width",
        "always_release", "allow_stretch"
    ]
}
