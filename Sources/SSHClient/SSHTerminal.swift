import Foundation
import Citadel
import Logging
import NIOCore

/// SSH 终端会话
/// 负责交互式终端命令的执行和管理
public class SSHTerminal {
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(label: "com.sshclient.terminal")
    
    /// 关联的 SSH 客户端
    private weak var sshClient: SSHClient?
    
    /// 终端状态
    public private(set) var isActive: Bool = false
    
    /// 终端环境变量
    public var environment: [String: String] = [:]
    
    /// 终端尺寸
    public var terminalSize: TerminalSize = TerminalSize()
    
    /// 输出回调
    public var outputHandler: ((String) -> Void)?
    
    /// 错误输出回调
    public var errorHandler: ((String) -> Void)?
    
    /// 命令执行回调
    public var commandCompletionHandler: ((SSHCommandResult) -> Void)?
    
    // MARK: - 初始化
    
    /// 初始化 SSH 终端
    /// - Parameter sshClient: SSH 客户端实例
    public init(sshClient: SSHClient) {
        self.sshClient = sshClient
        logger.info("初始化 SSH 终端")
    }
    
    deinit {
        if isActive {
            // 在deinit中不使用async，直接同步关闭
            isActive = false
            logger.info("终端会话已关闭（析构时）")
        }
    }
    
    // MARK: - 终端管理
    
    /// 开启终端会话
    /// - Throws: SSHError 开启失败时抛出异常
    public func start() async throws {
        guard let client = sshClient, client.isAuthenticated else {
            throw SSHError.sessionNotEstablished
        }
        
        guard !isActive else {
            logger.warning("终端会话已经开启")
            return
        }
        
        logger.info("正在开启终端会话...")
        isActive = true
        logger.info("终端会话开启成功")
    }
    
    /// 关闭终端会话
    public func close() async {
        guard isActive else { return }
        
        isActive = false
        logger.info("终端会话已关闭")
    }
    
    // MARK: - 命令执行
    
    /// 执行命令
    /// - Parameter command: 要执行的命令
    /// - Returns: 命令执行结果
    /// - Throws: SSHError 执行失败时抛出异常
    public func executeCommand(_ command: String) async throws -> SSHCommandResult {
        guard isActive else {
            throw SSHError.sessionNotEstablished
        }
        
        guard let client = sshClient else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.info("执行命令: \(command)")
        
        do {
            let citadelClient = try client.getCitadelClient()
            let startTime = Date()
            
            // 使用 Citadel 执行命令
            let output = try await citadelClient.executeCommand(command)
            let executionTime = Date().timeIntervalSince(startTime)
            
            // 转换输出为字符串
            let outputString = String(buffer: output)
            
            let result = SSHCommandResult(
                command: command,
                exitCode: 0, // Citadel的executeCommand成功时默认为0
                output: outputString,
                error: "", // executeCommand合并了stdout和stderr
                executionTime: executionTime
            )
            
            logger.info("命令执行成功: \(result.summary)")
            
            // 调用回调
            outputHandler?(outputString)
            commandCompletionHandler?(result)
            
            return result
            
        } catch {
            logger.error("命令执行失败: \(error.localizedDescription)")
            
            let result = SSHCommandResult(
                command: command,
                exitCode: -1,
                output: "",
                error: error.localizedDescription,
                executionTime: 0
            )
            
            errorHandler?(error.localizedDescription)
            commandCompletionHandler?(result)
            
            throw SSHError.commandExecutionFailed(error.localizedDescription)
        }
    }
    
    /// 执行命令并分离stdout和stderr
    /// - Parameter command: 要执行的命令
    /// - Returns: 命令执行结果
    /// - Throws: SSHError 执行失败时抛出异常
    public func executeCommandSeparated(_ command: String) async throws -> SSHCommandResult {
        guard isActive else {
            throw SSHError.sessionNotEstablished
        }
        
        guard let client = sshClient else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.info("执行命令（分离输出）: \(command)")
        
        do {
            let citadelClient = try client.getCitadelClient()
            let startTime = Date()
            
            // 使用 Citadel 执行命令，获取分离的stdout和stderr
            let streams = try await citadelClient.executeCommandPair(command)
            
            var stdout = ""
            var stderr = ""
            
            // 读取 stdout
            for try await chunk in streams.stdout {
                stdout += String(buffer: chunk)
            }
            
            // 读取 stderr
            for try await chunk in streams.stderr {
                stderr += String(buffer: chunk)
            }
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            let result = SSHCommandResult(
                command: command,
                exitCode: stderr.isEmpty ? 0 : 1,
                output: stdout,
                error: stderr,
                executionTime: executionTime
            )
            
            logger.info("命令执行完成: \(result.summary)")
            
            // 调用回调
            if !stdout.isEmpty {
                outputHandler?(stdout)
            }
            if !stderr.isEmpty {
                errorHandler?(stderr)
            }
            commandCompletionHandler?(result)
            
            return result
            
        } catch {
            logger.error("命令执行失败: \(error.localizedDescription)")
            
            let result = SSHCommandResult(
                command: command,
                exitCode: -1,
                output: "",
                error: error.localizedDescription,
                executionTime: 0
            )
            
            errorHandler?(error.localizedDescription)
            commandCompletionHandler?(result)
            
            throw SSHError.commandExecutionFailed(error.localizedDescription)
        }
    }
    
    /// 执行长时间运行的命令（流式输出）
    /// - Parameter command: 要执行的命令
    /// - Returns: AsyncThrowingStream 流式输出
    public func executeCommandStream(_ command: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let client = sshClient else {
                        continuation.finish(throwing: SSHError.sessionNotEstablished)
                        return
                    }
                    
                    let citadelClient = try client.getCitadelClient()
                    
                    // 使用 Citadel 的流式命令执行
                    let streams = try await citadelClient.executeCommandStream(command)
                    
                    for try await event in streams {
                        switch event {
                        case .stdout(let stdout):
                            let output = String(buffer: stdout)
                            continuation.yield(output)
                            outputHandler?(output)
                        case .stderr(let stderr):
                            let error = String(buffer: stderr)
                            continuation.yield(error)
                            errorHandler?(error)
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    logger.error("流式命令执行失败: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - 终端辅助类型

/// 终端尺寸
public struct TerminalSize {
    public var width: UInt32 = 80
    public var height: UInt32 = 24
    public var pixelWidth: UInt32 = 0
    public var pixelHeight: UInt32 = 0
    
    public init(width: UInt32 = 80, height: UInt32 = 24, pixelWidth: UInt32 = 0, pixelHeight: UInt32 = 0) {
        self.width = width
        self.height = height
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

/// 特殊按键
public enum SpecialKey: String, CaseIterable {
    case enter = "\r"
    case tab = "\t"
    case escape = "\u{1B}"
    case backspace = "\u{7F}"
    case delete = "\u{1B}[3~"
    case arrowUp = "\u{1B}[A"
    case arrowDown = "\u{1B}[B"
    case arrowRight = "\u{1B}[C"
    case arrowLeft = "\u{1B}[D"
    case home = "\u{1B}[H"
    case end = "\u{1B}[F"
    case pageUp = "\u{1B}[5~"
    case pageDown = "\u{1B}[6~"
    case ctrlC = "\u{3}"
    case ctrlD = "\u{4}"
    case ctrlZ = "\u{1A}"
    
    /// 转义序列
    public var escapeSequence: String {
        return self.rawValue
    }
} 