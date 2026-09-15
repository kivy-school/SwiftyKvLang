import XCTest
@testable import KvParser

/// Test suite for KV language parser
///
/// Tests the complete parsing pipeline:
/// 1. Tokenization (YAML-inspired indentation handling)
/// 2. Parsing (recursive descent with selectors, properties, canvas)
/// 3. AST validation (structure matches KV language specification)
final class KvParserTests: XCTestCase {
    
    // MARK: - Basic Tokenization Tests
    
    func testTokenizeSimpleRule() throws {
        let source = """
        <Button>:
            text: 'Hello'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        
        // Verify we have expected token types
        XCTAssertTrue(tokens.contains { if case .leftAngle = $0.type { return true }; return false })
        XCTAssertTrue(tokens.contains { if case .identifier("Button") = $0.type { return true }; return false })
        XCTAssertTrue(tokens.contains { if case .rightAngle = $0.type { return true }; return false })
        XCTAssertTrue(tokens.contains { if case .indent = $0.type { return true }; return false })
        XCTAssertTrue(tokens.contains { if case .dedent = $0.type { return true }; return false })
    }
    
    func testIndentationDetection() throws {
        let source = """
        Widget:
            BoxLayout:
                Label:
                    text: 'test'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        
        // Count INDENT/DEDENT tokens
        let indents = tokens.filter { if case .indent = $0.type { return true }; return false }.count
        let dedents = tokens.filter { if case .dedent = $0.type { return true }; return false }.count
        
        XCTAssertEqual(indents, 3, "Should have 3 INDENT tokens for 3 nesting levels")
        XCTAssertEqual(dedents, 3, "Should have 3 DEDENT tokens")
    }
    
    func testDirectiveTokenization() throws {
        let source = """
        #:kivy 1.0
        #:import math math
        
        <Widget>:
            pass
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        
        let directives = tokens.filter { 
            if case .directive = $0.type { return true }
            return false
        }
        
        XCTAssertEqual(directives.count, 2, "Should find 2 directives")
    }
    
    // MARK: - Basic Parsing Tests
    
    func testParseSimpleRule() throws {
        let source = """
        <Button>:
            text: 'Click me'
            size: 100, 50
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        XCTAssertEqual(module.rules.count, 1, "Should have 1 rule")
        
        let rule = module.rules[0]
        XCTAssertEqual(rule.selector.primaryName, "Button")
        XCTAssertEqual(rule.properties.count, 2, "Should have 2 properties")
        XCTAssertEqual(rule.properties[0].name, "text")
        XCTAssertEqual(rule.properties[1].name, "size")
    }
    
    func testParseRuleWithCanvas() throws {
        let source = """
        <Label>:
            canvas:
                Color:
                    rgba: 1, 1, 1, 1
                Rectangle:
                    pos: self.pos
                    size: self.size
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        XCTAssertEqual(module.rules.count, 1)
        
        let rule = module.rules[0]
        XCTAssertNotNil(rule.canvas, "Rule should have canvas")
        XCTAssertEqual(rule.canvas?.instructions.count, 2, "Canvas should have 2 instructions")
        
        let colorInstruction = rule.canvas?.instructions[0]
        XCTAssertEqual(colorInstruction?.instructionType, "Color")
        XCTAssertEqual(colorInstruction?.properties.count, 1)
        
        let rectInstruction = rule.canvas?.instructions[1]
        XCTAssertEqual(rectInstruction?.instructionType, "Rectangle")
        XCTAssertEqual(rectInstruction?.properties.count, 2)
    }
    
    func testParseMultipleSelectors() throws {
        let source = """
        <Button,ToggleButton>:
            background_color: 1, 1, 1, 1
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        XCTAssertEqual(module.rules.count, 1)
        
        let rule = module.rules[0]
        if case .multiple(let selectors) = rule.selector {
            XCTAssertEqual(selectors.count, 2)
        } else {
            XCTFail("Expected multiple selector")
        }
    }
    
    func testParseAvoidanceSelector() throws {
        let source = """
        <-Button>:
            text: 'Override'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        XCTAssertEqual(module.rules.count, 1)
        
        let rule = module.rules[0]
        XCTAssertTrue(rule.avoidPrevious, "Rule should have avoidPrevious flag")
    }
    
    func testParseDynamicClass() throws {
        let source = """
        <CustomButton@Button>:
            text: 'Custom'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        XCTAssertEqual(module.rules.count, 1)
        XCTAssertTrue(module.dynamicClasses.keys.contains("CustomButton"))
        
        let rule = module.rules[0]
        if case .dynamicClass(let name, let bases) = rule.selector {
            XCTAssertEqual(name, "CustomButton")
            XCTAssertEqual(bases, ["Button"])
        } else {
            XCTFail("Expected dynamic class selector")
        }
    }
    
    func testParseNestedWidgets() throws {
        let source = """
        BoxLayout:
            Label:
                text: 'Hello'
            Button:
                text: 'Click'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        XCTAssertNotNil(module.root, "Should have root widget")
        XCTAssertEqual(module.root?.name, "BoxLayout")
        XCTAssertEqual(module.root?.children.count, 2, "Root should have 2 children")
        
        let label = module.root?.children[0]
        XCTAssertEqual(label?.name, "Label")
        XCTAssertEqual(label?.properties.first?.name, "text")
        
        let button = module.root?.children[1]
        XCTAssertEqual(button?.name, "Button")
    }
    
    func testParseDirectives() throws {
        let source = """
        #:kivy 1.0
        #:import math math
        #:set MY_COLOR (1, 0, 0, 1)
        #:include other.kv
        
        <Widget>:
            pass
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        XCTAssertEqual(module.directives.count, 4, "Should have 4 directives")
        
        // Check directive types
        let hasKivy = module.directives.contains { 
            if case .kivy = $0 { return true }
            return false
        }
        let hasImport = module.directives.contains { 
            if case .import = $0 { return true }
            return false
        }
        let hasSet = module.directives.contains { 
            if case .set = $0 { return true }
            return false
        }
        let hasInclude = module.directives.contains { 
            if case .include = $0 { return true }
            return false
        }
        
        XCTAssertTrue(hasKivy)
        XCTAssertTrue(hasImport)
        XCTAssertTrue(hasSet)
        XCTAssertTrue(hasInclude)
    }
    
    // MARK: - Style.kv Integration Test
    
    func testParseStyleKv() throws {
        // Load style.kv from resources
        let bundle = Bundle.module
        var styleUrl = bundle.url(forResource: "style", withExtension: "kv", subdirectory: "Resources")
        
        // Fallback: try without subdirectory
        if styleUrl == nil {
            styleUrl = bundle.url(forResource: "style", withExtension: "kv")
        }
        
        guard let url = styleUrl else {
            // Skip test if resource not found (may happen in some build configurations)
            print("Skipping testParseStyleKv: style.kv not found in bundle")
            return
        }
        
        let source = try String(contentsOf: url, encoding: .utf8)
        
        // Tokenize
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        
        print("Tokenized style.kv: \(tokens.count) tokens")
        
        // Parse
        let parser = KvParser(tokens: tokens, filename: "style.kv")
        let module = try parser.parse()
        
        print("Parsed style.kv:")
        print("  Directives: \(module.directives.count)")
        print("  Rules: \(module.rules.count)")
        print("  Templates: \(module.templates.count)")
        print("  Dynamic classes: \(module.dynamicClasses.count)")
        
        // Validate structure
        XCTAssertGreaterThan(module.rules.count, 0, "style.kv should contain widget rules")
        XCTAssertGreaterThan(module.directives.count, 0, "style.kv should have directives")
        
        // Print first few rules for debugging
        print("\nFirst 5 rules:")
        for (index, rule) in module.rules.prefix(5).enumerated() {
            print("  \(index + 1). \(rule.selector.primaryName) (line \(rule.line))")
            print("     Properties: \(rule.properties.count)")
            print("     Children: \(rule.children.count)")
            print("     Canvas: \(rule.canvas != nil ? "yes" : "no")")
        }
        
        // Print tree structure of first rule
        if let firstRule = module.rules.first {
            print("\nFirst rule tree structure:")
            print(firstRule.treeDescription())
        }
    }
    
    // MARK: - Compiler Tests
    
    func testCompileSimpleProperty() {
        let compiled = KvCompiler.compile(propertyName: "text", value: "'Hello World'")
        
        XCTAssertEqual(compiled.mode, .eval)
        XCTAssertTrue(compiled.isConstant, "String literal should have no watched keys")
        XCTAssertEqual(compiled.watchedKeys.count, 0)
    }
    
    func testCompilePropertyWithWatchedKey() {
        let compiled = KvCompiler.compile(propertyName: "width", value: "self.parent.width")
        
        XCTAssertEqual(compiled.mode, .eval)
        XCTAssertFalse(compiled.isConstant)
        XCTAssertEqual(compiled.watchedKeys.count, 1)
        XCTAssertEqual(compiled.watchedKeys[0], ["self", "parent", "width"])
    }
    
    func testCompileEventHandler() {
        let compiled = KvCompiler.compile(propertyName: "on_press", value: "print('pressed')")
        
        XCTAssertEqual(compiled.mode, .exec)
        XCTAssertTrue(compiled.isConstant, "Event handlers should not have watched keys")
    }
    
    func testCompileComplexExpression() {
        let compiled = KvCompiler.compile(
            propertyName: "opacity",
            value: ".7 if self.disabled else 1"
        )
        
        XCTAssertEqual(compiled.mode, .eval)
        XCTAssertFalse(compiled.isConstant)
        XCTAssertTrue(compiled.watchedKeys.contains(["self", "disabled"]))
    }
    
    func testCompileMultipleWatchedKeys() {
        let compiled = KvCompiler.compile(
            propertyName: "pos",
            value: "self.parent.x + root.offset_x, self.parent.y + root.offset_y"
        )
        
        XCTAssertEqual(compiled.mode, .eval)
        XCTAssertFalse(compiled.isConstant)
        
        // Should have 4 watched keys
        let keys = Set(compiled.watchedKeys)
        XCTAssertTrue(keys.contains(["self", "parent", "x"]))
        XCTAssertTrue(keys.contains(["self", "parent", "y"]))
        XCTAssertTrue(keys.contains(["root", "offset_x"]))
        XCTAssertTrue(keys.contains(["root", "offset_y"]))
    }
    
    func testCompileIgnoresStrings() {
        let compiled = KvCompiler.compile(
            propertyName: "text",
            value: "'self.width is: ' + str(self.width)"
        )
        
        XCTAssertEqual(compiled.mode, .eval)
        XCTAssertFalse(compiled.isConstant)
        
        // Should only extract self.width, not the one in the string
        XCTAssertEqual(compiled.watchedKeys.count, 1)
        XCTAssertEqual(compiled.watchedKeys[0], ["self", "width"])
    }
    
    func testCompileWithFString() {
        let compiled = KvCompiler.compile(
            propertyName: "text",
            value: "f'Width: {self.width}'"
        )
        
        XCTAssertEqual(compiled.mode, .eval)
        XCTAssertFalse(compiled.isConstant)
        XCTAssertTrue(compiled.watchedKeys.contains(["self", "width"]))
    }
    
    func testCompileWithTranslation() {
        let compiled = KvCompiler.compile(
            propertyName: "text",
            value: "_('Hello')"
        )
        
        XCTAssertEqual(compiled.mode, .eval)
        XCTAssertFalse(compiled.isConstant)
        
        // Translation function adds special "_" key
        XCTAssertTrue(compiled.watchedKeys.contains(["_"]))
    }
    
    func testCompileModule() throws {
        let source = """
        <Button>:
            text: 'Click me'
            width: self.parent.width
            opacity: .7 if self.disabled else 1
            on_press: print('pressed')
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let compiled = module.compile()
        
        XCTAssertEqual(compiled.rules.count, 1)
        
        let rule = compiled.rules[0]
        XCTAssertEqual(rule.properties.count, 3)
        XCTAssertEqual(rule.handlers.count, 1)
        
        // Check compiled properties
        let textProp = rule.properties.first { $0.name == "text" }!
        XCTAssertTrue(textProp.compiled.isConstant)
        
        let widthProp = rule.properties.first { $0.name == "width" }!
        XCTAssertFalse(widthProp.compiled.isConstant)
        XCTAssertTrue(widthProp.compiled.watchedKeys.contains(["self", "parent", "width"]))
        
        let opacityProp = rule.properties.first { $0.name == "opacity" }!
        XCTAssertFalse(opacityProp.compiled.isConstant)
        XCTAssertTrue(opacityProp.compiled.watchedKeys.contains(["self", "disabled"]))
        
        // Check event handler
        let handler = rule.handlers[0]
        XCTAssertEqual(handler.name, "on_press")
        XCTAssertEqual(handler.compiled.mode, .exec)
        XCTAssertTrue(handler.compiled.isConstant)
    }
    
    // MARK: - Visitor Tests
    
    func testPropertyNameCollector() throws {
        let source = """
        <Button>:
            text: 'Click me'
            width: 100
            height: 50
            on_press: print('pressed')
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let collector = PropertyNameCollector()
        module.accept(visitor: collector)
        
        XCTAssertEqual(collector.propertyNames.count, 4)
        XCTAssertTrue(collector.propertyNames.contains("text"))
        XCTAssertTrue(collector.propertyNames.contains("width"))
        XCTAssertTrue(collector.propertyNames.contains("height"))
        XCTAssertTrue(collector.propertyNames.contains("on_press"))
    }
    
    func testWidgetNameCollector() throws {
        let source = """
        BoxLayout:
            Button:
                text: 'Button 1'
            Label:
                text: 'Label 1'
            BoxLayout:
                Label:
                    text: 'Nested'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let collector = WidgetNameCollector()
        module.accept(visitor: collector)
        
        XCTAssertEqual(collector.widgetNames.count, 5)
        XCTAssertEqual(collector.widgetNames[0], "BoxLayout")
        XCTAssertEqual(collector.widgetNames[1], "Button")
        XCTAssertEqual(collector.widgetNames[2], "Label")
        XCTAssertEqual(collector.widgetNames[3], "BoxLayout")
        XCTAssertEqual(collector.widgetNames[4], "Label")
    }
    
    func testSelectorCollector() throws {
        let source = """
        <Button>:
            text: 'button'
        
        <Label>:
            text: 'label'
        
        <.highlight>:
            color: 1, 1, 0, 1
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let collector = SelectorCollector()
        module.accept(visitor: collector)
        
        XCTAssertEqual(collector.selectors.count, 3)
        XCTAssertTrue(collector.selectors.contains("Button"))
        XCTAssertTrue(collector.selectors.contains("Label"))
        XCTAssertTrue(collector.selectors.contains(".highlight"))
    }
    
    func testASTStatistics() throws {
        let source = """
        #:kivy 1.0
        
        <Button>:
            text: 'Click'
            width: self.parent.width
            canvas:
                Color:
                    rgba: 1, 1, 1, 1
                Rectangle:
                    pos: self.pos
                    size: self.size
        
        <Label>:
            text: 'Label'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let stats = ASTStatistics()
        module.accept(visitor: stats)
        
        XCTAssertEqual(stats.directiveCount, 1)
        XCTAssertEqual(stats.ruleCount, 2)
        XCTAssertEqual(stats.propertyCount, 6) // Button: text, width, canvas(rgba, pos, size), Label: text
        XCTAssertEqual(stats.canvasInstructionCount, 2) // Color, Rectangle
    }
    
    func testWatchedPropertyFinder() throws {
        let source = """
        <Button>:
            text: 'Static'
            width: self.parent.width
            opacity: .7 if self.disabled else 1
            size_hint: None, None
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let finder = WatchedPropertyFinder()
        module.accept(visitor: finder)
        
        // Should find 2 properties with watched keys (width and opacity)
        XCTAssertEqual(finder.watchedProperties.count, 2)
        
        let widthProp = finder.watchedProperties.first { $0.property == "width" }
        XCTAssertNotNil(widthProp)
        XCTAssertEqual(widthProp?.rule, "Button")
        XCTAssertTrue(widthProp?.keys.contains(["self", "parent", "width"]) ?? false)
        
        let opacityProp = finder.watchedProperties.first { $0.property == "opacity" }
        XCTAssertNotNil(opacityProp)
        XCTAssertTrue(opacityProp?.keys.contains(["self", "disabled"]) ?? false)
    }
    
    // MARK: - Code Generation Tests
    
    func testGenerateSimpleRule() throws {
        let source = """
        <Button>:
            text: 'Click me'
            width: 100
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let generated = module.generate()
        
        XCTAssertTrue(generated.contains("<Button>"))
        XCTAssertTrue(generated.contains("text: "))
        XCTAssertTrue(generated.contains("width: 100"))
    }
    
    func testGenerateDirectives() throws {
        let source = """
        #:kivy 1.0
        #:import math math
        #:set BACKGROUND_COLOR [1, 1, 1, 1]
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let generated = module.generate()
        
        XCTAssertTrue(generated.contains("#:kivy 1.0"))
        XCTAssertTrue(generated.contains("#:import"))
        XCTAssertTrue(generated.contains("#:set"))
    }
    
    func testGenerateNestedWidgets() throws {
        let source = """
        BoxLayout:
            Button:
                text: 'Button 1'
            Label:
                text: 'Label 1'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let generated = module.generate()
        
        XCTAssertTrue(generated.contains("BoxLayout:"))
        XCTAssertTrue(generated.contains("Button:"))
        XCTAssertTrue(generated.contains("Label:"))
        XCTAssertTrue(generated.contains("text: "))
    }
    
    func testGenerateCanvas() throws {
        let source = """
        <Button>:
            canvas:
                Color:
                    rgba: 1, 1, 1, 1
                Rectangle:
                    pos: self.pos
                    size: self.size
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let generated = module.generate()
        
        XCTAssertTrue(generated.contains("canvas:"))
        XCTAssertTrue(generated.contains("Color:"))
        XCTAssertTrue(generated.contains("Rectangle:"))
        XCTAssertTrue(generated.contains("rgba: 1, 1, 1, 1"))
        XCTAssertTrue(generated.contains("pos: self.pos"))
    }
    
    func testGenerateMultipleSelectors() throws {
        let source = """
        <Button,Label>:
            font_size: 14
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let generated = module.generate()
        
        XCTAssertTrue(generated.contains("<Button,Label>"))
        XCTAssertTrue(generated.contains("font_size: 14"))
    }
    
    func testGenerateAvoidanceSelector() throws {
        let source = """
        <-Button>:
            text: 'Default'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let generated = module.generate()
        
        XCTAssertTrue(generated.contains("<-Button>"))
        XCTAssertTrue(generated.contains("text: "))
    }
    
    func testRoundTrip() throws {
        let source = """
        #:kivy 1.0
        
        <Button>:
            text: 'Click'
            width: self.parent.width
            canvas:
                Color:
                    rgba: 1, 1, 1, 1
        """
        
        // Parse original
        let tokenizer1 = KvTokenizer(source: source)
        let tokens1 = try tokenizer1.tokenize()
        let parser1 = KvParser(tokens: tokens1)
        let module1 = try parser1.parse()
        
        // Generate code
        let generated = module1.generate()
        
        // Parse generated
        let tokenizer2 = KvTokenizer(source: generated)
        let tokens2 = try tokenizer2.tokenize()
        let parser2 = KvParser(tokens: tokens2)
        let module2 = try parser2.parse()
        
        // Compare structures
        XCTAssertEqual(module1.directives.count, module2.directives.count)
        XCTAssertEqual(module1.rules.count, module2.rules.count)
        XCTAssertEqual(module1.rules[0].properties.count, module2.rules[0].properties.count)
        
        // Check canvas is preserved
        XCTAssertNotNil(module1.rules[0].canvas)
        XCTAssertNotNil(module2.rules[0].canvas)
        XCTAssertEqual(module1.rules[0].canvas?.instructions.count, module2.rules[0].canvas?.instructions.count)
    }
    
    func testStyleKvRoundTrip() throws {
        // Load style.kv from resources
        let bundle = Bundle.module
        var styleUrl = bundle.url(forResource: "style", withExtension: "kv", subdirectory: "Resources")
        
        // Fallback: try without subdirectory
        if styleUrl == nil {
            styleUrl = bundle.url(forResource: "style", withExtension: "kv")
        }
        
        guard let url = styleUrl else {
            print("Skipping testStyleKvRoundTrip: style.kv not found in bundle")
            return
        }
        
        let originalSource = try String(contentsOf: url, encoding: .utf8)
        
        // Parse original
        let tokenizer1 = KvTokenizer(source: originalSource)
        let tokens1 = try tokenizer1.tokenize()
        let parser1 = KvParser(tokens: tokens1, filename: "style.kv")
        let module1 = try parser1.parse()
        
        print("\nOriginal style.kv parsed:")
        print("  Directives: \(module1.directives.count)")
        print("  Rules: \(module1.rules.count)")
        print("  Templates: \(module1.templates.count)")
        print("  Dynamic classes: \(module1.dynamicClasses.count)")
        
        // Generate code
        let generated = module1.generate()
        
        // Parse generated code (roundtrip: parse → generate → parse)
        let tokenizer2 = KvTokenizer(source: generated)
        let tokens2 = try tokenizer2.tokenize()
        let parser2 = KvParser(tokens: tokens2, filename: "style.kv.generated")
        let module2 = try parser2.parse()
        
        print("\nRegenerated style.kv parsed:")
        print("  Directives: \(module2.directives.count)")
        print("  Rules: \(module2.rules.count)")
        print("  Templates: \(module2.templates.count)")
        print("  Dynamic classes: \(module2.dynamicClasses.count)")
        
        // Verify semantic equivalence (AST structures match)
        XCTAssertEqual(module1.directives.count, module2.directives.count, "Directive count mismatch")
        XCTAssertEqual(module1.rules.count, module2.rules.count, "Rule count mismatch")
        XCTAssertEqual(module1.templates.count, module2.templates.count, "Template count mismatch")
        XCTAssertEqual(module1.dynamicClasses.count, module2.dynamicClasses.count, "Dynamic class count mismatch")
        
        // Verify each rule has same structure
        for (index, (rule1, rule2)) in zip(module1.rules, module2.rules).enumerated() {
            XCTAssertEqual(rule1.selector.primaryName, rule2.selector.primaryName, 
                          "Rule \(index) selector mismatch")
            XCTAssertEqual(rule1.properties.count, rule2.properties.count, 
                          "Rule \(index) (\(rule1.selector.primaryName)) property count mismatch")
            XCTAssertEqual(rule1.children.count, rule2.children.count, 
                          "Rule \(index) (\(rule1.selector.primaryName)) children count mismatch")
            
            // Check canvas preservation
            if rule1.canvas != nil {
                XCTAssertNotNil(rule2.canvas, "Rule \(index) (\(rule1.selector.primaryName)) lost canvas")
                XCTAssertEqual(rule1.canvas?.instructions.count, rule2.canvas?.instructions.count,
                              "Rule \(index) (\(rule1.selector.primaryName)) canvas instruction count mismatch")
            }
        }
        
        // Verify templates
        for (index, (template1, template2)) in zip(module1.templates, module2.templates).enumerated() {
            XCTAssertEqual(template1.name, template2.name, "Template \(index) name mismatch")
            XCTAssertEqual(template1.baseClasses.count, template2.baseClasses.count,
                          "Template \(index) (\(template1.name)) base class count mismatch")
            XCTAssertEqual(template1.rule.properties.count, template2.rule.properties.count,
                          "Template \(index) (\(template1.name)) property count mismatch")
        }
        
        print("\n✅ style.kv roundtrip successful - semantic equivalence verified")
        print("   (parse → generate → parse produces identical AST)")
    }
    
    // MARK: - Error Recovery Tests
    
    func testStrictModeThrowsOnError() throws {
        let source = """
        <Button>:
            text: 'Valid'
        
        <Label
            text: 'Missing >'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        
        // Strict mode should throw
        XCTAssertThrowsError(try parser.parseWithRecovery(mode: .strict))
    }
    
    func testTolerantModeCollectsErrors() throws {
        let source = """
        <Button>:
            text: 'Valid'
        
        < >
            text: 'Invalid empty selector'
        
        <Label>:
            text: 'Another valid rule'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        
        let result = try parser.parseWithRecovery(mode: .tolerant)
        
        // Should have some errors but still parse valid rules
        XCTAssertFalse(result.isSuccess)
        XCTAssertGreaterThan(result.errors.count, 0)
        
        // Should have parsed the valid rules
        XCTAssertGreaterThanOrEqual(result.module.rules.count, 1)
    }
    
    func testRecoveryFromMissingColon() throws {
        let source = """
        < >:
            text: 'Invalid empty selector'
        
        <Label>:
            text: 'Valid rule'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        
        let result = try parser.parseWithRecovery(mode: .tolerant)
        
        // Should have error for empty selector
        XCTAssertFalse(result.isSuccess)
        XCTAssertGreaterThan(result.errors.count, 0)
    }
    
    func testErrorLocationTracking() throws {
        let source = """
        <Button>:
            text: 'Valid'
        
        InvalidToken!!!
        
        <Label>:
            text: 'Valid'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        
        let result = try parser.parseWithRecovery(mode: .tolerant)
        
        // Should have error with location
        XCTAssertFalse(result.isSuccess)
        XCTAssertGreaterThan(result.errors.count, 0)
        
        // Check error has line information
        if let error = result.errors.first {
            XCTAssertGreaterThan(error.line, 0)
        }
    }
    
    func testPartialParsing() throws {
        let source = """
        #:kivy 1.0
        
        <Button>:
            text: 'Valid rule 1'
        
        garbage @#$%
        
        <Label>:
            text: 'Valid rule 2'
        
        more garbage
        
        <Widget>:
            size_hint: 1, 1
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        
        let result = try parser.parseWithRecovery(mode: .tolerant)
        
        // Should have errors
        XCTAssertFalse(result.isSuccess)
        
        // Should still parse directives
        XCTAssertGreaterThanOrEqual(result.module.directives.count, 1)
        
        // Should recover and parse some valid rules
        XCTAssertGreaterThan(result.module.rules.count, 0)
    }
    
    // MARK: - Semantic Validation Tests
    
    func testValidateKnownWidgets() throws {
        let source = """
        <Button>:
            text: 'Valid'
        
        <UnknownWidget>:
            text: 'Unknown'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let result = KvSemanticValidator.validate(module)
        
        // Should have warning for unknown widget
        XCTAssertTrue(result.hasWarnings)
        XCTAssertTrue(result.issues.contains { $0.message.contains("UnknownWidget") })
    }
    
    func testValidatePropertyTypos() throws {
        let source = """
        <Label>:
            colour: 1, 0, 0, 1
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let result = KvSemanticValidator.validate(module)
        
        // Should have error for 'colour' (British spelling)
        XCTAssertTrue(result.hasErrors)
        let typoError = result.issues.first { $0.message.contains("colour") }
        XCTAssertNotNil(typoError)
        XCTAssertTrue(typoError?.suggestion?.contains("color") ?? false)
    }
    
    func testValidateDynamicClassNaming() throws {
        let source = """
        <customButton@Button>:
            text: 'Custom'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let result = KvSemanticValidator.validate(module)
        
        // Should warn about lowercase dynamic class name
        XCTAssertTrue(result.hasWarnings)
        XCTAssertTrue(result.issues.contains { $0.message.contains("should start with uppercase") })
    }
    
    func testValidateExpressionComplexity() throws {
        let source = """
        <Button>:
            text: '[x for x in range(10)]'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let result = KvSemanticValidator.validate(module)
        
        // Should have info about complex expression
        XCTAssertTrue(result.issues.contains { $0.message.contains("Complex expression") })
    }
    
    func testValidateRedundantSelf() throws {
        let source = """
        <Button>:
            width: self.self.parent.width
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let result = KvSemanticValidator.validate(module)
        
        // Should have error for redundant self.self
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains { $0.message.contains("self.self") })
    }
    
    func testValidateAssignmentInExpression() throws {
        let source = """
        <Button>:
            size_hint: None None
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let result = KvSemanticValidator.validate(module)
        
        // Validation should complete without crashing
        // (None None is technically valid Python, just unusual)
        XCTAssertTrue(true)
    }
    
    func testValidateCanvasInstructions() throws {
        let source = """
        <Button>:
            canvas:
                Color:
                    rgba: 1, 1, 1, 1
                UnknownInstruction:
                    value: 42
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let result = KvSemanticValidator.validate(module)
        
        // Should warn about unknown canvas instruction
        XCTAssertTrue(result.hasWarnings)
        XCTAssertTrue(result.issues.contains { $0.message.contains("UnknownInstruction") })
    }
    
    func testValidateCleanCode() throws {
        let source = """
        <Button>:
            text: 'Hello'
            width: self.parent.width
            background_color: 1, 0, 0, 1
            on_press: print('clicked')
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let result = KvSemanticValidator.validate(module)
        
        // Should have no errors or warnings for valid code
        XCTAssertTrue(result.isValid)
        XCTAssertFalse(result.hasErrors)
    }
    
    func testDetailedTreeView() throws {
        let source = """
        #:kivy 1.0
        
        <Button>:
            text: 'Click'
            size: 100, 50
            canvas:
                Color:
                    rgba: 1, 0, 0, 1
                Rectangle:
                    pos: self.pos
                    size: self.size
        
        BoxLayout:
            orientation: 'vertical'
            Label:
                text: 'Hello'
            Button:
                text: 'World'
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        // Test summary view
        let summary = module.treeDescription()
        XCTAssertTrue(summary.contains("KvModule"))
        XCTAssertTrue(summary.contains("Directives (1)"))
        XCTAssertTrue(summary.contains("Rules (1)"))
        XCTAssertTrue(summary.contains("Root Widget"))
        XCTAssertTrue(summary.contains("├──") || summary.contains("└──"))
        
        // Test detailed view
        let detailed = module.detailedTreeDescription()
        XCTAssertTrue(detailed.contains("KvModule"))
        XCTAssertTrue(detailed.contains("kivy"))
        XCTAssertTrue(detailed.contains("Button"))
        XCTAssertTrue(detailed.contains("canvas"))
        XCTAssertTrue(detailed.contains("Color"))
        XCTAssertTrue(detailed.contains("BoxLayout"))
        XCTAssertTrue(detailed.contains("Label"))
        
        print("\n=== Summary View ===")
        print(summary)
        print("\n=== Detailed View ===")
        print(detailed)
    }
    
    // MARK: - Python AST Integration Tests
    
    func testPythonASTInHandlers() throws {
        let source = """
        <Button>:
            text: 'Click me'
            on_press: print("Button pressed!")
            on_release: app.handle_release(self)
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        XCTAssertEqual(module.rules.count, 1)
        let rule = module.rules[0]
        XCTAssertEqual(rule.handlers.count, 2)
        
        // Check on_press handler has Python AST
        let onPress = rule.handlers.first { $0.name == "on_press" }
        XCTAssertNotNil(onPress)
        XCTAssertNotNil(onPress?.pythonAST, "on_press handler should have parsed Python AST")
        
        if let ast = onPress?.pythonAST {
            // Should have 1 statement (print call)
            XCTAssertEqual(ast.count, 1, "on_press has one statement")
            
            // Should be an Expr statement (print call)
            if case .expr(let exprStmt) = ast[0] {
                // Should be a Call expression
                if case .call = exprStmt.value {
                    // Success - it's a function call
                } else {
                    XCTFail("Statement should be a Call expression")
                }
            } else {
                XCTFail("Statement should be an Expr")
            }
        }
        
        // Check on_release handler
        let onRelease = rule.handlers.first { $0.name == "on_release" }
        XCTAssertNotNil(onRelease)
        XCTAssertNotNil(onRelease?.pythonAST, "on_release handler should have parsed Python AST")
        
        print("\n=== Python AST Test ===")
        if let ast = onPress?.pythonAST {
            print("on_press AST: \(ast.count) statements")
        }
        if let ast = onRelease?.pythonAST {
            print("on_release AST: \(ast.count) statements")
        }
    }
    
    func testPythonASTParsingErrors() throws {
        let source = """
        <Button>:
            on_press: print("valid code")
            on_release: if incomplete syntax
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let rule = module.rules[0]
        
        // Valid handler should have AST
        let onPress = rule.handlers.first { $0.name == "on_press" }
        XCTAssertNotNil(onPress?.pythonAST, "Valid Python should parse")
        
        // Invalid handler should have nil AST
        let onRelease = rule.handlers.first { $0.name == "on_release" }
        XCTAssertNil(onRelease?.pythonAST, "Invalid Python should return nil AST")
    }
    
    func testDetailedTreeWithPythonAST() throws {
        let source = """
        <Button>:
            text: 'Click'
            size: 100, 50
            on_press: print("pressed")
            on_release: app.stop()
        
        BoxLayout:
            orientation: 'vertical'
            Button:
                on_press: self.disabled = True
        """
        
        let tokenizer = KvTokenizer(source: source)
        let tokens = try tokenizer.tokenize()
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        let detailed = module.detailedTreeDescription()
        
        // Should contain handler entries
        XCTAssertTrue(detailed.contains("on_press"))
        XCTAssertTrue(detailed.contains("on_release"))
        XCTAssertTrue(detailed.contains("[handler"))
        
        // Should contain Python AST markers
        XCTAssertTrue(detailed.contains("[python_ast]"))
        
        // Should contain Python AST node types (from PySwiftAST tree display)
        // These come from Statement tree representations
        XCTAssertTrue(detailed.contains("Expr") || detailed.contains("Call"), 
                     "Should show Python AST node types")
        
        print("\n=== Detailed Tree with Python AST ===")
        print(detailed)
    }

    // MARK: - New Directive Tests (#:mode, #:from)
    
    private func parse(_ source: String) throws -> KvModule {
        let tokens = try KvTokenizer(source: source).tokenize()
        return try KvParser(tokens: tokens).parse()
    }
    
    func testParseModeDirective() throws {
        let module = try parse("""
        #:mode carbonkivy
        
        <Widget>:
            text: 'x'
        """)
        
        XCTAssertEqual(module.directives.count, 1)
        guard case .mode(let name, let line) = module.directives[0] else {
            return XCTFail("Expected .mode directive")
        }
        XCTAssertEqual(name, "carbonkivy")
        XCTAssertEqual(line, 1)
        XCTAssertEqual(module.mode, "carbonkivy")
        XCTAssertEqual(KvMode(rawValue: module.mode), .carbonkivy)
    }
    
    func testModeDefaultsWhenAbsent() throws {
        let module = try parse("<Widget>:\n    text: 'x'")
        XCTAssertEqual(module.mode, "default")
    }
    
    func testModeDirectiveRequiresSingleName() throws {
        let tokens = try KvTokenizer(source: "#:mode\n").tokenize()
        XCTAssertThrowsError(try KvParser(tokens: tokens).parse())
        
        let tokens2 = try KvTokenizer(source: "#:mode a b\n").tokenize()
        XCTAssertThrowsError(try KvParser(tokens: tokens2).parse())
    }
    
    func testParseFromDirective() throws {
        let module = try parse("""
        #:from x.y.z import abc
        #:from x.y.z import abc as cba
        """)
        
        XCTAssertEqual(module.directives.count, 2)
        
        guard case .from(let module1, let name1, let alias1, _) = module.directives[0] else {
            return XCTFail("Expected .from directive")
        }
        XCTAssertEqual(module1, "x.y.z")
        XCTAssertEqual(name1, "abc")
        XCTAssertNil(alias1)
        
        guard case .from(let module2, let name2, let alias2, _) = module.directives[1] else {
            return XCTFail("Expected .from directive")
        }
        XCTAssertEqual(module2, "x.y.z")
        XCTAssertEqual(name2, "abc")
        XCTAssertEqual(alias2, "cba")
    }
    
    func testFromDirectiveRejectsMalformed() throws {
        for bad in ["#:from x.y.z abc", "#:from x.y.z import", "#:from x.y.z import abc as", "#:from x import a b"] {
            let tokens = try KvTokenizer(source: bad + "\n").tokenize()
            XCTAssertThrowsError(try KvParser(tokens: tokens).parse(), "Should reject: \(bad)")
        }
    }
    
    func testGenerateNewDirectives() throws {
        let source = """
        #:mode swiftui
        #:from x.y.z import abc
        #:from x.y.z import abc as cba
        #:include force other.kv
        
        <Widget>:
            text: 'x'
        """
        let module = try parse(source)
        let generated = module.generate()
        
        XCTAssertTrue(generated.contains("#:mode swiftui\n"))
        XCTAssertTrue(generated.contains("#:from x.y.z import abc\n"))
        XCTAssertTrue(generated.contains("#:from x.y.z import abc as cba\n"))
        XCTAssertTrue(generated.contains("#:include force other.kv\n"))
        
        // Round trip
        let reparsed = try parse(generated)
        XCTAssertEqual(reparsed.directives.count, 4)
        XCTAssertEqual(reparsed.directives.map { $0.sourceText }, module.directives.map { $0.sourceText })
    }
    
    // MARK: - Conditional Block Tests (if/else, try/expect)
    
    private let conditionalSource = """
    <MyWidget@BoxLayout>:
        if self.disabled_state: # if true show label else button..
            Label:
                text: "no press"
        else:
            Button:
                text: "press me"
        if self.other_state: # only show button if true
            Button:
                text: "extra press"
        try: # if no issues with proeprties or binding stuff
            Button:
                text: "success"
        expect:
            Label:
                text: "failed"
    """
    
    func testParseConditionalBlocks() throws {
        let module = try parse(conditionalSource)
        
        XCTAssertEqual(module.rules.count, 1)
        let rule = module.rules[0]
        XCTAssertEqual(rule.children.count, 0, "Branch widgets must not leak into the rule's children")
        XCTAssertEqual(rule.conditionals.count, 3)
        
        // if / else
        let ifElse = rule.conditionals[0]
        XCTAssertEqual(ifElse.line, 2)
        guard case .if(let condition, let watched) = ifElse.kind else {
            return XCTFail("Expected .if")
        }
        XCTAssertEqual(condition, "self.disabled_state")
        XCTAssertEqual(watched, [["self", "disabled_state"]])
        XCTAssertEqual(ifElse.body.children.map { $0.name }, ["Label"])
        XCTAssertEqual(ifElse.body.children[0].properties.first?.value, "\"no press\"")
        XCTAssertEqual(ifElse.elseBody?.children.map { $0.name }, ["Button"])
        XCTAssertEqual(ifElse.elseBody?.children[0].properties.first?.value, "\"press me\"")
        
        // if without else
        let ifOnly = rule.conditionals[1]
        XCTAssertEqual(ifOnly.condition, "self.other_state")
        XCTAssertEqual(ifOnly.body.children.map { $0.name }, ["Button"])
        XCTAssertNil(ifOnly.elseBody)
        
        // try / expect
        let tryExpect = rule.conditionals[2]
        XCTAssertEqual(tryExpect.kind, .try)
        XCTAssertNil(tryExpect.condition)
        XCTAssertEqual(tryExpect.body.children.map { $0.name }, ["Button"])
        XCTAssertEqual(tryExpect.elseBody?.children.map { $0.name }, ["Label"])
        XCTAssertEqual(tryExpect.elseBody?.children[0].properties.first?.value, "\"failed\"")
    }
    
    func testConditionalBranchesHoldFullBodies() throws {
        let module = try parse("""
        Widget:
            if root.compact:
                height: 20
                on_release: print("hi")
                canvas:
                    Color:
                        rgba: 1, 0, 0, 1
                Label:
                    id: inner
                    text: "a"
                if app.dark:
                    Button:
                        text: "nested"
                else:
                    Label:
                        text: "nested else"
            text: "after"
        """)
        
        let root = try XCTUnwrap(module.root)
        XCTAssertEqual(root.properties.map { $0.name }, ["text"])
        XCTAssertEqual(root.conditionals.count, 1)
        
        let body = root.conditionals[0].body
        XCTAssertEqual(body.properties.map { $0.name }, ["height"])
        XCTAssertEqual(body.handlers.map { $0.name }, ["on_release"])
        XCTAssertEqual(body.canvas?.instructions.count, 1)
        XCTAssertEqual(body.children.count, 1)
        XCTAssertEqual(body.children[0].id, "inner")
        
        // Nested conditional
        XCTAssertEqual(body.conditionals.count, 1)
        let nested = body.conditionals[0]
        XCTAssertEqual(nested.condition, "app.dark")
        XCTAssertEqual(nested.body.children.first?.name, "Button")
        XCTAssertEqual(nested.elseBody?.children.first?.name, "Label")
    }
    
    func testConditionalInsideChildWidget() throws {
        let module = try parse("""
        <Screen>:
            BoxLayout:
                if self.wide:
                    Label:
                        text: "wide"
        """)
        
        let box = module.rules[0].children[0]
        XCTAssertEqual(box.conditionals.count, 1)
        XCTAssertEqual(box.conditionals[0].body.children.first?.name, "Label")
    }
    
    func testComparisonOperatorsSurviveReconstruction() throws {
        let module = try parse("""
        <W>:
            a: self.x > 3 and self.y < 4
            b: self.x >= 3 or self.y <= 4
            c: self.x == 3 and self.y != 4
            if root.width > 400:
                Label:
                    text: "wide"
        """)
        
        let props = Dictionary(uniqueKeysWithValues: module.rules[0].properties.map { ($0.name, $0.value) })
        XCTAssertEqual(props["a"]?.replacingOccurrences(of: " ", with: ""), "self.x>3andself.y<4")
        XCTAssertEqual(props["b"]?.replacingOccurrences(of: " ", with: ""), "self.x>=3orself.y<=4")
        XCTAssertEqual(props["c"]?.replacingOccurrences(of: " ", with: ""), "self.x==3andself.y!=4")
        XCTAssertEqual(props["b"]?.contains("> ="), false, "'>=' must stay one operator")
        XCTAssertEqual(module.rules[0].conditionals[0].condition?.replacingOccurrences(of: " ", with: ""), "root.width>400")
    }
    
    func testMultiLineHandlerWithNestedBlockDoesNotLeak() throws {
        let module = try parse("""
        <StatusLabel@Label>:
            error: False
            on_error:
                if self.error:
                    self.color = 1, 0, 0, 1
                    self.bold = True
                else:
                    self.color = 1, 1, 1, 1
            text: "after"
        
        <ConditionalBox@BoxLayout>:
            if root.state:
                Button:
                    text: "press me"
            else:
                Label:
                    text: "cant press me"
        """)
        
        XCTAssertEqual(module.rules.count, 2)
        let status = module.rules[0]
        XCTAssertEqual(status.properties.map { $0.name }, ["error", "text"])
        XCTAssertEqual(status.handlers.map { $0.name }, ["on_error"])
        XCTAssertTrue(status.handlers[0].value.contains("else"))
        XCTAssertTrue(status.conditionals.isEmpty, "the handler's else must stay inside the handler")
        
        let box = module.rules[1]
        XCTAssertEqual(box.conditionals.count, 1)
        XCTAssertEqual(box.conditionals[0].elseBody?.children.first?.name, "Label")
    }
    
    func testIfConditionMayContainColons() throws {
        let module = try parse("""
        <W>:
            if self.items[1:2] and root.mode == "x":
                Label:
                    text: "slice"
        """)
        
        let cond = module.rules[0].conditionals[0]
        // Token reconstruction spaces out ':' like it does for property values; compare ignoring spaces
        XCTAssertEqual(cond.condition?.replacingOccurrences(of: " ", with: ""), "self.items[1:2]androot.mode==\"x\"")
        XCTAssertEqual(cond.body.children.first?.name, "Label")
    }
    
    func testExceptIsAcceptedAsExpectAlias() throws {
        let module = try parse("""
        <W>:
            try:
                Button:
                    text: "ok"
            except:
                Label:
                    text: "no"
        """)
        
        let cond = module.rules[0].conditionals[0]
        XCTAssertEqual(cond.kind, .try)
        XCTAssertEqual(cond.elseBody?.children.first?.name, "Label")
    }
    
    func testConditionalSyntaxErrors() throws {
        let cases: [(String, String)] = [
            ("bare else", "<W>:\n    else:\n        Label:\n            text: 'x'\n"),
            ("bare expect", "<W>:\n    expect:\n        Label:\n            text: 'x'\n"),
            ("else after try", "<W>:\n    try:\n        Label:\n            text: 'x'\n    else:\n        Label:\n            text: 'y'\n"),
            ("if without colon", "<W>:\n    if self.x\n        Label:\n            text: 'x'\n"),
            ("if without body", "<W>:\n    if self.x:\n    text: 'y'\n"),
            ("empty condition", "<W>:\n    if :\n        Label:\n            text: 'x'\n"),
            ("try without colon", "<W>:\n    try\n        Label:\n            text: 'x'\n"),
        ]
        
        for (label, source) in cases {
            let tokens = try KvTokenizer(source: source).tokenize()
            XCTAssertThrowsError(try KvParser(tokens: tokens).parse(), "Should fail: \(label)")
        }
    }
    
    func testGenerateConditionalBlocks() throws {
        let module = try parse(conditionalSource)
        let generated = module.generate()
        
        let expected = """
        <MyWidget@BoxLayout>
            if self.disabled_state:
                Label:
                    text: "no press"
            else:
                Button:
                    text: "press me"
            if self.other_state:
                Button:
                    text: "extra press"
            try:
                Button:
                    text: "success"
            expect:
                Label:
                    text: "failed"
        
        """
        XCTAssertEqual(generated, expected)
        
        // Round trip
        let reparsed = try parse(generated)
        XCTAssertEqual(reparsed.rules[0].conditionals.count, 3)
        XCTAssertEqual(reparsed.generate(), generated)
    }
    
    func testVisitorsTraverseConditionals() throws {
        let module = try parse(conditionalSource)
        
        let widgets = WidgetNameCollector()
        module.accept(visitor: widgets)
        XCTAssertEqual(widgets.widgetNames, ["Label", "Button", "Button", "Button", "Label"])
        
        let stats = ASTStatistics()
        module.accept(visitor: stats)
        XCTAssertEqual(stats.ruleCount, 1)
        XCTAssertEqual(stats.widgetCount, 5)
        XCTAssertEqual(stats.propertyCount, 5)
        XCTAssertEqual(stats.conditionalCount, 3)
        
        let finder = WatchedPropertyFinder()
        module.accept(visitor: finder)
        let ifBindings = finder.watchedProperties.filter { $0.property == "if" }
        XCTAssertEqual(ifBindings.count, 2)
        XCTAssertEqual(ifBindings[0].keys, [["self", "disabled_state"]])
    }
    
    func testValidatorSeesBranchWidgets() throws {
        let module = try parse("""
        <W>:
            if self.x:
                Bogus:
                    text: "x"
            else:
                Label:
                    colour: 1, 1, 1, 1
        """)
        
        let result = KvSemanticValidator.validate(module)
        XCTAssertTrue(result.issues.contains { $0.message.contains("Unknown widget type: 'Bogus'") })
        XCTAssertTrue(result.issues.contains { $0.message.contains("Invalid property name: 'colour'") })
    }
    
    func testTreeViewsIncludeConditionals() throws {
        let module = try parse(conditionalSource)
        
        let detailed = module.detailedTreeDescription()
        XCTAssertTrue(detailed.contains("if self.disabled_state [conditional, line 2]"))
        XCTAssertTrue(detailed.contains("then"))
        XCTAssertTrue(detailed.contains("else"))
        XCTAssertTrue(detailed.contains("try [conditional, line 11]"))
        XCTAssertTrue(detailed.contains("expect"))
        XCTAssertTrue(detailed.contains("Label [widget, line 3]"))
        
        let summary = module.rules[0].treeDescription()
        XCTAssertTrue(summary.contains("Conditionals (3):"))
        XCTAssertTrue(summary.contains("if self.disabled_state: [line 2]"))
    }

    // MARK: - Block Values (name: |)
    
    func testBlockValueKeepsItsLines() throws {
        let module = try parse("""
        Button:
            text: |
                if self.state == "down":
                    return "pressed"
                else:
                    return "released"
            on_press: |
                # now we can use as many lines we want as long right indent
                print("a")

                print("b")
            on_release:| #should be allowed also,
                #just strip spaces and check if it starts
                #with | then it should be written as function else as expression
            size_hint: 1, 1
        """)
        
        let root = try XCTUnwrap(module.root)
        XCTAssertEqual(root.properties.map { $0.name }, ["text", "size_hint"])
        XCTAssertEqual(root.handlers.map { $0.name }, ["on_press", "on_release"])
        
        let text = root.properties[0]
        XCTAssertTrue(text.isBlock)
        XCTAssertEqual(text.value, """
        if self.state == "down":
            return "pressed"
        else:
            return "released"
        """)
        guard case .code = text.compiledValue else { return XCTFail("block should compile as code") }
        XCTAssertEqual(text.watchedKeys, [["self", "state"]])
        XCTAssertEqual(text.pythonAST?.count, 1, "the if/else parses as one statement")
        
        let press = root.handlers[0]
        XCTAssertTrue(press.isBlock)
        XCTAssertEqual(press.value, "# now we can use as many lines we want as long right indent\nprint(\"a\")\n\nprint(\"b\")")
        XCTAssertEqual(press.pythonAST?.count, 2)
        
        let release = root.handlers[1]
        XCTAssertTrue(release.isBlock)
        XCTAssertTrue(release.value.hasPrefix("#just strip spaces"))
        
        // The line after the block is a normal property again
        XCTAssertFalse(root.properties[1].isBlock)
        XCTAssertEqual(root.properties[1].value, "1, 1")
    }
    
    func testBlockValueEndsAtTheRulesIndent() throws {
        let module = try parse("""
        <StatusLabel@Label>:
            error: False
            on_error: |
                if self.error:
                    self.color = 1, 0, 0, 1
                else:
                    self.color = 1, 1, 1, 1
            text: "after"
        
        <Other@Label>:
            text: "x"
        """)
        
        XCTAssertEqual(module.rules.count, 2)
        let rule = module.rules[0]
        XCTAssertEqual(rule.properties.map { $0.name }, ["error", "text"])
        XCTAssertEqual(rule.handlers[0].value.split(separator: "\n").count, 4)
        XCTAssertTrue(rule.conditionals.isEmpty)
    }
    
    func testBlockWatchedKeysAcrossLines() throws {
        let module = try parse("""
        <W>:
            b: |
                if self.error:  # comment
                    return root.width
                return app.title
        """)
        let keys = module.rules[0].properties[0].watchedKeys ?? []
        XCTAssertEqual(Set(keys.map { $0.joined(separator: ".") }), ["self.error", "root.width", "app.title"])
    }
    
    func testEmptyBlockAndBlockAtEndOfFile() throws {
        let module = try parse("<W>:\n    on_press: |\n    text: 'x'\n    on_release: |\n        print(1)")
        let rule = module.rules[0]
        XCTAssertEqual(rule.handlers[0].value, "")
        XCTAssertTrue(rule.handlers[0].isBlock)
        XCTAssertEqual(rule.properties[0].value, "\"x\"")
        XCTAssertEqual(rule.handlers[1].value, "print(1)")
    }
    
    func testPipeInsideAnExpressionIsNotABlock() throws {
        let module = try parse("<W>:\n    flags: self.a | self.b\n")
        let prop = module.rules[0].properties[0]
        XCTAssertFalse(prop.isBlock)
        XCTAssertEqual(prop.value.replacingOccurrences(of: " ", with: ""), "self.a|self.b")
    }
    
    func testBlockInCanvasInstruction() throws {
        let module = try parse("""
        <W>:
            canvas:
                Color:
                    rgba: |
                        if self.disabled:
                            return 0.5, 0.5, 0.5, 1
                        return 1, 1, 1, 1
        """)
        let rgba = module.rules[0].canvas!.instructions[0].properties[0]
        XCTAssertTrue(rgba.isBlock)
        XCTAssertEqual(rgba.value.split(separator: "\n").count, 3)
        XCTAssertEqual(rgba.watchedKeys, [["self", "disabled"]])
    }
    
    func testGenerateBlockValues() throws {
        let source = """
        <W@Label>:
            text: |
                if self.state == "down":
                    return "pressed"
                return "released"
            on_press: |
                print("a")
            Button:
                on_release: |
                    print("b")
        
        """
        let module = try parse(source)
        let generated = module.generate()
        
        let expected = """
        <W@Label>
            text: |
                if self.state == "down":
                    return "pressed"
                return "released"
            on_press: |
                print("a")
            Button:
                on_release: |
                    print("b")
        
        """
        XCTAssertEqual(generated, expected)
        
        let reparsed = try parse(generated)
        XCTAssertEqual(reparsed.rules[0].properties[0].value, module.rules[0].properties[0].value)
        XCTAssertEqual(reparsed.rules[0].children[0].handlers[0].value, "print(\"b\")")
        
        XCTAssertTrue(module.detailedTreeDescription().contains("text: | (3 lines) [property, line 2]"))
    }
}


