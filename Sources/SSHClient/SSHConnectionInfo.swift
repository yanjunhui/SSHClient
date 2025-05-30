import Foundation

/// SSH 连接信息
/// 提供当前连接状态的详细信息
public struct SSHConnectionInfo {
    
    // MARK: - 基本信息
    
    /// 服务器主机地址
    public let host: String
    
    /// 服务器端口号
    public let port: Int
    
    /// 是否已连接
    public let isConnected: Bool
    
    /// 是否已认证
    public let isAuthenticated: Bool
    
    /// 会话标识符
    public let sessionId: String?
    
    /// 连接建立时间
    public let connectionTime: Date?
    
    /// 认证完成时间
    public let authenticationTime: Date?
    
    /// 服务器信息
    public let serverInfo: SSHServerInfo?
    
    // MARK: - 统计信息
    
    /// 发送的字节数
    public let bytesSent: UInt64
    
    /// 接收的字节数
    public let bytesReceived: UInt64
    
    /// 连接持续时间（秒）
    public var connectionDuration: TimeInterval? {
        guard let connectionTime = connectionTime else { return nil }
        return Date().timeIntervalSince(connectionTime)
    }
    
    // MARK: - 初始化方法
    
    /// 标准初始化方法
    /// - Parameters:
    ///   - host: 主机地址
    ///   - port: 端口号
    ///   - isConnected: 连接状态
    ///   - isAuthenticated: 认证状态
    ///   - sessionId: 会话ID
    ///   - connectionTime: 连接时间
    ///   - authenticationTime: 认证时间
    ///   - serverInfo: 服务器信息
    ///   - bytesSent: 发送字节数
    ///   - bytesReceived: 接收字节数
    public init(
        host: String,
        port: Int,
        isConnected: Bool,
        isAuthenticated: Bool,
        sessionId: String? = nil,
        connectionTime: Date? = nil,
        authenticationTime: Date? = nil,
        serverInfo: SSHServerInfo? = nil,
        bytesSent: UInt64 = 0,
        bytesReceived: UInt64 = 0
    ) {
        self.host = host
        self.port = port
        self.isConnected = isConnected
        self.isAuthenticated = isAuthenticated
        self.sessionId = sessionId
        self.connectionTime = connectionTime
        self.authenticationTime = authenticationTime
        self.serverInfo = serverInfo
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
    }
}

/// SSH 服务器信息
public struct SSHServerInfo {
    
    /// 服务器软件版本
    public let serverVersion: String
    
    /// 支持的 SSH 协议版本
    public let protocolVersion: String
    
    /// 服务器标识字符串
    public let serverIdentifier: String
    
    /// 支持的加密算法
    public let supportedCiphers: [String]
    
    /// 支持的 MAC 算法
    public let supportedMACs: [String]
    
    /// 支持的压缩算法
    public let supportedCompressions: [String]
    
    /// 初始化服务器信息
    /// - Parameters:
    ///   - serverVersion: 服务器版本
    ///   - protocolVersion: 协议版本
    ///   - serverIdentifier: 服务器标识
    ///   - supportedCiphers: 支持的加密算法
    ///   - supportedMACs: 支持的 MAC 算法
    ///   - supportedCompressions: 支持的压缩算法
    public init(
        serverVersion: String,
        protocolVersion: String,
        serverIdentifier: String,
        supportedCiphers: [String] = [],
        supportedMACs: [String] = [],
        supportedCompressions: [String] = []
    ) {
        self.serverVersion = serverVersion
        self.protocolVersion = protocolVersion
        self.serverIdentifier = serverIdentifier
        self.supportedCiphers = supportedCiphers
        self.supportedMACs = supportedMACs
        self.supportedCompressions = supportedCompressions
    }
}

// MARK: - 状态判断扩展

public extension SSHConnectionInfo {
    
    /// 连接状态描述
    var statusDescription: String {
        if !isConnected {
            return "未连接"
        } else if !isAuthenticated {
            return "已连接，未认证"
        } else {
            return "已连接并认证"
        }
    }
    
    /// 是否可以执行命令
    var canExecuteCommands: Bool {
        return isConnected && isAuthenticated
    }
    
    /// 是否可以进行文件传输
    var canTransferFiles: Bool {
        return isConnected && isAuthenticated
    }
    
    /// 获取连接质量评分 (0-100)
    var connectionQuality: Int {
        var score = 0
        
        // 基础连接状态
        if isConnected { score += 30 }
        if isAuthenticated { score += 30 }
        
        // 连接稳定性（基于连接时间）
        if let duration = connectionDuration {
            if duration > 60 { score += 20 } // 连接超过1分钟
            else if duration > 10 { score += 10 } // 连接超过10秒
        }
        
        // 数据传输活跃度
        let totalBytes = bytesSent + bytesReceived
        if totalBytes > 1024 { score += 20 } // 有数据传输
        else if totalBytes > 0 { score += 10 } // 少量数据传输
        
        return min(score, 100)
    }
}

// MARK: - 格式化输出扩展

extension SSHConnectionInfo: CustomStringConvertible {
    
    public var description: String {
        var info = """
        SSH 连接信息:
        - 服务器: \(host):\(port)
        - 状态: \(statusDescription)
        - 会话ID: \(sessionId ?? "无")
        """
        
        if let connectionTime = connectionTime {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            info += "\n- 连接时间: \(formatter.string(from: connectionTime))"
        }
        
        if let duration = connectionDuration {
            info += "\n- 连接时长: \(String(format: "%.1f", duration))秒"
        }
        
        if bytesSent > 0 || bytesReceived > 0 {
            info += "\n- 数据传输: 发送 \(formatBytes(bytesSent)), 接收 \(formatBytes(bytesReceived))"
        }
        
        if let serverInfo = serverInfo {
            info += "\n- 服务器版本: \(serverInfo.serverVersion)"
        }
        
        return info
    }
    
    /// 格式化字节数显示
    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        
        let bytesDouble = Double(bytes)
        
        if bytesDouble >= gb {
            return String(format: "%.2f GB", bytesDouble / gb)
        } else if bytesDouble >= mb {
            return String(format: "%.2f MB", bytesDouble / mb)
        } else if bytesDouble >= kb {
            return String(format: "%.2f KB", bytesDouble / kb)
        } else {
            return "\(bytes) B"
        }
    }
}

// MARK: - 编码支持

extension SSHConnectionInfo: Codable {
    
    enum CodingKeys: String, CodingKey {
        case host, port, isConnected, isAuthenticated
        case sessionId, connectionTime, authenticationTime
        case serverInfo, bytesSent, bytesReceived
    }
}

extension SSHServerInfo: Codable {
    
    enum CodingKeys: String, CodingKey {
        case serverVersion, protocolVersion, serverIdentifier
        case supportedCiphers, supportedMACs, supportedCompressions
    }
} 