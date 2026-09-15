/// Root module representing a complete KV file
///
/// Corresponds to Parser class in parser.py, containing:
/// - directives: Preprocessor commands (#:kivy, #:import, etc.)
/// - rules: Widget class rules with selectors (<Button>, <.className>, etc.)
/// - templates: Dynamic class templates ([Name@Base])
/// - root: Optional root widget instance (widget without <>)
/// - dynamicClasses: Dynamic class definitions created with @ syntax
///
/// Reference: parser.py lines 468-498
public struct KvModule: KvNode, Sendable {
    public let directives: [KvDirective]
    public let rules: [KvRule]
    public let templates: [KvTemplate]
    public let root: KvWidget?
    public let dynamicClasses: [String: String]  // class name -> base classes
    
    // Position tracking
    public let line: Int
    public let column: Int
    public let endLine: Int?
    public let endColumn: Int?
    
    public init(
        directives: [KvDirective] = [],
        rules: [KvRule] = [],
        templates: [KvTemplate] = [],
        root: KvWidget? = nil,
        dynamicClasses: [String: String] = [:],
        line: Int = 1,
        column: Int = 0,
        endLine: Int? = nil,
        endColumn: Int? = nil
    ) {
        self.directives = directives
        self.rules = rules
        self.templates = templates
        self.root = root
        self.dynamicClasses = dynamicClasses
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
    }
    
    /// Generator mode from the last #:mode directive ("default" when absent)
    public var mode: String {
        for directive in directives.reversed() {
            if case .mode(let name, _) = directive { return name }
        }
        return KvMode.default.rawValue
    }
}

extension KvModule: TreeDisplayable {
    /// Generate tree description (summary mode by default)
    public func treeDescription(indent: Int = 0) -> String {
        return summaryTreeDescription()
    }
    
    /// Generate detailed tree with full AST traversal
    public func detailedTreeDescription() -> String {
        return detailedTreeDescriptionInternal(depth: 0, parentBranches: [])
    }
    
    /// Summary view (default) - shows counts and top-level items
    private func summaryTreeDescription() -> String {
        var result = "KvModule\n"
        
        struct Section {
            let name: String
            let items: [String]
        }
        
        var sections: [Section] = []
        
        // Collect directives
        if !directives.isEmpty {
            var items: [String] = []
            for directive in directives {
                switch directive {
                case .kivy(let version, _):
                    items.append("kivy \(version)")
                case .import(let alias, let package, _):
                    items.append("import \(package) as \(alias)")
                case .from(let module, let name, let alias, _):
                    let aliasStr = alias.map { " as \($0)" } ?? ""
                    items.append("from \(module) import \(name)\(aliasStr)")
                case .set(let name, let value, _):
                    items.append("set \(name) = \(value)")
                case .include(let path, let force, _):
                    let forceStr = force ? " [force]" : ""
                    items.append("include\(forceStr) \(path)")
                case .mode(let name, _):
                    items.append("mode \(name)")
                }
            }
            sections.append(Section(
                name: "Directives (\(directives.count))",
                items: items
            ))
        }
        
        // Collect rules
        if !rules.isEmpty {
            let items = rules.map { rule -> String in
                let avoid = rule.avoidPrevious ? "-" : ""
                return "<\(avoid)\(rule.selector.primaryName)> (\(rule.properties.count) props, \(rule.children.count) children)"
            }
            sections.append(Section(
                name: "Rules (\(rules.count))",
                items: items
            ))
        }
        
        // Collect templates
        if !templates.isEmpty {
            let items = templates.map { "[\($0.name)@\($0.baseClasses.joined(separator: "+"))]" }
            sections.append(Section(
                name: "Templates (\(templates.count))",
                items: items
            ))
        }
        
        // Collect root widget
        if let root = root {
            sections.append(Section(
                name: "Root Widget",
                items: ["\(root.name) (\(root.children.count) children)"]
            ))
        }
        
        // Collect dynamic classes
        if !dynamicClasses.isEmpty {
            sections.append(Section(
                name: "Dynamic Classes (\(dynamicClasses.count))",
                items: Array(dynamicClasses.keys).sorted()
            ))
        }
        
        // Format with tree characters
        for (sectionIndex, section) in sections.enumerated() {
            let isLastSection = sectionIndex == sections.count - 1
            let sectionPrefix = isLastSection ? "└── " : "├── "
            result += "\(sectionPrefix)\(section.name)\n"
            
            for (itemIndex, item) in section.items.enumerated() {
                let isLastItem = itemIndex == section.items.count - 1
                let continuation = isLastSection ? "    " : "│   "
                let itemPrefix = isLastItem ? "└── " : "├── "
                result += "\(continuation)\(itemPrefix)\(item)\n"
            }
        }
        
        return result
    }
    
    /// Detailed view - shows full AST tree with all nested nodes
    private func detailedTreeDescriptionInternal(depth: Int, parentBranches: [Bool]) -> String {
        var result = depth == 0 ? "KvModule\n" : ""
        
        enum Item {
            case directive(String)
            case rule(String, KvRule)
            case template(String, KvRule)
            case rootWidget(String, KvWidget)
        }
        
        var allItems: [Item] = []
        
        // Add directives
        for directive in directives {
            allItems.append(.directive(directive.sourceText))
        }
        
        // Add rules with full tree - content should be nested under rule name
        for rule in rules {
            let avoid = rule.avoidPrevious ? "-" : ""
            let name = "<\(avoid)\(rule.selector.primaryName)> [rule, line \(rule.line)]"
            allItems.append(.rule(name, rule))
        }
        
        // Add templates
        for template in templates {
            let name = "[\(template.name)@\(template.baseClasses.joined(separator: "+"))] [template, line \(template.line)]"
            allItems.append(.template(name, template.rule))
        }
        
        // Add root widget tree
        if let root = root {
            let name = "\(root.name) [root, line \(root.line)]\(root.id != nil ? ", id: \(root.id!)" : "")"
            allItems.append(.rootWidget(name, root))
        }
        
        // Format with tree characters
        let totalItems = allItems.count
        for (index, item) in allItems.enumerated() {
            let isLast = index == totalItems - 1
            let prefix = TreeFormatter.prefix(depth: depth + 1, isLast: isLast, parentBranches: parentBranches)
            
            switch item {
            case .directive(let name):
                result += "\(prefix)\(name)\n"
            case .rule(let name, let rule):
                result += "\(prefix)\(name)\n"
                result += rule.detailedContent(depth: depth + 2, parentBranches: parentBranches + [!isLast])
            case .template(let name, let rule):
                result += "\(prefix)\(name)\n"
                result += rule.detailedContent(depth: depth + 2, parentBranches: parentBranches + [!isLast])
            case .rootWidget(let name, let widget):
                result += "\(prefix)\(name)\n"
                result += widget.detailedContent(depth: depth + 2, parentBranches: parentBranches + [!isLast])
            }
        }
        
        return result
    }
}
