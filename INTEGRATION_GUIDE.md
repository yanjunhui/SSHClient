# SSHClient 集成指南

## 在Xcode项目中添加SSHClient

### 方法1: 通过Swift Package Manager (推荐)

1. 在Xcode中打开你的项目
2. 选择 `File` → `Add Package Dependencies...`
3. 输入仓库URL或本地路径
4. 选择版本范围
5. 点击 `Add Package`
6. 选择 `SSHClient` 库添加到你的target

### 方法2: 通过Package.swift

在你的 `Package.swift` 文件中添加：

```swift
dependencies: [
    .package(path: "../SSHClient")  // 本地路径
    // 或者
    .package(url: "https://github.com/yourusername/SSHClient.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["SSHClient"]
    )
]
```

## 系统要求

- macOS 12.0+ 
- iOS 15.0+
- Swift 5.9+

## 基本使用

```swift
import SSHClient

// 创建SSH客户端
let client = SSHClient()

// 连接到服务器
try await client.connect(to: "your-server.com", port: 22)

// 密码认证
try await client.authenticate(username: "user", password: "password")

// 或密钥认证
try await client.authenticate(username: "user", privateKeyPath: "/path/to/key")

// 使用完成后断开连接
await client.disconnect()
```

## 故障排除

### 验证卡住问题
如果在添加包时遇到"Verifying..."卡住的问题：

1. 确保网络连接正常
2. 清理Xcode缓存：`Product` → `Clean Build Folder`
3. 重启Xcode
4. 检查是否有代理或防火墙阻止访问

### 依赖解析问题
如果遇到依赖解析问题：

1. 检查Swift版本兼容性
2. 确保平台版本满足要求
3. 清理包缓存：`rm -rf ~/Library/Developer/Xcode/DerivedData`

## 更多信息

详细的API文档和示例请参考 [README.md](README.md) 