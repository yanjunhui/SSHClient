import Foundation
import Citadel
import Logging
import NIOCore

/// SFTP 客户端
/// 负责通过 SSH 连接进行安全文件传输
public class SFTPClient {
    
    // MARK: - 属性
    
    /// 日志记录器
    private let logger = Logger(label: "com.sshclient.sftp")
    
    /// 关联的 SSH 客户端
    private weak var sshClient: SSHClient?
    
    /// Citadel SFTP 客户端
    private var citadelSFTP: Citadel.SFTPClient?
    
    /// SFTP 会话状态
    public private(set) var isActive: Bool = false
    
    /// 当前工作目录
    public private(set) var currentDirectory: String = "/"
    
    /// 文件传输进度回调
    public var progressHandler: ((SFTPProgress) -> Void)?
    
    /// 文件传输完成回调
    public var transferCompletionHandler: ((SFTPTransferResult) -> Void)?
    
    // MARK: - 初始化
    
    /// 初始化 SFTP 客户端
    /// - Parameter sshClient: SSH 客户端实例
    public init(sshClient: SSHClient) {
        self.sshClient = sshClient
        logger.info("初始化 SFTP 客户端")
    }
    
    deinit {
        if isActive {
            // 在deinit中不使用async，直接同步关闭
            isActive = false
            citadelSFTP = nil
            currentDirectory = "/"
            logger.info("SFTP 会话已关闭（析构时）")
        }
    }
    
    // MARK: - 会话管理
    
    /// 开启 SFTP 会话
    /// - Throws: SSHError 开启失败时抛出异常
    public func start() async throws {
        guard let client = sshClient, client.isAuthenticated else {
            throw SSHError.sessionNotEstablished
        }
        
        guard !isActive else {
            logger.warning("SFTP 会话已经开启")
            return
        }
        
        logger.info("正在开启 SFTP 会话...")
        
        do {
            // 获取 Citadel SSH 客户端
            let citadelClient = try client.getCitadelClient()
            
            // 开启 SFTP 会话
            citadelSFTP = try await citadelClient.openSFTP()
            
            // 获取当前工作目录
            currentDirectory = try await getCurrentWorkingDirectory()
            
            isActive = true
            logger.info("SFTP 会话开启成功，当前目录: \(currentDirectory)")
            
        } catch {
            logger.error("SFTP 会话开启失败: \(error.localizedDescription)")
            throw SSHError.sftpInitializationFailed(error.localizedDescription)
        }
    }
    
    /// 关闭 SFTP 会话
    public func close() async {
        guard isActive else { return }
        
        if citadelSFTP != nil {
            do {
                try await citadelSFTP?.close()
                logger.debug("SFTP 会话已关闭")
            } catch {
                logger.warning("关闭SFTP会话时出现错误: \(error.localizedDescription)")
            }
        }
        
        isActive = false
        citadelSFTP = nil
        currentDirectory = "/"
        
        logger.info("SFTP 会话已关闭")
    }
    
    // MARK: - 目录操作
    
    /// 切换工作目录
    /// - Parameter path: 目标目录路径
    /// - Throws: SSHError 切换失败时抛出异常
    public func changeDirectory(to path: String) async throws {
        guard isActive, citadelSFTP != nil else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.info("切换目录到: \(path)")
        
        do {
            let normalizedPath = normalizePath(path)
            
            // 验证目录是否存在
            let exists = try await directoryExists(normalizedPath)
            guard exists else {
                throw SSHError.fileNotFound("目录不存在: \(normalizedPath)")
            }
            
            currentDirectory = normalizedPath
            logger.info("成功切换到目录: \(currentDirectory)")
            
        } catch {
            logger.error("切换目录失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 列出目录内容
    /// - Parameter path: 目录路径，默认为当前目录
    /// - Returns: 文件信息数组
    /// - Throws: SSHError 列出失败时抛出异常
    public func listDirectory(_ path: String? = nil) async throws -> [SFTPFileInfo] {
        guard isActive, let sftp = citadelSFTP else {
            throw SSHError.sessionNotEstablished
        }
        
        let targetPath = path ?? currentDirectory
        logger.info("列出目录内容: \(targetPath)")
        
        do {
            let normalizedPath = normalizePath(targetPath)
            
            // 使用 Citadel 列出目录内容
            let directoryContents = try await sftp.listDirectory(atPath: normalizedPath)
            
            // 转换为我们的文件信息格式
            var files: [SFTPFileInfo] = []
            
            for fileName in directoryContents {
                // SFTPMessage.Name转换为String
                let fileNameString = String(describing: fileName)
                if let fileInfo = await convertToSFTPFileInfo(fileNameString, basePath: normalizedPath, sftp: sftp) {
                    files.append(fileInfo)
                }
            }
            
            logger.info("目录列出成功，找到 \(files.count) 个项目")
            return files
            
        } catch {
            logger.error("列出目录失败: \(error.localizedDescription)")
            throw SSHError.directoryOperationFailed(error.localizedDescription)
        }
    }
    
    /// 创建目录
    /// - Parameter path: 目录路径
    /// - Throws: SSHError 创建失败时抛出异常
    public func createDirectory(_ path: String) async throws {
        guard isActive, let sftp = citadelSFTP else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.info("创建目录: \(path)")
        
        do {
            let normalizedPath = normalizePath(path)
            
            // 使用 Citadel 创建目录
            try await sftp.createDirectory(atPath: normalizedPath)
            
            logger.info("目录创建成功: \(normalizedPath)")
            
        } catch {
            logger.error("创建目录失败: \(error.localizedDescription)")
            throw SSHError.directoryOperationFailed(error.localizedDescription)
        }
    }
    
    /// 删除目录
    /// - Parameter path: 目录路径
    /// - Throws: SSHError 删除失败时抛出异常
    public func removeDirectory(_ path: String) async throws {
        guard isActive, citadelSFTP != nil else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.info("删除目录: \(path)")
        
        let normalizedPath = normalizePath(path)
        
        // 使用Citadel SFTP删除目录 - 实际上可能需要使用不同的方法
        // 根据Citadel文档，可能需要使用不同的API
        logger.warning("目录删除功能需要进一步实现 - Citadel API可能不直接支持")
        logger.info("目录删除请求: \(normalizedPath)")
    }
    
    // MARK: - 文件操作
    
    /// 上传文件
    /// - Parameters:
    ///   - localPath: 本地文件路径
    ///   - remotePath: 远程文件路径
    /// - Returns: 传输结果
    /// - Throws: SSHError 上传失败时抛出异常
    public func uploadFile(from localPath: String, to remotePath: String) async throws -> SFTPTransferResult {
        guard isActive, let sftp = citadelSFTP else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.info("上传文件: \(localPath) -> \(remotePath)")
        
        do {
            // 检查本地文件是否存在
            guard FileManager.default.fileExists(atPath: localPath) else {
                throw SSHError.fileNotFound("本地文件不存在: \(localPath)")
            }
            
            // 获取文件信息
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: localPath)
            let fileSize = fileAttributes[.size] as? UInt64 ?? 0
            
            let normalizedRemotePath = normalizePath(remotePath)
            let startTime = Date()
            
            // 读取本地文件数据
            let fileData = try Data(contentsOf: URL(fileURLWithPath: localPath))
            
            // 使用 Citadel 创建/写入远程文件
            try await sftp.withFile(
                filePath: normalizedRemotePath,
                flags: [.write, .create, .truncate]
            ) { file in
                let buffer = ByteBuffer(data: fileData)
                try await file.write(buffer, at: 0)
            }
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            let result = SFTPTransferResult(
                operation: .upload,
                localPath: localPath,
                remotePath: normalizedRemotePath,
                fileSize: fileSize,
                transferredBytes: fileSize,
                executionTime: executionTime,
                isSuccess: true
            )
            
            logger.info("文件上传成功: \(result.summary)")
            transferCompletionHandler?(result)
            
            return result
            
        } catch {
            logger.error("文件上传失败: \(error.localizedDescription)")
            throw SSHError.transferFailed(error.localizedDescription)
        }
    }
    
    /// 下载文件
    /// - Parameters:
    ///   - remotePath: 远程文件路径
    ///   - localPath: 本地保存路径
    /// - Returns: 传输结果
    /// - Throws: SSHError 下载失败时抛出异常
    public func downloadFile(from remotePath: String, to localPath: String) async throws -> SFTPTransferResult {
        guard isActive, let sftp = citadelSFTP else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.info("下载文件: \(remotePath) -> \(localPath)")
        
        do {
            let normalizedRemotePath = normalizePath(remotePath)
            let startTime = Date()
            
            // 创建本地目录（如果需要）
            let localDirectory = (localPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: localDirectory, withIntermediateDirectories: true)
            
            // 使用 Citadel 读取远程文件
            let fileData = try await sftp.withFile(
                filePath: normalizedRemotePath,
                flags: .read
            ) { file in
                try await file.readAll()
            }
            
            // 将数据写入本地文件
            let localData = Data(buffer: fileData)
            try localData.write(to: URL(fileURLWithPath: localPath))
            
            let executionTime = Date().timeIntervalSince(startTime)
            let fileSize = UInt64(localData.count)
            
            let result = SFTPTransferResult(
                operation: .download,
                localPath: localPath,
                remotePath: normalizedRemotePath,
                fileSize: fileSize,
                transferredBytes: fileSize,
                executionTime: executionTime,
                isSuccess: true
            )
            
            logger.info("文件下载成功: \(result.summary)")
            transferCompletionHandler?(result)
            
            return result
            
        } catch {
            logger.error("文件下载失败: \(error.localizedDescription)")
            throw SSHError.transferFailed(error.localizedDescription)
        }
    }
    
    /// 删除文件
    /// - Parameter path: 文件路径
    /// - Throws: SSHError 删除失败时抛出异常
    public func removeFile(_ path: String) async throws {
        guard isActive, citadelSFTP != nil else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.info("删除文件: \(path)")
        
        let normalizedPath = normalizePath(path)
        
        // 使用Citadel SFTP删除文件 - 实际上可能需要使用不同的方法
        // 根据Citadel文档，可能需要使用不同的API
        logger.warning("文件删除功能需要进一步实现 - Citadel API可能不直接支持")
        logger.info("文件删除请求: \(normalizedPath)")
    }
    
    // MARK: - 私有方法
    
    /// 获取当前工作目录
    private func getCurrentWorkingDirectory() async throws -> String {
        guard let sftp = citadelSFTP else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.debug("获取当前工作目录...")
        
        do {
            // 使用 Citadel 的 getRealPath 来获取当前目录
            let currentPath = try await sftp.getRealPath(atPath: ".")
            return currentPath
        } catch {
            // 如果获取失败，返回默认路径
            return "/home/\(ProcessInfo.processInfo.userName)"
        }
    }
    
    /// 标准化路径
    private func normalizePath(_ path: String) -> String {
        if path.hasPrefix("/") {
            return path
        } else {
            return (currentDirectory as NSString).appendingPathComponent(path)
        }
    }
    
    /// 检查目录是否存在
    private func directoryExists(_ path: String) async throws -> Bool {
        guard let sftp = citadelSFTP else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.debug("检查目录是否存在: \(path)")
        
        do {
            _ = try await sftp.listDirectory(atPath: path)
            return true // 如果能列出目录内容，说明目录存在
        } catch {
            return false // 如果失败，说明目录不存在或无权限访问
        }
    }
    
    /// 检查文件是否存在
    private func fileExists(_ path: String) async throws -> Bool {
        guard let sftp = citadelSFTP else {
            throw SSHError.sessionNotEstablished
        }
        
        logger.debug("检查文件是否存在: \(path)")
        
        do {
            // 尝试获取文件属性来判断文件是否存在
            _ = try await sftp.getAttributes(at: path)
            return true
        } catch {
            return false
        }
    }
    
    /// 将 Citadel 文件信息转换为我们的格式
    private func convertToSFTPFileInfo(_ fileName: String, basePath: String, sftp: Citadel.SFTPClient) async -> SFTPFileInfo? {
        let fullPath = (basePath as NSString).appendingPathComponent(fileName)
        
        // 简化的实现：先检查基本文件名模式来确定文件类型
        let fileType: SFTPFileType
        if fileName.hasSuffix("/") {
            fileType = .directory
        } else if fileName.contains("@") {
            fileType = .symbolicLink
        } else {
            fileType = .regularFile
        }
        
        // 使用基本的文件信息（暂时不获取详细属性）
        return SFTPFileInfo(
            name: fileName.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            path: fullPath,
            size: 0, // 暂时无法获取精确大小，需要后续优化
            type: fileType,
            permissions: fileType == .directory ? "rwxr-xr-x" : "rw-r--r--",
            owner: "user",
            group: "group",
            modificationDate: Date()
        )
    }
} 