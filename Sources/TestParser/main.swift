import Foundation
import KvParser

@main
struct TestParser {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count > 1 else {
            print("Usage: test-parser <file.kv> [--tree] [--generate]")
            return
        }
        
        let filePath = args[1]
        let kvContent = try String(contentsOfFile: filePath, encoding: .utf8)
        
        print("Tokenizing...")
        let tokenizer = KvTokenizer(source: kvContent)
        let tokens = try tokenizer.tokenize()
        
        print("\nToken count: \(tokens.count)")
        print("\nTokens around Labels:")
        for (i, token) in tokens.enumerated() {
            if case .identifier(let name) = token.type, name == "Label" {
                let start = max(0, i - 3)
                let end = min(tokens.count - 1, i + 5)
                for j in start...end {
                    let marker = j == i ? " >>> " : "     "
                    print("\(marker)\(j): \(tokens[j])")
                }
                print()
            }
        }
        
        print("\nParsing...")
        let parser = KvParser(tokens: tokens)
        let module = try parser.parse()
        
        print("✅ Parse successful!")
        print("Rules: \(module.rules.count)")
        if let rule = module.rules.first {
            print("First rule children: \(rule.children.count)")
            for (i, child) in rule.children.enumerated() {
                print("  Child \(i): \(child.name) at line \(child.line)")
            }
        }
        print("Root widget: \(module.root?.name ?? "none")")
        print("Mode: \(module.mode)")
        
        if args.contains("--tree") {
            print()
            print(module.detailedTreeDescription())
        }
        if args.contains("--generate") {
            print()
            print(module.generate())
        }
    }
}
