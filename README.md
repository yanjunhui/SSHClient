# 🔐 SSHClient - Swift SSH/SFTP 客户端库

一个功能完整的 Swift SSH/SFTP 客户端库，专为 macOS 和 iOS 开发，提供安全的远程服务器连接、终端会话管理和文件传输功能。

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2012.0%2B%20%7C%20iOS%2015.0%2B-lightgrey.svg)](https://developer.apple.com/swift/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 📋 功能特性

### 🔐 SSH 连接与认证
- **密码认证**: 支持用户名/密码登录
- **密钥认证**: 支持 RSA/ED25519 私钥认证
- **连接管理**: 自动重连、连接状态监控
- **安全配置**: 超时设置、主机密钥验证

### 💻 交互式终端
- **PTY 支持**: 完整的伪终端功能
- **命令执行**: 同步/异步命令执行
- **环境变量**: 自定义环境变量设置
- **终端大小**: 动态调整终端窗口大小
- **输出处理**: 实时标准输出和错误输出处理

### 📁 SFTP 文件传输
- **文件操作**: 上传、下载、删除文件
- **目录管理**: 创建、删除、列出目录内容
- **进度监控**: 实时传输进度回调
- **断点续传**: 支持大文件传输恢复
- **权限管理**: 文件权限查看和修改

### 🛠 开发者功能
- **完整中文注释**: 所有 API 都有详细的中文说明
- **异步支持**: 基于 async/await 的现代异步编程
- **错误处理**: 详细的错误类型和恢复建议
- **日志记录**: 完整的操作日志和调试信息
- **单元测试**: 全面的测试覆盖和真实环境测试

## 📦 安装

### Swift Package Manager

在 Xcode 中：
1. 选择 `File` → `Add Package Dependencies...`
2. 输入仓库 URL：`https://github.com/your-username/SSHClient.git`
3. 选择版本并添加到项目

或在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/your-username/SSHClient.git", from: "1.0.0")
]
```

## 🚀 快速开始

### 1. 基本 SSH 连接

```swift
import SSHClient

// 创建配置
let config = SSHConfiguration(
    host: "your-server.com",
    port: 22,
    connectionTimeout: 30
)

// 初始化客户端
let client = SSHClient(configuration: config)

do {
    // 建立连接
    try await client.connect()
    
    // 密码认证
    try await client.authenticate(username: "user", password: "password")
    
    // 或使用密钥认证
    // try await client.authenticate(username: "user", privateKeyPath: "/path/to/key")
    
    print("SSH 连接成功！")
    
} catch {
    print("连接失败: \(error.localizedDescription)")
}
```

### 2. 执行终端命令

```swift
// 创建终端会话
let terminal = SSHTerminal(sshClient: client)

// 设置输出处理
terminal.outputHandler = { output in
    print("输出: \(output)")
}

terminal.errorHandler = { error in
    print("错误: \(error)")
}

do {
    // 启动终端
    try await terminal.start()
    
    // 执行命令
    let result = try await terminal.executeCommand("ls -la")
    
    if result.isSuccess {
        print("命令执行成功:")
        print(result.output)
    } else {
        print("命令执行失败: \(result.error)")
    }
    
    // 发送特殊按键
    try await terminal.sendSpecialKey(.ctrlC)
    
} catch {
    print("终端操作失败: \(error)")
}
```

### 3. SFTP 文件操作

```swift
// 创建 SFTP 客户端
let sftp = SFTPClient(sshClient: client)

// 设置传输进度回调
sftp.progressHandler = { progress in
    print("传输进度: \(progress.progressPercentage)% - \(progress.filename)")
    print("传输速度: \(progress.speedDescription)")
}

do {
    // 启动 SFTP 会话
    try await sftp.start()
    
    // 列出远程目录
    let files = try await sftp.listDirectory("/home/user")
    for file in files {
        print("\(file.type.icon) \(file.name) (\(file.formattedSize))")
    }
    
    // 上传文件
    let uploadResult = try await sftp.uploadFile(
        from: "/local/path/file.txt",
        to: "/remote/path/file.txt"
    )
    print("上传结果: \(uploadResult.summary)")
    
    // 下载文件
    let downloadResult = try await sftp.downloadFile(
        from: "/remote/path/file.txt",
        to: "/local/path/downloaded_file.txt"
    )
    print("下载结果: \(downloadResult.summary)")
    
} catch {
    print("SFTP 操作失败: \(error)")
}
```

## 📚 详细用法

### SSH 配置选项

```swift
let config = SSHConfiguration(
    host: "server.com",
    port: 22,
    connectionTimeout: 30,        // 连接超时
    dataTimeout: 60,             // 数据传输超时
    protocolVersion: "2.0",      // SSH 协议版本
    clientIdentifier: "MyApp",   // 客户端标识
    compressionEnabled: false,   // 是否启用压缩
    keepAliveInterval: 30        // 心跳间隔
)

// 验证配置
try config.validate()

// 快速创建配置
let localhostConfig = SSHConfiguration.localhost()
let customConfig = SSHConfiguration.create(host: "server.com", port: 2022)
```

### 错误处理

```swift
do {
    try await client.connect()
} catch let error as SSHError {
    switch error.category {
    case .connection:
        print("连接错误: \(error.errorDescription ?? "")")
        
    case .authentication:
        print("认证错误: \(error.errorDescription ?? "")")
        
    case .fileTransfer:
        print("文件传输错误: \(error.errorDescription ?? "")")
        
    default:
        print("其他错误: \(error.errorDescription ?? "")")
    }
}
```

### 连接状态监控

```swift
let info = client.connectionInfo

print("连接状态: \(info.statusDescription)")
print("连接质量: \(info.connectionQuality)/100")
print("可以执行命令: \(info.canExecuteCommands)")
print("可以传输文件: \(info.canTransferFiles)")

if let duration = info.connectionDuration {
    print("连接时长: \(duration) 秒")
}
```

### 终端高级用法

```swift
let terminal = SSHTerminal(sshClient: client)

// 自定义终端尺寸
terminal.terminalSize = TerminalSize(columns: 120, rows: 40)

// 设置环境变量
terminal.setEnvironmentVariable("LANG", value: "zh_CN.UTF-8")
terminal.setEnvironmentVariable("TERM", value: "xterm-256color")

// 启用原始模式（用于交互式应用）
try await terminal.enableRawMode()

// 发送原始数据
try await terminal.sendRawData("top\n".data(using: .utf8)!)
```

### SFTP 高级功能

```swift
let sftp = SFTPClient(sshClient: client)

// 创建目录
try await sftp.createDirectory("/remote/new_folder")

// 删除文件
try await sftp.deleteFile("/remote/old_file.txt")

// 重命名文件
try await sftp.renameFile(from: "/remote/old_name.txt", to: "/remote/new_name.txt")

// 获取文件属性
let fileInfo = try await sftp.getFileInfo("/remote/file.txt")
print("文件大小: \(fileInfo.formattedSize)")
print("修改时间: \(fileInfo.formattedModificationDate)")
print("权限: \(fileInfo.permissions)")

// 设置文件权限
try await sftp.setFilePermissions("/remote/file.txt", permissions: "755")
```

## 🧪 测试

运行单元测试：

```bash
swift test
```

当前测试覆盖：
- ✅ SSH 配置验证 (3 测试)
- ✅ SSH 客户端基础功能 (4 测试)
- ✅ 终端会话管理 (4 测试)
- ✅ 命令执行结果处理 (3 测试)
- ✅ SFTP 类型定义 (3 测试)
- ✅ 错误处理机制 (3 测试)
- ✅ 连接信息管理 (1 测试)
- ✅ 性能测试 (2 测试)

**总计: 24 个测试全部通过** ✅

## 📖 API 文档

### 主要类

#### `SSHClient`
主要的 SSH 客户端类，负责连接管理和认证。

```swift
public class SSHClient {
    public init(configuration: SSHConfiguration)
    public func connect() async throws
    public func authenticate(username: String, password: String) async throws
    public func authenticate(username: String, privateKeyPath: String, passphrase: String?) async throws
    public func disconnect()
    public var connectionInfo: SSHConnectionInfo { get }
}
```

#### `SSHTerminal`
SSH 终端会话管理器，支持交互式命令执行。

```swift
public class SSHTerminal {
    public init(sshClient: SSHClient)
    public func start() async throws
    public func executeCommand(_ command: String) async throws -> SSHCommandResult
    public func sendSpecialKey(_ key: SpecialKey) async throws
    public var outputHandler: ((String) -> Void)?
    public var errorHandler: ((String) -> Void)?
}
```

#### `SFTPClient`
SFTP 文件传输客户端，支持文件上传下载和目录管理。

```swift
public class SFTPClient {
    public init(sshClient: SSHClient)
    public func start() async throws
    public func listDirectory(_ path: String) async throws -> [SFTPFileInfo]
    public func uploadFile(from localPath: String, to remotePath: String) async throws -> SFTPTransferResult
    public func downloadFile(from remotePath: String, to localPath: String) async throws -> SFTPTransferResult
    public var progressHandler: ((SFTPProgress) -> Void)?
}
```

### 配置类型

#### `SSHConfiguration`
SSH 连接配置，包含所有连接参数。

#### `SSHCommandResult`
命令执行结果，包含输出、错误和执行时间。

#### `SFTPFileInfo`
远程文件信息，包含名称、大小、权限等属性。

#### `SSHError`
统一的错误类型，提供详细的错误分类和描述。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- [BlueSocket](https://github.com/Kitura/BlueSocket) - 底层网络套接字支持
- [Swift Crypto](https://github.com/apple/swift-crypto) - 加密功能支持
- [Swift Log](https://github.com/apple/swift-log) - 日志记录支持

## 📞 支持

如果您在使用过程中遇到问题，请：

1. 查看 [常见问题](FAQ.md)
2. 搜索现有的 [Issues](https://github.com/your-username/SSHClient/issues)
3. 创建新的 Issue 并提供详细信息
