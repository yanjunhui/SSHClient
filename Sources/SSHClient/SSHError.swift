import Foundation

/// SSH 客户端错误类型
/// 定义了所有可能发生的 SSH 操作错误
public enum SSHError: Error, LocalizedError {
    
    // MARK: - 连接相关错误
    
    /// 连接失败
    case connectionFailed(String)
    
    /// 连接超时
    case connectionTimeout
    
    /// 未建立连接
    case notConnected
    
    /// 连接已断开
    case connectionLost
    
    // MARK: - 认证相关错误
    
    /// 认证失败
    case authenticationFailed(String)
    
    /// 认证超时
    case authenticationTimeout
    
    /// 密钥文件未找到
    case keyNotFound(String)
    
    /// 密钥文件无效
    case keyInvalid(String)
    
    /// 密钥密码错误
    case invalidPassphrase
    
    // MARK: - 协议相关错误
    
    /// SSH 协议错误
    case protocolError(String)
    
    /// 不支持的算法
    case unsupportedAlgorithm(String)
    
    /// 数据格式错误
    case invalidData(String)
    
    // MARK: - 会话相关错误
    
    /// 会话未建立
    case sessionNotEstablished
    
    /// 会话已关闭
    case sessionClosed
    
    /// 通道创建失败
    case channelCreationFailed(String)
    
    /// 通道操作失败
    case channelOperationFailed(String)
    
    // MARK: - 命令执行错误
    
    /// 命令执行失败
    case commandExecutionFailed(String)
    
    /// 命令执行超时
    case commandTimeout
    
    /// 无效的命令
    case invalidCommand(String)
    
    // MARK: - 文件传输错误
    
    /// SFTP 初始化失败
    case sftpInitializationFailed(String)
    
    /// 文件未找到
    case fileNotFound(String)
    
    /// 文件访问被拒绝
    case accessDenied(String)
    
    /// 文件传输失败
    case transferFailed(String)
    
    /// 目录操作失败
    case directoryOperationFailed(String)
    
    // MARK: - 配置错误
    
    /// 无效的配置
    case invalidConfiguration(String)
    
    /// 缺少必要参数
    case missingParameter(String)
    
    // MARK: - 系统错误
    
    /// 内存不足
    case outOfMemory
    
    /// 网络不可达
    case networkUnreachable
    
    /// 未知错误
    case unknown(String)
    
    // MARK: - 错误描述
    
    public var errorDescription: String? {
        switch self {
        // 连接相关错误
        case .connectionFailed(let message):
            return "连接失败: \(message)"
        case .connectionTimeout:
            return "连接超时"
        case .notConnected:
            return "尚未建立连接"
        case .connectionLost:
            return "连接已断开"
            
        // 认证相关错误
        case .authenticationFailed(let message):
            return "身份验证失败: \(message)"
        case .authenticationTimeout:
            return "身份验证超时"
        case .keyNotFound(let path):
            return "密钥文件未找到: \(path)"
        case .keyInvalid(let message):
            return "密钥文件无效: \(message)"
        case .invalidPassphrase:
            return "密钥密码错误"
            
        // 协议相关错误
        case .protocolError(let message):
            return "SSH 协议错误: \(message)"
        case .unsupportedAlgorithm(let algorithm):
            return "不支持的算法: \(algorithm)"
        case .invalidData(let message):
            return "数据格式错误: \(message)"
            
        // 会话相关错误
        case .sessionNotEstablished:
            return "会话尚未建立"
        case .sessionClosed:
            return "会话已关闭"
        case .channelCreationFailed(let message):
            return "通道创建失败: \(message)"
        case .channelOperationFailed(let message):
            return "通道操作失败: \(message)"
            
        // 命令执行错误
        case .commandExecutionFailed(let message):
            return "命令执行失败: \(message)"
        case .commandTimeout:
            return "命令执行超时"
        case .invalidCommand(let command):
            return "无效的命令: \(command)"
            
        // 文件传输错误
        case .sftpInitializationFailed(let message):
            return "SFTP 初始化失败: \(message)"
        case .fileNotFound(let path):
            return "文件未找到: \(path)"
        case .accessDenied(let path):
            return "访问被拒绝: \(path)"
        case .transferFailed(let message):
            return "文件传输失败: \(message)"
        case .directoryOperationFailed(let message):
            return "目录操作失败: \(message)"
            
        // 配置错误
        case .invalidConfiguration(let message):
            return "配置无效: \(message)"
        case .missingParameter(let parameter):
            return "缺少必要参数: \(parameter)"
            
        // 系统错误
        case .outOfMemory:
            return "内存不足"
        case .networkUnreachable:
            return "网络不可达"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
    
    /// 错误类型分类
    public var category: SSHErrorCategory {
        switch self {
        case .connectionFailed, .connectionTimeout, .notConnected, .connectionLost:
            return .connection
        case .authenticationFailed, .authenticationTimeout, .keyNotFound, .keyInvalid, .invalidPassphrase:
            return .authentication
        case .protocolError, .unsupportedAlgorithm, .invalidData:
            return .protocol
        case .sessionNotEstablished, .sessionClosed, .channelCreationFailed, .channelOperationFailed:
            return .session
        case .commandExecutionFailed, .commandTimeout, .invalidCommand:
            return .command
        case .sftpInitializationFailed, .fileNotFound, .accessDenied, .transferFailed, .directoryOperationFailed:
            return .fileTransfer
        case .invalidConfiguration, .missingParameter:
            return .configuration
        case .outOfMemory, .networkUnreachable, .unknown:
            return .system
        }
    }
    
    /// 是否为可恢复错误
    public var isRecoverable: Bool {
        switch self {
        case .connectionTimeout, .authenticationTimeout, .commandTimeout, .networkUnreachable:
            return true
        case .connectionLost, .transferFailed:
            return true
        default:
            return false
        }
    }
}

/// SSH 错误类别
public enum SSHErrorCategory: String, CaseIterable {
    case connection = "连接"
    case authentication = "认证"
    case `protocol` = "协议"
    case session = "会话"
    case command = "命令"
    case fileTransfer = "文件传输"
    case configuration = "配置"
    case system = "系统"
}

// MARK: - 错误处理扩展

public extension SSHError {
    
    /// 创建带底层错误信息的 SSH 错误
    /// - Parameters:
    ///   - type: SSH 错误类型
    ///   - underlyingError: 底层错误
    /// - Returns: SSH 错误实例
    static func wrap(_ type: SSHError, underlyingError: Error) -> SSHError {
        switch type {
        case .connectionFailed:
            return .connectionFailed(underlyingError.localizedDescription)
        case .authenticationFailed:
            return .authenticationFailed(underlyingError.localizedDescription)
        case .protocolError:
            return .protocolError(underlyingError.localizedDescription)
        default:
            return .unknown(underlyingError.localizedDescription)
        }
    }
    
    /// 获取错误的建议解决方案
    var suggestion: String {
        switch self {
        case .connectionFailed, .connectionTimeout:
            return "请检查网络连接和服务器地址是否正确"
        case .authenticationFailed, .authenticationTimeout:
            return "请检查用户名和密码是否正确"
        case .keyNotFound, .keyInvalid:
            return "请检查密钥文件路径和格式是否正确"
        case .notConnected:
            return "请先建立 SSH 连接"
        case .sessionNotEstablished:
            return "请先进行身份验证"
        case .commandTimeout:
            return "请检查命令是否需要更长的执行时间"
        case .fileNotFound:
            return "请检查文件路径是否正确"
        case .accessDenied:
            return "请检查文件权限或用户权限"
        default:
            return "请查看详细错误信息并重试"
        }
    }
} 