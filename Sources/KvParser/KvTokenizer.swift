import Foundation

/// Token types for KV language lexical analysis
///
/// Inspired by YAML tokenization but adapted for KV's Python-expression values
/// and widget-specific syntax (angle brackets, canvas keywords, etc.)
public enum TokenType: Equatable, Sendable {
    // Structure tokens (YAML-inspired)
    case indent
    case dedent
    case newline
    
    // Delimiters
    case colon           // : (key-value separator, YAML-style)
    case comma           // , (list separator)
    case leftAngle       // < (rule selector start)
    case rightAngle      // > (rule selector end)
    case leftBracket     // [ (template start)
    case rightBracket    // ] (template end)
    case leftParen       // (
    case rightParen      // )
    case dot             // . (dotted names)
    case minus           // - (avoidance prefix)
    case at              // @ (dynamic class separator)
    case plus            // + (multiple inheritance)
    
    // Literals
    case identifier(String)
    case string(String)
    case number(String)
    
    /// Code block opened by `: |`; the indented lines below, dedented and
    /// joined with newlines. Emitted in place of the value tokens.
    case block(String)
    
    // Special keywords
    case canvas          // canvas, canvas.before, canvas.after
    case canvasBefore    // canvas.before
    case canvasAfter     // canvas.after
    
    // Directives (preprocessor commands)
    case directive(String)  // #:kivy, #:import, etc.
    
    // Comments
    case comment(String)    // # comment (YAML-style, not part of AST)
    
    // End of file
    case eof
}

/// Token with position information
public struct Token: Sendable {
    public let type: TokenType
    public let line: Int
    public let column: Int
    public let length: Int
    
    public init(type: TokenType, line: Int, column: Int, length: Int = 1) {
        self.type = type
        self.line = line
        self.column = column
        self.length = length
    }
}

/// KV language tokenizer
///
/// High-performance UTF-8 byte-level tokenizer inspired by PySwiftAST
/// Uses byte-level scanning for significantly faster tokenization than Character-based approach
/// Handles:
/// - YAML-style indentation (INDENT/DEDENT tokens)
/// - Python-style string literals
/// - KV-specific syntax (selectors, directives)
/// - Dynamic indent size detection (first indent determines spacing)
///
/// Design inspired by YAML parsers (libyaml, PyYAML) and Python tokenizer
/// Reference: parser.py lines 572-777 (parse method and parse_level)
public final class KvTokenizer: Sendable {
    private let source: String
    private let utf8: String.UTF8View
    private let bytes: [UInt8]          // O(1) indexed byte array
    private var position: Int            // Byte index for O(1) access
    private var line: Int = 1
    private var column: Int = 1
    private var indentStack: [Int] = [0]  // YAML-inspired indent tracking
    private var indentSize: Int? = nil     // Detected on first indent
    private var pendingTokens: [Token] = []
    private var atLineStart = true
    private var lastTokenType: TokenType? = nil
    /// Indentation of the line being scanned, for block values
    private var currentLineIndent = 0
    
    public init(source: String) {
        self.source = source
        self.utf8 = source.utf8
        self.bytes = Array(source.utf8)  // Convert to byte array for O(1) access
        self.position = 0
    }
    
    /// Tokenize the source into a list of tokens
    public func tokenize() throws -> [Token] {
        // Pre-allocate capacity (estimate ~7 tokens per line based on style.kv)
        let estimatedTokens = max(100, bytes.count / 7)
        var tokens: [Token] = []
        tokens.reserveCapacity(estimatedTokens)
        
        while true {
            let token = try nextToken()
            tokens.append(token)
            lastTokenType = token.type
            if token.type == .eof {
                break
            }
        }
        
        return tokens
    }
    
    /// Get the next token from the source
    private func nextToken() throws -> Token {
        // Return pending tokens first (DEDENT tokens)
        if !pendingTokens.isEmpty {
            return pendingTokens.removeFirst()
        }
        
        // Handle end of file
        if position >= bytes.count {
            // Emit DEDENT tokens for remaining indentation
            if indentStack.count > 1 {
                indentStack.removeLast()
                return Token(type: .dedent, line: line, column: column)
            }
            return Token(type: .eof, line: line, column: column)
        }
        
        // Handle indentation at start of line
        if atLineStart {
            return try handleIndentation()
        }
        
        skipWhitespace()
        
        if position >= bytes.count {
            return Token(type: .eof, line: line, column: column)
        }
        
        let byte = bytes[position]
        
        // Comments
        if byte == 0x23 { // '#'
            return try scanComment()
        }
        
        // Newlines
        if byte == 0x0A || byte == 0x0D { // '\n' or '\r'
            return scanNewline()
        }
        
        // String literals
        if byte == 0x22 || byte == 0x27 { // '"' or '\''
            return try scanString()
        }
        
        // Code block: `: |` with nothing but a comment after it
        if byte == 0x7C, lastTokenType == .colon, restOfLineIsBlank(after: position + 1) { // '|'
            return scanBlock()
        }
        
        // Numbers
        if isDigit(byte) {
            return scanNumber()
        }
        
        // Names and keywords
        if isNameStart(byte) {
            return scanNameOrKeyword()
        }
        
        // Operators and delimiters
        let token = try? scanOperatorOrDelimiter()
        if let token = token {
            return token
        }
        
        // If we can't recognize the character, treat it as part of an identifier/text
        // This handles special chars in Python expressions (=, !, /, etc.)
        return scanUnknownAsIdentifier()
    }
    
    // MARK: - Helper Methods
    
    private func handleIndentation() throws -> Token {
        atLineStart = false
        
        var indent = 0
        while position < bytes.count {
            let byte = bytes[position]
            if byte == 0x20 { // ' '
                indent += 1
                advance()
            } else if byte == 0x09 { // '\t'
                indent += 4  // Tabs count as 4 spaces (parser.py behavior)
                advance()
            } else {
                break
            }
        }
        
        currentLineIndent = indent
        
        // Skip blank lines and comments
        if position < bytes.count && (bytes[position] == 0x0A || bytes[position] == 0x0D || bytes[position] == 0x23) {
            if bytes[position] == 0x23 { // '#'
                return try scanComment()
            }
            return scanNewline()
        }
        
        // Check if end of file
        if position >= bytes.count {
            if indentStack.count > 1 {
                indentStack.removeLast()
                return Token(type: .dedent, line: line, column: column)
            }
            return Token(type: .eof, line: line, column: column)
        }
        
        // Compare with current indentation level
        let currentIndent = indentStack.last!
        
        if indent > currentIndent {
            // Detect indent size on first indent (YAML-style)
            if indentSize == nil {
                indentSize = indent
            }
            
            // Validate indent is a multiple of indent size
            if let size = indentSize, indent % size != 0 {
                throw KvParserError.invalidIndentation(
                    line: line,
                    message: "Invalid indentation: expected multiple of \(size) spaces, got \(indent)"
                )
            }
            
            indentStack.append(indent)
            return Token(type: .indent, line: line, column: column)
        } else if indent < currentIndent {
            // Generate DEDENT tokens
            while indentStack.count > 1 && indentStack.last! > indent {
                indentStack.removeLast()
                let token = Token(type: .dedent, line: line, column: column)
                
                if indentStack.last! == indent {
                    return token
                } else {
                    pendingTokens.append(token)
                }
            }
            
            if indentStack.last! != indent {
                throw KvParserError.invalidIndentation(
                    line: line,
                    message: "Dedent doesn't match any previous indentation level"
                )
            }
            
            return pendingTokens.removeFirst()
        }
        
        return try nextToken()
    }
    
    private func skipWhitespace() {
        while position < bytes.count {
            let byte = bytes[position]
            if byte == 0x20 || byte == 0x09 { // ' ' or '\t'
                advance()
            } else {
                break
            }
        }
    }
    
    private func scanComment() throws -> Token {
        let startLine = line
        let startColumn = column
        let start = position
        
        advance() // skip '#'
        
        // Check for directive (starts with #:)
        if position < bytes.count && bytes[position] == 0x3A { // ':'
            // Scan entire directive line
            while position < bytes.count && bytes[position] != 0x0A && bytes[position] != 0x0D {
                advance()
            }
            let directiveText = bytesToString(start: start, end: position)
            return Token(type: .directive(directiveText), line: startLine, column: startColumn, length: directiveText.count)
        }
        
        // Regular comment - skip to end of line
        while position < bytes.count && bytes[position] != 0x0A && bytes[position] != 0x0D {
            advance()
        }
        
        let commentText = bytesToString(start: start, end: position)
        return Token(type: .comment(commentText), line: startLine, column: startColumn, length: commentText.count)
    }
    
    /// Only whitespace or a comment between `index` and the end of the line?
    private func restOfLineIsBlank(after index: Int) -> Bool {
        var i = index
        while i < bytes.count {
            let byte = bytes[i]
            if byte == 0x0A || byte == 0x0D || byte == 0x23 { return true } // newline or '#'
            if byte != 0x20 && byte != 0x09 { return false }
            i += 1
        }
        return true
    }
    
    /// Scan the lines under a `|` that are indented past the property's line.
    ///
    /// The block is dedented by the shallowest line and joined with newlines,
    /// so it can be handed to Python as written. Its lines never touch the
    /// indent stack; a NEWLINE is queued so the parser sees the value end.
    private func scanBlock() -> Token {
        let startLine = line
        let startColumn = column
        
        // Rest of the `|` line, comment included
        while position < bytes.count && bytes[position] != 0x0A && bytes[position] != 0x0D {
            advance()
        }
        if position < bytes.count {
            _ = scanNewline()
        }
        
        var lines: [(indent: Int, text: String)] = []
        while position < bytes.count {
            // Measure this line without committing to it
            var i = position
            var indent = 0
            while i < bytes.count && (bytes[i] == 0x20 || bytes[i] == 0x09) {
                indent += bytes[i] == 0x09 ? 4 : 1
                i += 1
            }
            let blank = i >= bytes.count || bytes[i] == 0x0A || bytes[i] == 0x0D
            if !blank && indent <= currentLineIndent { break }
            
            var end = i
            while end < bytes.count && bytes[end] != 0x0A && bytes[end] != 0x0D { end += 1 }
            lines.append((indent: blank ? Int.max : indent, text: bytesToString(start: position, end: end)))
            
            while position < end { advance() }
            if position < bytes.count { _ = scanNewline() }
        }
        
        // Trailing blank lines belong to whatever comes next
        while let last = lines.last, last.indent == Int.max {
            lines.removeLast()
        }
        
        let common = lines.map(\.indent).min() ?? 0
        let text = lines.map { entry -> String in
            guard entry.indent != Int.max else { return "" }
            var dropped = 0
            var rest = Substring(entry.text)
            while dropped < common, let first = rest.first, first == " " || first == "\t" {
                dropped += first == "\t" ? 4 : 1
                rest = rest.dropFirst()
            }
            return String(rest)
        }.joined(separator: "\n")
        
        // The property line has ended; the next line's indentation is
        // handled as usual once the queued NEWLINE is consumed.
        pendingTokens.append(Token(type: .newline, line: startLine, column: startColumn))
        atLineStart = true
        return Token(type: .block(text), line: startLine, column: startColumn, length: 1)
    }
    
    private func scanNewline() -> Token {
        let startLine = line
        let startColumn = column
        
        if bytes[position] == 0x0D { // '\r'
            advance()
            if position < bytes.count && bytes[position] == 0x0A { // '\n'
                advance()
            }
        } else {
            advance()
        }
        
        atLineStart = true
        return Token(type: .newline, line: startLine, column: startColumn)
    }
    
    private func scanString() throws -> Token {
        let startLine = line
        let startColumn = column
        let start = position  // Start includes the opening quote
        let quote = bytes[position]
        advance() // Skip opening quote
        
        let contentStart = position  // Track where content starts (after opening quote)
        
        // Check for triple quotes
        var isTriple = false
        if position < bytes.count && bytes[position] == quote {
            advance()
            if position < bytes.count && bytes[position] == quote {
                advance()
                isTriple = true
            } else {
                // Empty string - return with quotes for full token value
                let fullValue = bytesToString(start: start, end: position)
                return Token(type: .string(""), line: startLine, column: startColumn, length: fullValue.count)
            }
        }
        
        while position < bytes.count {
            let byte = bytes[position]
            
            if byte == 0x5C && !isTriple { // '\\'
                advance()
                if position < bytes.count {
                    advance()
                }
            } else if byte == quote {
                // Found closing quote(s)
                let contentEnd = position  // End of content (before closing quote)
                advance() // Skip closing quote
                
                if isTriple {
                    if position < bytes.count && bytes[position] == quote {
                        advance()
                        if position < bytes.count && bytes[position] == quote {
                            advance()
                            // Extract content without quotes
                            let content = bytesToString(start: contentStart, end: contentEnd)
                            let fullValue = bytesToString(start: start, end: position)
                            return Token(type: .string(content), line: startLine, column: startColumn, length: fullValue.count)
                        }
                    }
                } else {
                    // Extract content without quotes
                    let content = bytesToString(start: contentStart, end: contentEnd)
                    let fullValue = bytesToString(start: start, end: position)
                    return Token(type: .string(content), line: startLine, column: startColumn, length: fullValue.count)
                }
            } else {
                advance()
            }
        }
        
        throw KvParserError.unterminatedString(line: line)
    }
    
    private func scanNumber() -> Token {
        let startLine = line
        let startColumn = column
        let start = position
        
        // Regular number
        while position < bytes.count && (isDigit(bytes[position]) || bytes[position] == 0x5F) { // '_'
            advance()
        }
        
        // Decimal point
        if position < bytes.count && bytes[position] == 0x2E { // '.'
            let nextPos = position + 1
            if nextPos < bytes.count && isDigit(bytes[nextPos]) {
                advance()
                
                while position < bytes.count && (isDigit(bytes[position]) || bytes[position] == 0x5F) { // '_'
                    advance()
                }
            }
        }
        
        let value = bytesToString(start: start, end: position)
        return Token(type: .number(value), line: startLine, column: startColumn, length: value.count)
    }
    
    private func scanNameOrKeyword() -> Token {
        let startLine = line
        let startColumn = column
        let start = position
        
        // First character already validated by isNameStart
        advance()
        
        // Continue with name characters
        while position < bytes.count && isNameContinue(bytes[position]) {
            advance()
        }
        
        let value = bytesToString(start: start, end: position)
        
        // Check for special keywords
        let tokenType: TokenType
        if value == "canvas" {
            tokenType = .canvas
        } else {
            tokenType = .identifier(value)
        }
        
        return Token(type: tokenType, line: startLine, column: startColumn, length: value.count)
    }
    
    private func scanUnknownAsIdentifier() -> Token {
        let startLine = line
        let startColumn = column
        let start = position
        
        // Collect all consecutive unknown characters
        while position < bytes.count {
            let byte = bytes[position]
            // Stop at whitespace, newlines, or recognized delimiters
            if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D || // whitespace/newline
               byte == 0x3A || byte == 0x2C || // : ,
               byte == 0x3C || byte == 0x3E || // < >
               byte == 0x5B || byte == 0x5D || // [ ]
               byte == 0x28 || byte == 0x29 || // ( )
               byte == 0x2E || byte == 0x2D || // . -
               byte == 0x40 || byte == 0x2B || // @ +
               byte == 0x23 || // #
               isNameStart(byte) || isDigit(byte) || byte == 0x22 || byte == 0x27 { // identifiers, numbers, quotes
                break
            }
            advance()
        }
        
        let value = bytesToString(start: start, end: position)
        return Token(type: .identifier(value), line: startLine, column: startColumn, length: value.count)
    }
    
    private func scanOperatorOrDelimiter() throws -> Token {
        let startLine = line
        let startColumn = column
        let byte = bytes[position]
        
        switch byte {
        case 0x3A: // ':'
            advance()
            return Token(type: .colon, line: startLine, column: startColumn)
            
        case 0x2C: // ','
            advance()
            return Token(type: .comma, line: startLine, column: startColumn)
            
        case 0x3C: // '<'
            advance()
            return Token(type: .leftAngle, line: startLine, column: startColumn)
            
        case 0x3E: // '>'
            advance()
            return Token(type: .rightAngle, line: startLine, column: startColumn)
            
        case 0x5B: // '['
            advance()
            return Token(type: .leftBracket, line: startLine, column: startColumn)
            
        case 0x5D: // ']'
            advance()
            return Token(type: .rightBracket, line: startLine, column: startColumn)
            
        case 0x28: // '('
            advance()
            return Token(type: .leftParen, line: startLine, column: startColumn)
            
        case 0x29: // ')'
            advance()
            return Token(type: .rightParen, line: startLine, column: startColumn)
            
        case 0x2E: // '.'
            advance()
            return Token(type: .dot, line: startLine, column: startColumn)
            
        case 0x2D: // '-'
            advance()
            return Token(type: .minus, line: startLine, column: startColumn)
            
        case 0x40: // '@'
            advance()
            return Token(type: .at, line: startLine, column: startColumn)
            
        case 0x2B: // '+'
            advance()
            return Token(type: .plus, line: startLine, column: startColumn)
            
        default:
            // Unrecognized character - caller will handle it
            throw KvParserError.syntaxError(line: line, message: "Unrecognized delimiter")
        }
    }
    
    // MARK: - Utility Methods
    
    @inline(__always)
    private func advance() {
        if position < bytes.count {
            let byte = bytes[position]
            position += 1
            
            // Track line/column for newlines
            if byte == 0x0A { // '\n'
                line += 1
                column = 1
            } else if byte == 0x0D { // '\r'
                line += 1
                column = 1
            } else {
                // For UTF-8: only increment column for ASCII or UTF-8 start bytes
                // Start bytes: 0xxxxxxx (ASCII) or 11xxxxxx (UTF-8 multi-byte start)
                // Continuation bytes: 10xxxxxx (don't increment column)
                if byte < 0x80 || byte >= 0xC0 {
                    column += 1
                }
            }
        }
    }
    
    @inline(__always)
    private func isDigit(_ byte: UInt8) -> Bool {
        return byte >= 0x30 && byte <= 0x39 // '0'...'9'
    }
    
    @inline(__always)
    private func isNameStart(_ byte: UInt8) -> Bool {
        // ASCII: a-z, A-Z, _
        return (byte >= 0x41 && byte <= 0x5A) || // 'A'...'Z'
               (byte >= 0x61 && byte <= 0x7A) || // 'a'...'z'
               byte == 0x5F ||                    // '_'
               byte >= 0x80                       // Non-ASCII (Unicode identifier)
    }
    
    @inline(__always)
    private func isNameContinue(_ byte: UInt8) -> Bool {
        // ASCII: a-z, A-Z, 0-9, _
        return (byte >= 0x41 && byte <= 0x5A) || // 'A'...'Z'
               (byte >= 0x61 && byte <= 0x7A) || // 'a'...'z'
               (byte >= 0x30 && byte <= 0x39) || // '0'...'9'
               byte == 0x5F ||                    // '_'
               byte >= 0x80                       // Non-ASCII (Unicode identifier)
    }
    
    /// Convert byte range to String
    /// Uses UTF-8 decoding for correct character handling
    @inline(__always)
    private func bytesToString(start: Int, end: Int) -> String {
        let slice = bytes[start..<end]
        return String(decoding: slice, as: UTF8.self)
    }
}

/// Parser errors
public enum KvParserError: Error, CustomStringConvertible {
    case invalidIndentation(line: Int, message: String)
    case unterminatedString(line: Int)
    case unexpectedToken(token: Token, expected: String)
    case syntaxError(line: Int, message: String)
    
    public var description: String {
        switch self {
        case .invalidIndentation(let line, let message):
            return "Line \(line): \(message)"
        case .unterminatedString(let line):
            return "Line \(line): Unterminated string literal"
        case .unexpectedToken(let token, let expected):
            return "Line \(token.line): Unexpected token, expected \(expected)"
        case .syntaxError(let line, let message):
            return "Line \(line): \(message)"
        }
    }
}
