import PySwiftAST

/// KV language parser
///
/// Implements recursive descent parsing following parser.py's parse_level() algorithm.
/// Handles indentation-based structure (YAML-inspired), widget selectors, properties,
/// canvas instructions, and directives.
///
/// Reference: parser.py lines 454-777
public final class KvParser {
    internal let tokens: [Token]
    internal var current: Int = 0
    private var filename: String?
    
    public init(tokens: [Token], filename: String? = nil) {
        self.tokens = tokens
        self.filename = filename
    }
    
    /// Parse tokens into a KV module
    public func parse() throws -> KvModule {
        var directives: [KvDirective] = []
        var rules: [KvRule] = []
        var templates: [KvTemplate] = []
        var root: KvWidget? = nil
        var dynamicClasses: [String: String] = [:]
        
        // Pre-allocate capacity based on typical style.kv structure
        directives.reserveCapacity(4)
        rules.reserveCapacity(80)
        templates.reserveCapacity(5)
        
        // First pass: extract directives
        directives = try parseDirectives()
        
        // Second pass: parse rules, templates, and root widget
        while !isAtEnd {
            skipNewlines()
            if isAtEnd { break }
            
            let token = peek()
            
            // Check for rule selector: <...>
            if case .leftAngle = token.type {
                let rule = try parseRule()
                rules.append(rule)
                
                // Collect dynamic class definitions
                if case .dynamicClass(let name, let bases) = rule.selector {
                    dynamicClasses[name] = bases.joined(separator: "+")
                }
            }
            // Check for template: [...]
            else if case .leftBracket = token.type {
                let template = try parseTemplate()
                templates.append(template)
            }
            // Otherwise it's a root widget (if we don't have one yet)
            else if case .identifier(_) = token.type {
                if root == nil {
                    root = try parseWidget(level: 0)
                } else {
                    throw KvParserError.syntaxError(
                        line: token.line,
                        message: "Only one root widget allowed in KV file"
                    )
                }
            }
            else {
                // Skip unexpected tokens
                advance()
            }
        }
        
        return KvModule(
            directives: directives,
            rules: rules,
            templates: templates,
            root: root,
            dynamicClasses: dynamicClasses,
            line: 1,
            column: 0
        )
    }
    
    // MARK: - Directive Parsing
    
    /// Parse all directives from token stream
    /// Reference: parser.py lines 490-570
    private func parseDirectives() throws -> [KvDirective] {
        var directives: [KvDirective] = []
        
        for token in tokens {
            guard case .directive(let text) = token.type else { continue }
            let directive = try parseDirective(text: text, line: token.line)
            directives.append(directive)
        }
        
        return directives
    }
    
    /// Parse a single directive from its text
    internal func parseDirective(text: String, line: Int) throws -> KvDirective {
        // Remove #: prefix
        let content = text.dropFirst(2).trimmingCharacters(in: .whitespaces)
        let parts = content.split(separator: " ", maxSplits: 2).map(String.init)
        
        guard let command = parts.first else {
            throw KvParserError.syntaxError(line: line, message: "Empty directive")
        }
        
        switch command {
        case "kivy":
            // #:kivy 1.0
            if parts.count >= 2 {
                return .kivy(version: parts[1], line: line)
            }
            
        case "import":
            // #:import alias module.path
            if parts.count >= 3 {
                return .import(
                    alias: parts[1],
                    package: parts[2],
                    line: line
                )
            }
            
        case "from":
            // #:from module.path import name [as alias]
            let words = content.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            if words.count >= 4, words[2] == "import" {
                var alias: String? = nil
                if words.count >= 6, words[4] == "as" {
                    alias = words[5]
                } else if words.count != 4 {
                    break
                }
                return .from(module: words[1], name: words[3], alias: alias, line: line)
            }
            
        case "mode":
            // #:mode default|carbonkivy|nucleant|swiftui
            if parts.count == 2 {
                return .mode(name: parts[1], line: line)
            }
            
        case "set":
            // #:set name value
            if parts.count >= 3 {
                return .set(
                    name: parts[1],
                    value: parts[2],
                    line: line
                )
            }
            
        case "include":
            // #:include [force] path
            var force = false
            var path = ""
            
            if parts.count >= 3 && parts[1] == "force" {
                force = true
                path = parts[2]
            } else if parts.count >= 2 {
                path = parts[1]
            }
            
            // Remove quotes if present
            if path.hasPrefix("'") && path.hasSuffix("'") ||
               path.hasPrefix("\"") && path.hasSuffix("\"") {
                path = String(path.dropFirst().dropLast())
            }
            
            return .include(path: path, force: force, line: line)
            
        default:
            throw KvParserError.syntaxError(
                line: line,
                message: "Unknown directive: #:\(command)"
            )
        }
        
        throw KvParserError.syntaxError(line: line, message: "Invalid directive format")
    }
    
    // MARK: - Rule Parsing
    
    /// Parse a rule: <Selector>:
    /// Reference: parser.py lines 394-432
    internal func parseRule() throws -> KvRule {
        let startToken = peek()
        guard case .leftAngle = startToken.type else {
            throw KvParserError.unexpectedToken(token: startToken, expected: "<")
        }
        advance() // consume <
        
        // Check for avoidance prefix (-)
        var avoidPrevious = false
        if case .minus = peek().type {
            avoidPrevious = true
            advance()
        }
        
        // Parse selector
        let selector = try parseSelector()
        
        // Expect >
        guard case .rightAngle = peek().type else {
            throw KvParserError.unexpectedToken(token: peek(), expected: ">")
        }
        advance()
        
        skipNewlines()  // Allow newlines before colon
        
        // Optionally expect : (colon is optional in KV lang)
        if case .colon = peek().type {
            advance()
        }
        
        skipNewlines()
        
        // Expect INDENT for rule body
        guard case .indent = peek().type else {
            // Empty rule is valid
            return KvRule(
                selector: selector,
                avoidPrevious: avoidPrevious,
                line: startToken.line
            )
        }
        advance()
        
        // Parse rule body (properties, canvas, children, conditionals)
        let body = try parseRuleBody()
        
        // Expect DEDENT
        if case .dedent = peek().type {
            advance()
        }
        
        return KvRule(
            selector: selector,
            body: body,
            avoidPrevious: avoidPrevious,
            line: startToken.line
        )
    }
    
    /// Parse selector inside < >
    /// Can be: WidgetName, .className, Widget1,Widget2, or New@Base+Base2
    /// Also handles avoidance prefix: <-Widget1,-Widget2>
    private func parseSelector() throws -> KvSelector {
        var selectors: [KvSelector] = []
        
        while true {
            // Check for avoidance prefix before each selector
            var hasLocalMinus = false
            if case .minus = peek().type {
                hasLocalMinus = true
                advance()
            }
            
            // Check for class selector (.className)
            if case .dot = peek().type {
                advance()
                guard case .identifier(let className) = peek().type else {
                    throw KvParserError.unexpectedToken(token: peek(), expected: "class name")
                }
                advance()
                selectors.append(.className(className))
            }
            // Check for regular name or dynamic class (Name@Base)
            else if case .identifier(let name) = peek().type {
                advance()
                
                // Check for @ (dynamic class)
                if case .at = peek().type {
                    advance()
                    
                    // Parse base classes (Base1+Base2+...)
                    var bases: [String] = []
                    while case .identifier(let base) = peek().type {
                        advance()
                        bases.append(base)
                        
                        if case .plus = peek().type {
                            advance()
                        } else {
                            break
                        }
                    }
                    
                    selectors.append(.dynamicClass(name: name, bases: bases))
                } else {
                    selectors.append(.name(name))
                }
            }
            else {
                break
            }
            
            // Check for comma (multiple selectors)
            if case .comma = peek().type {
                advance()
            } else {
                break
            }
        }
        
        if selectors.isEmpty {
            throw KvParserError.syntaxError(
                line: peek().line,
                message: "Empty selector"
            )
        }
        
        return selectors.count == 1 ? selectors[0] : .multiple(selectors)
    }
    
    // MARK: - Template Parsing
    
    /// Parse template: [Name@Base]:
    /// Reference: parser.py lines 434-452
    internal func parseTemplate() throws -> KvTemplate {
        let startToken = peek()
        guard case .leftBracket = startToken.type else {
            throw KvParserError.unexpectedToken(token: startToken, expected: "[")
        }
        advance()
        
        // Parse name
        guard case .identifier(let name) = peek().type else {
            throw KvParserError.unexpectedToken(token: peek(), expected: "template name")
        }
        advance()
        
        // Expect @
        guard case .at = peek().type else {
            throw KvParserError.unexpectedToken(token: peek(), expected: "@")
        }
        advance()
        
        // Parse base classes
        var bases: [String] = []
        while case .identifier(let base) = peek().type {
            advance()
            bases.append(base)
            
            if case .plus = peek().type {
                advance()
            } else {
                break
            }
        }
        
        // Expect ]
        guard case .rightBracket = peek().type else {
            throw KvParserError.unexpectedToken(token: peek(), expected: "]")
        }
        advance()
        
        // Expect :
        guard case .colon = peek().type else {
            throw KvParserError.unexpectedToken(token: peek(), expected: ":")
        }
        advance()
        
        skipNewlines()
        
        // Parse as a rule with dummy selector
        guard case .indent = peek().type else {
            throw KvParserError.syntaxError(
                line: peek().line,
                message: "Template body must be indented"
            )
        }
        advance()
        
        let body = try parseRuleBody()
        
        if case .dedent = peek().type {
            advance()
        }
        
        let rule = KvRule(
            selector: .name(name),
            body: body,
            line: startToken.line
        )
        
        return KvTemplate(
            name: name,
            baseClasses: bases,
            rule: rule,
            line: startToken.line
        )
    }
    
    // MARK: - Widget Parsing
    
    /// Parse a widget instance
    internal func parseWidget(level: Int) throws -> KvWidget {
        let startToken = peek()
        guard case .identifier(let name) = startToken.type else {
            throw KvParserError.unexpectedToken(token: startToken, expected: "widget name")
        }
        advance()
        
        // Expect : (but be tolerant of newline first)
        skipNewlines()
        guard case .colon = peek().type else {
            throw KvParserError.unexpectedToken(token: peek(), expected: ":")
        }
        advance()
        
        skipNewlines()
        
        // Check for body
        guard case .indent = peek().type else {
            // Empty widget
            return KvWidget(
                name: name,
                level: level,
                line: startToken.line
            )
        }
        advance()
        
        var body = try parseRuleBody()
        
        if case .dedent = peek().type {
            advance()
        }
        
        // Extract id from properties
        let id = body.properties.first { $0.name == "id" }?.value
        body.properties.removeAll { $0.name == "id" }
        
        return KvWidget(
            name: name,
            id: id,
            body: body,
            level: level,
            line: startToken.line
        )
    }
    
    /// Parse rule/widget body (properties, canvas, children, conditionals)
    /// Reference: parser.py lines 640-777
    private func parseRuleBody() throws -> KvBody {
        var body = KvBody()
        
        while !isAtEnd {
            skipNewlines()
            
            let token = peek()
            
            // Check for DEDENT (end of body)
            if case .dedent = token.type {
                break
            }
            
            // Check for canvas keywords
            if case .canvas = token.type {
                advance()
                
                // Check for .before or .after
                var canvasType: String = "canvas"
                if case .dot = peek().type {
                    advance()
                    if case .identifier(let modifier) = peek().type {
                        advance()
                        canvasType = "canvas.\(modifier)"
                    }
                }
                
                // Expect :
                guard case .colon = peek().type else {
                    throw KvParserError.unexpectedToken(token: peek(), expected: ":")
                }
                advance()
                
                skipNewlines()
                
                // Parse canvas instructions
                if case .indent = peek().type {
                    advance()
                    let instructions = try parseCanvasInstructions()
                    if case .dedent = peek().type {
                        advance()
                    }
                    
                    let canvasNode = KvCanvas(
                        instructions: instructions,
                        line: token.line
                    )
                    
                    switch canvasType {
                    case "canvas.before":
                        body.canvasBefore = canvasNode
                    case "canvas.after":
                        body.canvasAfter = canvasNode
                    default:
                        body.canvas = canvasNode
                    }
                }
            }
            // Check for conditional block: if <cond>: / try:
            else if case .identifier(let name) = token.type, Self.conditionalKeywords.contains(name) {
                body.conditionals.append(try parseConditional())
            }
            // Check for property or child widget
            else if case .identifier(let name) = token.type {
                let nextIdx = current + 1
                if nextIdx < tokens.count, case .colon = tokens[nextIdx].type {
                    // Distinguish between property and child widget:
                    // - Widget names start with uppercase (Button, Label, BoxLayout)
                    // - Property names start with lowercase or underscore (text, _internal_prop)
                    let isWidget = name.first?.isUppercase ?? false
                    
                    if isWidget {
                        // It's a child widget
                        current = nextIdx - 1 // Reset to identifier
                        let child = try parseWidget(level: 1) // level is relative
                        body.children.append(child)
                    } else {
                        // It's a property (including multi-line properties)
                        current = nextIdx - 1 // Reset to identifier
                        let property = try parseProperty()
                        
                        if name.hasPrefix("on_") {
                            body.handlers.append(property)
                        } else {
                            body.properties.append(property)
                        }
                    }
                } else {
                    advance()
                }
            }
            else {
                advance()
            }
        }
        
        return body
    }
    
    // MARK: - Conditional Parsing
    
    /// Keywords that open a conditional block or its alternate branch
    private static let conditionalKeywords: Swift.Set<String> = ["if", "else", "try", "expect", "except"]
    
    /// Parse `if <cond>:` ... `else:` or `try:` ... `expect:` blocks
    private func parseConditional() throws -> KvConditional {
        let startToken = peek()
        guard case .identifier(let keyword) = startToken.type else {
            throw KvParserError.unexpectedToken(token: startToken, expected: "if or try")
        }
        
        let kind: KvConditional.Kind
        switch keyword {
        case "if":
            advance()
            let condition = try parseConditionHeader()
            let compiled = KvCompiler.compile(propertyName: "if", value: condition)
            kind = .if(condition: condition, watchedKeys: compiled.watchedKeys)
        case "try":
            advance()
            guard case .colon = peek().type else {
                throw KvParserError.unexpectedToken(token: peek(), expected: ":")
            }
            advance()
            kind = .try
        default:
            throw KvParserError.syntaxError(
                line: startToken.line,
                message: "'\(keyword)' without a preceding \(keyword == "else" ? "if" : "try") block"
            )
        }
        
        let body = try parseConditionalBranch(keyword: keyword, line: startToken.line)
        
        // Optional else / expect branch at the same level
        var elseBody: KvBody? = nil
        skipNewlines()
        if case .identifier(let next) = peek().type,
           next == (kind == .try ? "expect" : "else") || (kind == .try && next == "except") {
            let elseToken = advance()
            guard case .colon = peek().type else {
                throw KvParserError.unexpectedToken(token: peek(), expected: ":")
            }
            advance()
            elseBody = try parseConditionalBranch(keyword: next, line: elseToken.line)
        }
        
        return KvConditional(kind: kind, body: body, elseBody: elseBody, line: startToken.line)
    }
    
    /// Collect the condition of an `if` up to the trailing colon on the line
    private func parseConditionHeader() throws -> String {
        var lineTokens: [Token] = []
        while !isAtEnd {
            let token = peek()
            if case .newline = token.type { break }
            if case .dedent = token.type { break }
            if case .comment = token.type { advance(); continue }
            lineTokens.append(token)
            advance()
        }
        
        guard let colonIndex = lineTokens.lastIndex(where: { $0.type == .colon }) else {
            throw KvParserError.syntaxError(line: peek().line, message: "Expected ':' after if condition")
        }
        let condition = reconstructValue(from: Array(lineTokens[..<colonIndex]))
        guard !condition.isEmpty else {
            throw KvParserError.syntaxError(line: peek().line, message: "Empty if condition")
        }
        return condition
    }
    
    /// Parse the indented body following a conditional header
    private func parseConditionalBranch(keyword: String, line: Int) throws -> KvBody {
        skipNewlines()
        guard case .indent = peek().type else {
            throw KvParserError.syntaxError(line: line, message: "Expected indented block after '\(keyword)'")
        }
        advance()
        
        let body = try parseRuleBody()
        
        if case .dedent = peek().type {
            advance()
        }
        return body
    }
    
    // MARK: - Property Parsing
    
    /// Parse a property: name: value
    private func parseProperty() throws -> KvProperty {
        let startToken = peek()
        guard case .identifier(let name) = startToken.type else {
            throw KvParserError.unexpectedToken(token: startToken, expected: "property name")
        }
        advance()
        
        // Expect :
        guard case .colon = peek().type else {
            throw KvParserError.unexpectedToken(token: peek(), expected: ":")
        }
        advance()
        
        // `name: |` -- the tokenizer has already gathered the block
        if case .block(let code) = peek().type {
            advance()
            return makeProperty(name: name, value: code, isBlock: true, line: startToken.line)
        }
        
        // Collect value tokens until newline
        var valueTokens: [Token] = []
        let valueStartLine = peek().line
        let valueStartColumn = peek().column
        
        while !isAtEnd {
            let token = peek()
            if case .newline = token.type {
                break
            }
            if case .dedent = token.type {
                break
            }
            valueTokens.append(token)
            advance()
        }
        
        // Check for multi-line continuation (NEWLINE followed by INDENT)
        if case .newline = peek().type {
            advance() // consume newline
            
            if case .indent = peek().type {
                advance() // consume indent
                
                // Collect continuation lines. A Python block in a handler
                // indents further still; only the dedent back to the
                // property's own level ends the value.
                var depth = 0
                while !isAtEnd {
                    skipNewlines()
                    
                    let token = peek()
                    if case .dedent = token.type {
                        advance() // consume dedent
                        if depth == 0 { break }
                        depth -= 1
                        continue
                    }
                    if case .indent = token.type {
                        advance()
                        depth += 1
                        continue
                    }
                    
                    // Collect tokens on this continuation line
                    while !isAtEnd {
                        let token = peek()
                        if case .newline = token.type {
                            break
                        }
                        if case .dedent = token.type {
                            break
                        }
                        valueTokens.append(token)
                        advance()
                    }
                }
            }
        }
        
        // Reconstruct value string from tokens
        let value = reconstructValue(from: valueTokens)
        return makeProperty(name: name, value: value, isBlock: false, line: startToken.line)
    }
    
    /// Compile the value for watched keys and, for handlers and blocks,
    /// parse it as Python statements.
    private func makeProperty(name: String, value: String, isBlock: Bool, line: Int) -> KvProperty {
        let compiled = KvCompiler.compile(propertyName: name, value: value)
        
        // Note: Parse may fail if value contains special characters not preserved by tokenization
        // (e.g., semicolons are not tokenized separately)
        let pythonAST: [Statement]? = (isBlock || KvPythonParser.isHandler(name))
            ? KvPythonParser.parseHandler(value)
            : nil
        
        return KvProperty(
            name: name,
            value: value,
            compiledValue: isBlock ? .code(value) : .expression(value),
            watchedKeys: compiled.watchedKeys,
            isBlock: isBlock,
            pythonAST: pythonAST,
            line: line
        )
    }
    
    /// Reconstruct value string from tokens
    private func reconstructValue(from tokens: [Token]) -> String {
        var result = ""
        var needsSpace = false
        
        for token in tokens {
            // Determine if we need a space before this token
            let addSpace = needsSpace && !isDotOrBracket(token)
            if addSpace {
                result += " "
            }
            
            switch token.type {
            case .identifier(let s):
                result += s
                needsSpace = true
            case .string(let s):
                // Preserve quotes for strings
                // Try to detect if original had single or double quotes
                // For now, always use double quotes
                result += "\"\(s)\""
                needsSpace = true
            case .number(let s):
                result += s
                needsSpace = true
            case .comma:
                result += ","
                needsSpace = true
            case .colon:
                result += ":"
                needsSpace = true
            case .dot:
                result += "."
                needsSpace = false  // No space after dot
            case .leftParen, .leftBracket:
                result += token.type == .leftParen ? "(" : "["
                needsSpace = false
            case .rightParen, .rightBracket:
                result += token.type == .rightParen ? ")" : "]"
                needsSpace = true
            case .minus:
                result += "-"
                needsSpace = false
            case .plus:
                result += "+"
                needsSpace = true
            case .leftAngle, .rightAngle:
                // `>=` arrives as `>` then `=`; no space between them
                result += token.type == .leftAngle ? "<" : ">"
                needsSpace = false
            case .at:
                result += "@"
                needsSpace = true
            default:
                break
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// Check if token is a dot, bracket or comma that should connect without space
    private func isDotOrBracket(_ token: Token) -> Bool {
        switch token.type {
        case .dot, .leftBracket, .rightBracket, .comma:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Canvas Instruction Parsing
    
    /// Parse canvas instructions
    private func parseCanvasInstructions() throws -> [KvCanvasInstruction] {
        var instructions: [KvCanvasInstruction] = []
        
        while !isAtEnd {
            skipNewlines()
            
            let token = peek()
            
            // Check for DEDENT
            if case .dedent = token.type {
                break
            }
            
            // Parse instruction
            if case .identifier(let instructionType) = token.type {
                advance()
                
                // Check if there's a colon (instruction with properties) or not (simple command)
                skipNewlines()
                let hasColon = peek().type == .colon
                
                if hasColon {
                    advance() // consume colon
                    skipNewlines()
                }
                
                // Parse instruction properties
                var properties: [KvProperty] = []
                if hasColon, case .indent = peek().type {
                    advance()
                    
                    while !isAtEnd {
                        skipNewlines()
                        
                        if case .dedent = peek().type {
                            advance()
                            break
                        }
                        
                        if case .identifier = peek().type {
                            let property = try parseProperty()
                            properties.append(property)
                        } else {
                            advance()
                        }
                    }
                }
                
                instructions.append(KvCanvasInstruction(
                    instructionType: instructionType,
                    properties: properties,
                    line: token.line
                ))
            } else {
                advance()
            }
        }
        
        return instructions
    }
    
    // MARK: - Helper Methods
    
    internal func peek() -> Token {
        return current < tokens.count ? tokens[current] : Token(type: .eof, line: 0, column: 0)
    }
    
    @discardableResult
    internal func advance() -> Token {
        let token = peek()
        if current < tokens.count {
            current += 1
        }
        return token
    }
    
    internal func skipNewlines() {
        while true {
            let tokenType = peek().type
            if case .newline = tokenType {
                advance()
            } else if case .comment(_) = tokenType {
                advance()
            } else {
                break
            }
        }
    }
    
    private func skipTo(_ index: Int) {
        current = min(index, tokens.count)
    }
    
    internal var isAtEnd: Bool {
        return current >= tokens.count || peek().type == .eof
    }
}
