import Foundation

/// SSH 连接配置
/// 包含建立 SSH 连接所需的所有参数
public struct SSHConfiguration {
    
    // MARK: - 基本连接参数
    
    /// 服务器主机地址
    public let host: String
    
    /// SSH 端口号，默认为 22
    public let port: Int
    
    /// 连接超时时间（秒），默认为 30 秒
    public let connectionTimeout: TimeInterval
    
    /// 数据传输超时时间（秒），默认为 60 秒
    public let dataTimeout: TimeInterval
    
    // MARK: - SSH 协议参数
    
    /// 支持的 SSH 协议版本
    public let protocolVersion: String
    
    /// 客户端标识字符串
    public let clientIdentifier: String
    
    /// 压缩算法配置
    public let compressionEnabled: Bool
    
    /// 保持连接的心跳间隔（秒），0 表示禁用
    public let keepAliveInterval: TimeInterval
    
    // MARK: - 初始化方法
    
    /// 标准初始化方法
    /// - Parameters:
    ///   - host: 服务器主机地址
    ///   - port: SSH 端口号
    ///   - connectionTimeout: 连接超时时间
    ///   - dataTimeout: 数据传输超时时间
    ///   - protocolVersion: SSH 协议版本
    ///   - clientIdentifier: 客户端标识
    ///   - compressionEnabled: 是否启用压缩
    ///   - keepAliveInterval: 心跳间隔
    public init(
        host: String,
        port: Int = 22,
        connectionTimeout: TimeInterval = 30,
        dataTimeout: TimeInterval = 60,
        protocolVersion: String = "2.0",
        clientIdentifier: String = "SSHClient-Swift-1.0",
        compressionEnabled: Bool = false,
        keepAliveInterval: TimeInterval = 0
    ) {
        self.host = host
        self.port = port
        self.connectionTimeout = connectionTimeout
        self.dataTimeout = dataTimeout
        self.protocolVersion = protocolVersion
        self.clientIdentifier = clientIdentifier
        self.compressionEnabled = compressionEnabled
        self.keepAliveInterval = keepAliveInterval
    }
    
    /// 快速创建本地连接配置（用于测试）
    /// - Returns: 连接到 localhost:22 的配置
    public static func localhost() -> SSHConfiguration {
        return SSHConfiguration(host: "127.0.0.1")
    }
    
    /// 快速创建带自定义端口的配置
    /// - Parameters:
    ///   - host: 主机地址
    ///   - port: 端口号
    /// - Returns: SSH 配置实例
    public static func create(host: String, port: Int) -> SSHConfiguration {
        return SSHConfiguration(host: host, port: port)
    }
}

// MARK: - 配置验证扩展

public extension SSHConfiguration {
    
    /// 验证配置的有效性
    /// - Throws: SSHError 当配置无效时抛出异常
    func validate() throws {
        // 验证主机地址
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SSHError.invalidConfiguration("主机地址不能为空")
        }
        
        // 验证端口范围
        guard port > 0 && port <= 65535 else {
            throw SSHError.invalidConfiguration("端口号必须在 1-65535 范围内")
        }
        
        // 验证超时时间
        guard connectionTimeout > 0 else {
            throw SSHError.invalidConfiguration("连接超时时间必须大于 0")
        }
        
        guard dataTimeout > 0 else {
            throw SSHError.invalidConfiguration("数据超时时间必须大于 0")
        }
        
        // 验证心跳间隔
        guard keepAliveInterval >= 0 else {
            throw SSHError.invalidConfiguration("心跳间隔不能为负数")
        }
    }
}

// MARK: - 描述信息扩展

extension SSHConfiguration: CustomStringConvertible {
    
    public var description: String {
        return """
        SSH 配置:
        - 主机: \(host):\(port)
        - 连接超时: \(connectionTimeout)s
        - 数据超时: \(dataTimeout)s
        - 协议版本: SSH-\(protocolVersion)
        - 客户端标识: \(clientIdentifier)
        - 压缩: \(compressionEnabled ? "启用" : "禁用")
        - 心跳间隔: \(keepAliveInterval == 0 ? "禁用" : "\(keepAliveInterval)s")
        """
    }
}

// MARK: - 编码支持

extension SSHConfiguration: Codable {
    
    enum CodingKeys: String, CodingKey {
        case host
        case port
        case connectionTimeout
        case dataTimeout
        case protocolVersion
        case clientIdentifier
        case compressionEnabled
        case keepAliveInterval
    }
} 