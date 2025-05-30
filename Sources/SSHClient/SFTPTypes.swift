import Foundation

// MARK: - SFTP 文件信息

/// SFTP 文件信息
/// 描述远程文件或目录的详细信息
public struct SFTPFileInfo {
    
    /// 文件名
    public let name: String
    
    /// 完整路径
    public let path: String
    
    /// 文件大小（字节）
    public let size: UInt64
    
    /// 文件类型
    public let type: SFTPFileType
    
    /// 权限字符串（例如：rw-r--r--）
    public let permissions: String
    
    /// 所有者
    public let owner: String
    
    /// 所属组
    public let group: String
    
    /// 修改时间
    public let modificationDate: Date
    
    /// 访问时间
    public let accessDate: Date?
    
    /// 创建时间
    public let creationDate: Date?
    
    // MARK: - 初始化方法
    
    /// 完整初始化方法
    /// - Parameters:
    ///   - name: 文件名
    ///   - path: 完整路径
    ///   - size: 文件大小
    ///   - type: 文件类型
    ///   - permissions: 权限字符串
    ///   - owner: 所有者
    ///   - group: 所属组
    ///   - modificationDate: 修改时间
    ///   - accessDate: 访问时间
    ///   - creationDate: 创建时间
    public init(
        name: String,
        path: String,
        size: UInt64,
        type: SFTPFileType,
        permissions: String = "rw-r--r--",
        owner: String = "user",
        group: String = "user",
        modificationDate: Date = Date(),
        accessDate: Date? = nil,
        creationDate: Date? = nil
    ) {
        self.name = name
        self.path = path
        self.size = size
        self.type = type
        self.permissions = permissions
        self.owner = owner
        self.group = group
        self.modificationDate = modificationDate
        self.accessDate = accessDate
        self.creationDate = creationDate
    }
}

// MARK: - 文件类型

/// SFTP 文件类型
public enum SFTPFileType: String, CaseIterable, Codable {
    case regularFile = "file"       // 普通文件
    case directory = "directory"    // 目录
    case symbolicLink = "symlink"   // 符号链接
    case blockDevice = "block"      // 块设备
    case characterDevice = "char"   // 字符设备
    case fifo = "fifo"             // FIFO 管道
    case socket = "socket"         // Socket 文件
    case unknown = "unknown"       // 未知类型
    
    /// 文件类型的中文描述
    public var description: String {
        switch self {
        case .regularFile:
            return "文件"
        case .directory:
            return "目录"
        case .symbolicLink:
            return "符号链接"
        case .blockDevice:
            return "块设备"
        case .characterDevice:
            return "字符设备"
        case .fifo:
            return "管道"
        case .socket:
            return "套接字"
        case .unknown:
            return "未知"
        }
    }
    
    /// 文件类型图标
    public var icon: String {
        switch self {
        case .regularFile:
            return "📄"
        case .directory:
            return "📁"
        case .symbolicLink:
            return "🔗"
        case .blockDevice, .characterDevice:
            return "⚙️"
        case .fifo:
            return "🔄"
        case .socket:
            return "🔌"
        case .unknown:
            return "❓"
        }
    }
}

// MARK: - 传输进度

/// SFTP 传输进度信息
public struct SFTPProgress {
    
    /// 已传输字节数
    public let transferredBytes: UInt64
    
    /// 总字节数
    public let totalBytes: UInt64
    
    /// 传输方向
    public let direction: SFTPTransferDirection
    
    /// 文件名
    public let filename: String
    
    /// 传输速度（字节/秒），可选
    public let speed: Double?
    
    /// 剩余时间（秒），可选
    public let remainingTime: TimeInterval?
    
    // MARK: - 计算属性
    
    /// 传输进度百分比 (0.0 - 1.0)
    public var progress: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(transferredBytes) / Double(totalBytes)
    }
    
    /// 传输进度百分比 (0 - 100)
    public var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    /// 是否传输完成
    public var isCompleted: Bool {
        return transferredBytes >= totalBytes
    }
    
    // MARK: - 初始化方法
    
    /// 初始化传输进度
    /// - Parameters:
    ///   - transferredBytes: 已传输字节数
    ///   - totalBytes: 总字节数
    ///   - direction: 传输方向
    ///   - filename: 文件名
    ///   - speed: 传输速度
    ///   - remainingTime: 剩余时间
    public init(
        transferredBytes: UInt64,
        totalBytes: UInt64,
        direction: SFTPTransferDirection,
        filename: String,
        speed: Double? = nil,
        remainingTime: TimeInterval? = nil
    ) {
        self.transferredBytes = transferredBytes
        self.totalBytes = totalBytes
        self.direction = direction
        self.filename = filename
        self.speed = speed
        self.remainingTime = remainingTime
    }
}

// MARK: - 传输方向

/// SFTP 传输方向
public enum SFTPTransferDirection: String, CaseIterable, Codable {
    case upload = "upload"     // 上传
    case download = "download" // 下载
    
    /// 传输方向的中文描述
    public var description: String {
        switch self {
        case .upload:
            return "上传"
        case .download:
            return "下载"
        }
    }
    
    /// 传输方向图标
    public var icon: String {
        switch self {
        case .upload:
            return "⬆️"
        case .download:
            return "⬇️"
        }
    }
}

// MARK: - 传输结果

/// SFTP 传输结果
public struct SFTPTransferResult {
    
    /// 传输操作类型
    public let operation: SFTPTransferOperation
    
    /// 本地文件路径
    public let localPath: String
    
    /// 远程文件路径
    public let remotePath: String
    
    /// 文件大小
    public let fileSize: UInt64
    
    /// 实际传输字节数
    public let transferredBytes: UInt64
    
    /// 执行时间（秒）
    public let executionTime: TimeInterval
    
    /// 是否成功
    public let isSuccess: Bool
    
    /// 错误信息（如果失败）
    public let errorMessage: String?
    
    /// 平均传输速度（字节/秒）
    public var averageSpeed: Double {
        guard executionTime > 0 else { return 0 }
        return Double(transferredBytes) / executionTime
    }
    
    /// 传输完成度
    public var completionRate: Double {
        guard fileSize > 0 else { return 0 }
        return Double(transferredBytes) / Double(fileSize)
    }
    
    // MARK: - 初始化方法
    
    /// 初始化传输结果
    /// - Parameters:
    ///   - operation: 操作类型
    ///   - localPath: 本地路径
    ///   - remotePath: 远程路径
    ///   - fileSize: 文件大小
    ///   - transferredBytes: 传输字节数
    ///   - executionTime: 执行时间
    ///   - isSuccess: 是否成功
    ///   - errorMessage: 错误信息
    public init(
        operation: SFTPTransferOperation,
        localPath: String,
        remotePath: String,
        fileSize: UInt64,
        transferredBytes: UInt64,
        executionTime: TimeInterval,
        isSuccess: Bool,
        errorMessage: String? = nil
    ) {
        self.operation = operation
        self.localPath = localPath
        self.remotePath = remotePath
        self.fileSize = fileSize
        self.transferredBytes = transferredBytes
        self.executionTime = executionTime
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
    }
}

// MARK: - 传输操作

/// SFTP 传输操作类型
public enum SFTPTransferOperation: String, CaseIterable, Codable {
    case upload = "upload"         // 上传文件
    case download = "download"     // 下载文件
    case delete = "delete"         // 删除文件
    case rename = "rename"         // 重命名文件
    case createDirectory = "mkdir" // 创建目录
    case removeDirectory = "rmdir" // 删除目录
    
    /// 操作的中文描述
    public var description: String {
        switch self {
        case .upload:
            return "上传"
        case .download:
            return "下载"
        case .delete:
            return "删除"
        case .rename:
            return "重命名"
        case .createDirectory:
            return "创建目录"
        case .removeDirectory:
            return "删除目录"
        }
    }
}

// MARK: - 扩展

extension SFTPFileInfo: CustomStringConvertible {
    public var description: String {
        let sizeStr = formatFileSize(size)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        return """
        \(type.icon) \(name)
        路径: \(path)
        大小: \(sizeStr)
        权限: \(permissions)
        所有者: \(owner):\(group)
        修改时间: \(dateFormatter.string(from: modificationDate))
        """
    }
    
    /// 格式化文件大小
    private func formatFileSize(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        if unitIndex == 0 {
            return "\(Int(size)) \(units[unitIndex])"
        } else {
            return String(format: "%.2f \(units[unitIndex])", size)
        }
    }
}

extension SFTPProgress: CustomStringConvertible {
    public var description: String {
        let filename = self.filename.isEmpty ? "文件" : self.filename
        let progressStr = "\(progressPercentage)%"
        let sizeStr = "\(formatBytes(transferredBytes))/\(formatBytes(totalBytes))"
        
        var result = "\(direction.icon) \(direction.description) \(filename): \(progressStr) (\(sizeStr))"
        
        if let speed = speed {
            result += " - \(formatBytes(UInt64(speed)))/s"
        }
        
        if let remaining = remainingTime {
            result += " - 剩余 \(formatTime(remaining))"
        }
        
        return result
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        if unitIndex == 0 {
            return "\(Int(size))\(units[unitIndex])"
        } else {
            return String(format: "%.1f\(units[unitIndex])", size)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", secs))"
        } else {
            return "\(minutes):\(String(format: "%02d", secs))"
        }
    }
}

extension SFTPTransferResult: CustomStringConvertible {
    public var description: String {
        return summary
    }
    
    /// 获取简短摘要
    public var summary: String {
        let speedStr = formatSpeed(averageSpeed)
        let timeStr = String(format: "%.2f", executionTime)
        let statusIcon = isSuccess ? "✅" : "❌"
        
        if isSuccess {
            return "\(statusIcon) \(operation.description)成功: \((remotePath as NSString).lastPathComponent) (\(speedStr), \(timeStr)s)"
        } else {
            let error = errorMessage ?? "未知错误"
            return "\(statusIcon) \(operation.description)失败: \((remotePath as NSString).lastPathComponent) - \(error)"
        }
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var speed = bytesPerSecond
        var unitIndex = 0
        
        while speed >= 1024 && unitIndex < units.count - 1 {
            speed /= 1024
            unitIndex += 1
        }
        
        if unitIndex == 0 {
            return "\(Int(speed)) \(units[unitIndex])"
        } else {
            return String(format: "%.1f \(units[unitIndex])", speed)
        }
    }
}

// MARK: - Codable 支持

extension SFTPFileInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case name, path, size, type, permissions
        case owner, group, modificationDate, accessDate, creationDate
    }
}

extension SFTPProgress: Codable {
    enum CodingKeys: String, CodingKey {
        case transferredBytes, totalBytes, direction
        case filename, speed, remainingTime
    }
}

extension SFTPTransferResult: Codable {
    enum CodingKeys: String, CodingKey {
        case operation, localPath, remotePath, fileSize
        case transferredBytes, executionTime, isSuccess, errorMessage
    }
} 