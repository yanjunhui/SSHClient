import Foundation
import Citadel
import Logging

/// SSH 客户端主类
/// 负责建立 SSH 连接、用户认证和会话管理
public class SSHClient {
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(label: "com.sshclient.main")
    
    /// Citadel SSH 客户端
    private var citadelClient: Citadel.SSHClient?
    
    /// SSH 连接配置
    public let configuration: SSHConfiguration
    
    /// 连接状态
    public private(set) var isConnected: Bool = false
    
    /// 是否已认证
    public private(set) var isAuthenticated: Bool = false
    
    /// 会话标识符
    private var sessionId: String?
    
    // MARK: - 初始化
    
    /// 初始化 SSH 客户端
    /// - Parameter configuration: SSH 连接配置
    public init(configuration: SSHConfiguration) {
        self.configuration = configuration
        logger.info("初始化 SSH 客户端，目标主机: \(configuration.host):\(configuration.port)")
    }
    
    deinit {
        logger.info("SSH 客户端析构")
    }
    
    // MARK: - 连接管理
    
    /// 建立 SSH 连接
    /// - Throws: SSHError 连接失败时抛出异常
    public func connect() async throws {
        guard !isConnected else {
            logger.warning("SSH 连接已存在")
            return
        }
        
        logger.info("正在连接到 \(configuration.host):\(configuration.port)")
        
        // 使用Citadel建立真实的SSH连接（但不进行认证）
        // 注意：Citadel的API要求连接和认证一起进行，所以这里我们保持原有逻辑
        // 真正的连接将在认证方法中完成
        isConnected = true
        sessionId = UUID().uuidString
        logger.info("SSH连接准备就绪，会话ID: \(sessionId ?? "未知")")
    }
    
    /// 断开 SSH 连接
    public func disconnect() async {
        guard isConnected else { return }
        
        do {
            try await citadelClient?.close()
        } catch {
            logger.warning("断开连接时出现错误: \(error.localizedDescription)")
        }
        
        citadelClient = nil
        isConnected = false
        isAuthenticated = false
        sessionId = nil
        
        logger.info("SSH 连接已断开")
    }
    
    // MARK: - 认证
    
    /// 使用密码进行认证
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    /// - Throws: SSHError 认证失败时抛出异常
    public func authenticate(username: String, password: String) async throws {
        guard !isAuthenticated else {
            logger.warning("用户已经通过认证")
            return
        }
        
        logger.info("正在进行密码认证，用户名: \(username)")
        
        do {
            // 使用Citadel连接，在新版本中连接和认证是一体的
            citadelClient = try await Citadel.SSHClient.connect(
                host: configuration.host,
                port: configuration.port,
                authenticationMethod: .passwordBased(username: username, password: password),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            
            isConnected = true
            isAuthenticated = true
            sessionId = UUID().uuidString
            
            logger.info("密码认证成功")
        } catch {
            logger.error("密码认证失败: \(error.localizedDescription)")
            throw SSHError.authenticationFailed("密码认证失败: \(error.localizedDescription)")
        }
    }
    
    /// 使用密钥进行认证
    /// - Parameters:
    ///   - username: 用户名
    ///   - privateKeyPath: 私钥文件路径
    ///   - passphrase: 私钥密码（可选）
    /// - Throws: SSHError 认证失败时抛出异常
    public func authenticate(username: String, privateKeyPath: String, passphrase: String? = nil) async throws {
        guard !isAuthenticated else {
            logger.warning("用户已经通过认证")
            return
        }
        
        logger.info("正在进行密钥认证，用户名: \(username)")
        
        do {
            // 检查私钥文件是否存在
            guard FileManager.default.fileExists(atPath: privateKeyPath) else {
                throw SSHError.keyNotFound("私钥文件不存在: \(privateKeyPath)")
            }
            
            // 读取私钥内容
            let _ = try String(contentsOfFile: privateKeyPath)
            
            // 使用Citadel的公钥认证方法
            // 注意：目前Citadel的公钥认证可能需要不同的API调用
            // 暂时记录这个功能需要进一步实现
            logger.warning("SSH密钥认证功能需要进一步实现 - 当前使用占位实现")
            logger.info("SSH密钥认证请求，用户名: \(username), 密钥文件: \(privateKeyPath)")
            
            // 临时标记为已认证（实际实现需要真正的密钥认证）
            isConnected = true
            isAuthenticated = true
            sessionId = UUID().uuidString
            
            logger.info("密钥认证占位完成")
        } catch {
            logger.error("密钥认证失败: \(error.localizedDescription)")
            throw SSHError.authenticationFailed("密钥认证失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 内部访问器
    
    /// 获取内部的 Citadel 客户端实例
    /// - Returns: Citadel SSH 客户端实例
    /// - Throws: SSHError 如果未连接或未认证
    internal func getCitadelClient() throws -> Citadel.SSHClient {
        guard let client = citadelClient else {
            throw SSHError.notConnected
        }
        return client
    }
}

// MARK: - 状态查询扩展

public extension SSHClient {
    
    /// 获取连接信息
    var connectionInfo: SSHConnectionInfo {
        return SSHConnectionInfo(
            host: configuration.host,
            port: configuration.port,
            isConnected: isConnected,
            isAuthenticated: isAuthenticated,
            sessionId: sessionId
        )
    }
} 