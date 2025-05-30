import Foundation

/// SSH 命令执行结果
/// 包含命令执行的完整信息和输出
public struct SSHCommandResult {
    
    // MARK: - 基本信息
    
    /// 执行的命令
    public let command: String
    
    /// 退出代码
    public let exitCode: Int
    
    /// 标准输出
    public let output: String
    
    /// 错误输出
    public let error: String
    
    /// 执行时间（秒）
    public let executionTime: TimeInterval
    
    /// 执行开始时间
    public let startTime: Date
    
    /// 执行结束时间
    public let endTime: Date
    
    // MARK: - 初始化方法
    
    /// 完整初始化方法
    /// - Parameters:
    ///   - command: 执行的命令
    ///   - exitCode: 退出代码
    ///   - output: 标准输出
    ///   - error: 错误输出
    ///   - executionTime: 执行时间
    ///   - startTime: 开始时间
    ///   - endTime: 结束时间
    public init(
        command: String,
        exitCode: Int,
        output: String,
        error: String,
        executionTime: TimeInterval,
        startTime: Date = Date(),
        endTime: Date = Date()
    ) {
        self.command = command
        self.exitCode = exitCode
        self.output = output
        self.error = error
        self.executionTime = executionTime
        self.startTime = startTime
        self.endTime = endTime
    }
    
    /// 简化初始化方法
    /// - Parameters:
    ///   - command: 执行的命令
    ///   - exitCode: 退出代码
    ///   - output: 标准输出
    ///   - error: 错误输出
    ///   - executionTime: 执行时间
    public init(
        command: String,
        exitCode: Int,
        output: String,
        error: String = "",
        executionTime: TimeInterval
    ) {
        let now = Date()
        let start = now.addingTimeInterval(-executionTime)
        
        self.init(
            command: command,
            exitCode: exitCode,
            output: output,
            error: error,
            executionTime: executionTime,
            startTime: start,
            endTime: now
        )
    }
}

// MARK: - 状态判断扩展

public extension SSHCommandResult {
    
    /// 命令是否执行成功
    var isSuccess: Bool {
        return exitCode == 0
    }
    
    /// 是否有输出
    var hasOutput: Bool {
        return !output.isEmpty
    }
    
    /// 是否有错误
    var hasError: Bool {
        return !error.isEmpty || exitCode != 0
    }
    
    /// 获取执行状态描述
    var statusDescription: String {
        if isSuccess {
            return "成功"
        } else {
            return "失败 (退出代码: \(exitCode))"
        }
    }
    
    /// 获取简短的结果描述
    var summary: String {
        let timeStr = String(format: "%.2f", executionTime)
        if isSuccess {
            return "✅ \(command) - 执行成功 (\(timeStr)秒)"
        } else {
            return "❌ \(command) - 执行失败 (\(timeStr)秒, 退出代码: \(exitCode))"
        }
    }
    
    /// 获取输出行数
    var outputLineCount: Int {
        return output.components(separatedBy: .newlines).count - 1
    }
    
    /// 获取错误行数
    var errorLineCount: Int {
        return error.components(separatedBy: .newlines).count - 1
    }
}

// MARK: - 输出处理扩展

public extension SSHCommandResult {
    
    /// 获取输出的行数组
    var outputLines: [String] {
        return output.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
    }
    
    /// 获取错误的行数组
    var errorLines: [String] {
        return error.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
    }
    
    /// 获取第一行输出
    var firstOutputLine: String? {
        return outputLines.first
    }
    
    /// 获取最后一行输出
    var lastOutputLine: String? {
        return outputLines.last
    }
    
    /// 搜索输出中是否包含指定文本
    /// - Parameter text: 要搜索的文本
    /// - Returns: 是否包含该文本
    func containsInOutput(_ text: String) -> Bool {
        return output.localizedCaseInsensitiveContains(text)
    }
    
    /// 搜索错误中是否包含指定文本
    /// - Parameter text: 要搜索的文本
    /// - Returns: 是否包含该文本
    func containsInError(_ text: String) -> Bool {
        return error.localizedCaseInsensitiveContains(text)
    }
    
    /// 使用正则表达式匹配输出
    /// - Parameter pattern: 正则表达式模式
    /// - Returns: 匹配结果数组
    func matchOutput(pattern: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
            return matches.compactMap { match in
                Range(match.range, in: output).map { String(output[$0]) }
            }
        } catch {
            return []
        }
    }
}

// MARK: - 格式化输出扩展

extension SSHCommandResult: CustomStringConvertible {
    
    public var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        
        var result = """
        命令执行结果:
        - 命令: \(command)
        - 状态: \(statusDescription)
        - 执行时间: \(String(format: "%.3f", executionTime))秒
        - 开始时间: \(formatter.string(from: startTime))
        - 结束时间: \(formatter.string(from: endTime))
        """
        
        if hasOutput {
            result += "\n- 输出 (\(outputLineCount) 行):\n\(output)"
        }
        
        if hasError {
            result += "\n- 错误输出 (\(errorLineCount) 行):\n\(error)"
        }
        
        return result
    }
}

// MARK: - JSON 序列化扩展

extension SSHCommandResult: Codable {
    
    enum CodingKeys: String, CodingKey {
        case command, exitCode, output, error
        case executionTime, startTime, endTime
    }
    
    /// 转换为 JSON 字符串
    /// - Returns: JSON 字符串，失败时返回 nil
    public func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    /// 从 JSON 字符串创建实例
    /// - Parameter json: JSON 字符串
    /// - Returns: SSHCommandResult 实例，失败时返回 nil
    public static func fromJSON(_ json: String) -> SSHCommandResult? {
        guard let data = json.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(SSHCommandResult.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - 比较扩展

extension SSHCommandResult: Equatable {
    
    public static func == (lhs: SSHCommandResult, rhs: SSHCommandResult) -> Bool {
        return lhs.command == rhs.command &&
               lhs.exitCode == rhs.exitCode &&
               lhs.output == rhs.output &&
               lhs.error == rhs.error
    }
}

extension SSHCommandResult: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(command)
        hasher.combine(exitCode)
        hasher.combine(output)
        hasher.combine(error)
    }
}

// MARK: - 快捷创建方法

public extension SSHCommandResult {
    
    /// 创建成功结果
    /// - Parameters:
    ///   - command: 命令
    ///   - output: 输出
    ///   - executionTime: 执行时间
    /// - Returns: 成功的命令结果
    static func success(command: String, output: String = "", executionTime: TimeInterval = 0) -> SSHCommandResult {
        return SSHCommandResult(
            command: command,
            exitCode: 0,
            output: output,
            error: "",
            executionTime: executionTime
        )
    }
    
    /// 创建失败结果
    /// - Parameters:
    ///   - command: 命令
    ///   - exitCode: 退出代码
    ///   - output: 标准输出
    ///   - error: 错误输出
    ///   - executionTime: 执行时间
    /// - Returns: 失败的命令结果
    static func failure(
        command: String,
        exitCode: Int = 1,
        output: String = "",
        error: String = "",
        executionTime: TimeInterval = 0
    ) -> SSHCommandResult {
        return SSHCommandResult(
            command: command,
            exitCode: exitCode,
            output: output,
            error: error,
            executionTime: executionTime
        )
    }
} 