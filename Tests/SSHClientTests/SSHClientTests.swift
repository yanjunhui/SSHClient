import XCTest
@testable import SSHClient

/// SSHClient 库的单元测试
/// 包含各个模块的功能测试和集成测试
final class SSHClientTests: XCTestCase {
    
    // MARK: - 测试属性
    
    private var testConfiguration: SSHConfiguration!
    private var sshClient: SSHClient!
    
    // MARK: - 设置和清理
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 创建测试配置
        testConfiguration = SSHConfiguration(
            host: "127.0.0.1",
            port: 2222,
            connectionTimeout: 10,
            dataTimeout: 30
        )
        
        // 初始化 SSH 客户端
        sshClient = SSHClient(configuration: testConfiguration)
    }
    
    override func tearDownWithError() throws {
        Task {
            await sshClient?.disconnect()
        }
        sshClient = nil
        testConfiguration = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - SSH 配置测试
    
    func testSSHConfigurationValidation() throws {
        // 测试有效配置
        XCTAssertNoThrow(try testConfiguration.validate())
        
        // 测试无效主机地址
        let invalidHostConfig = SSHConfiguration(host: "", port: 22)
        XCTAssertThrowsError(try invalidHostConfig.validate()) { error in
            XCTAssertTrue(error is SSHError)
            if case .invalidConfiguration(let message) = error as? SSHError {
                XCTAssertTrue(message.contains("主机地址不能为空"))
            }
        }
        
        // 测试无效端口
        let invalidPortConfig = SSHConfiguration(host: "localhost", port: 0)
        XCTAssertThrowsError(try invalidPortConfig.validate()) { error in
            XCTAssertTrue(error is SSHError)
            if case .invalidConfiguration(let message) = error as? SSHError {
                XCTAssertTrue(message.contains("端口号必须在"))
            }
        }
    }
    
    func testSSHConfigurationDefaults() {
        let config = SSHConfiguration(host: "example.com")
        
        XCTAssertEqual(config.host, "example.com")
        XCTAssertEqual(config.port, 22)
        XCTAssertEqual(config.connectionTimeout, 30)
        XCTAssertEqual(config.dataTimeout, 60)
        XCTAssertEqual(config.protocolVersion, "2.0")
        XCTAssertFalse(config.compressionEnabled)
    }
    
    func testSSHConfigurationFactoryMethods() {
        let localhostConfig = SSHConfiguration.localhost()
        XCTAssertEqual(localhostConfig.host, "127.0.0.1")
        XCTAssertEqual(localhostConfig.port, 22)
        
        let customConfig = SSHConfiguration.create(host: "server.com", port: 2022)
        XCTAssertEqual(customConfig.host, "server.com")
        XCTAssertEqual(customConfig.port, 2022)
    }
    
    // MARK: - SSH 客户端基础测试
    
    func testSSHClientInitialization() {
        XCTAssertNotNil(sshClient)
        XCTAssertEqual(sshClient.configuration.host, testConfiguration.host)
        XCTAssertEqual(sshClient.configuration.port, testConfiguration.port)
        XCTAssertFalse(sshClient.isConnected)
        XCTAssertFalse(sshClient.isAuthenticated)
    }
    
    func testSSHClientConnectionInfo() {
        let info = sshClient.connectionInfo
        XCTAssertEqual(info.host, testConfiguration.host)
        XCTAssertEqual(info.port, testConfiguration.port)
        XCTAssertFalse(info.isConnected)
        XCTAssertFalse(info.isAuthenticated)
        XCTAssertNil(info.sessionId)
    }
    
    // MARK: - 错误处理测试
    
    func testAuthenticationWithInvalidCredentials() async {
        // 测试使用无效凭据进行认证
        do {
            try await sshClient.authenticate(username: "invalid", password: "invalid")
            XCTFail("期望认证失败")
        } catch let error as SSHError {
            if case .authenticationFailed(_) = error {
                // 预期的认证失败错误
                XCTAssertTrue(true)
            } else {
                XCTFail("期望 authenticationFailed 错误，实际收到: \(error)")
            }
        } catch {
            // 也接受其他类型的连接错误，因为没有真实服务器
            print("收到连接错误（预期）: \(error)")
        }
    }
    
    func testKeyAuthenticationWithInvalidPath() async {
        // 测试使用不存在的密钥文件进行认证
        do {
            try await sshClient.authenticate(username: "test", privateKeyPath: "/nonexistent/key")
            XCTFail("期望认证失败")
        } catch let error as SSHError {
            // 可能抛出authenticationFailed或keyNotFound错误
            switch error {
            case .keyNotFound(_):
                XCTAssertTrue(true, "收到预期的keyNotFound错误")
            case .authenticationFailed(let message):
                // 如果密钥检查在认证阶段进行，也是可以接受的
                XCTAssertTrue(message.contains("密钥文件"), "错误消息应该包含密钥文件相关信息")
            default:
                XCTFail("期望 keyNotFound 或 authenticationFailed 错误，实际收到: \(error)")
            }
        } catch {
            XCTFail("期望 SSHError 类型错误，实际收到: \(error)")
        }
    }
    
    // MARK: - SSH 终端测试
    
    func testSSHTerminalInitialization() {
        let terminal = SSHTerminal(sshClient: sshClient)
        XCTAssertNotNil(terminal)
        XCTAssertFalse(terminal.isActive)
        XCTAssertEqual(terminal.terminalSize.width, 80)
        XCTAssertEqual(terminal.terminalSize.height, 24)
    }
    
    func testTerminalEnvironmentVariables() {
        let terminal = SSHTerminal(sshClient: sshClient)
        
        // 测试设置自定义环境变量
        terminal.environment["TEST_VAR"] = "test_value"
        XCTAssertEqual(terminal.environment["TEST_VAR"], "test_value")
    }
    
    func testTerminalSizeConfiguration() {
        let terminal = SSHTerminal(sshClient: sshClient)
        let newSize = TerminalSize(width: 120, height: 30, pixelWidth: 1200, pixelHeight: 600)
        
        terminal.terminalSize = newSize
        XCTAssertEqual(terminal.terminalSize.width, 120)
        XCTAssertEqual(terminal.terminalSize.height, 30)
        XCTAssertEqual(terminal.terminalSize.pixelWidth, 1200)
        XCTAssertEqual(terminal.terminalSize.pixelHeight, 600)
    }
    
    func testSpecialKeyEscapeSequences() {
        XCTAssertEqual(SpecialKey.enter.escapeSequence, "\r")
        XCTAssertEqual(SpecialKey.tab.escapeSequence, "\t")
        XCTAssertEqual(SpecialKey.escape.escapeSequence, "\u{1B}")
        XCTAssertEqual(SpecialKey.arrowUp.escapeSequence, "\u{1B}[A")
        XCTAssertEqual(SpecialKey.ctrlC.escapeSequence, "\u{3}")
    }
    
    func testTerminalStartWithoutAuthentication() async {
        let terminal = SSHTerminal(sshClient: sshClient)
        
        do {
            try await terminal.start()
            XCTFail("期望终端启动失败")
        } catch let error as SSHError {
            if case .sessionNotEstablished = error {
                // 预期的会话未建立错误
                XCTAssertTrue(true)
            } else {
                XCTFail("期望 sessionNotEstablished 错误，实际收到: \(error)")
            }
        } catch {
            XCTFail("期望 SSHError 类型错误，实际收到: \(error)")
        }
    }
    
    // MARK: - SSH 命令结果测试
    
    func testSSHCommandResultSuccess() {
        let result = SSHCommandResult.success(
            command: "ls -la",
            output: "total 8\ndrwxr-xr-x 2 user user 4096 Jan 1 12:00 .\n",
            executionTime: 0.5
        )
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.command, "ls -la")
        XCTAssertTrue(result.hasOutput)
        XCTAssertFalse(result.hasError)
        XCTAssertEqual(result.executionTime, 0.5)
    }
    
    func testSSHCommandResultFailure() {
        let result = SSHCommandResult.failure(
            command: "invalid_command",
            exitCode: 127,
            error: "command not found",
            executionTime: 0.1
        )
        
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.exitCode, 127)
        XCTAssertEqual(result.command, "invalid_command")
        XCTAssertFalse(result.hasOutput)
        XCTAssertTrue(result.hasError)
        XCTAssertEqual(result.executionTime, 0.1)
    }
    
    func testSSHCommandResultJSON() {
        let result = SSHCommandResult.success(
            command: "test",
            output: "test output",
            executionTime: 1.0
        )
        
        let json = result.toJSON()
        XCTAssertNotNil(json, "应该能转换为JSON")
        
        if let json = json {
            let restored = SSHCommandResult.fromJSON(json)
            XCTAssertNotNil(restored, "应该能从JSON恢复")
            
            if let restored = restored {
                XCTAssertEqual(restored.command, result.command)
                XCTAssertEqual(restored.output, result.output)
                XCTAssertEqual(restored.exitCode, result.exitCode)
            }
        }
    }
    
    // MARK: - SFTP 类型测试
    
    func testSFTPFileTypeDescription() {
        XCTAssertEqual(SFTPFileType.regularFile.description, "文件")
        XCTAssertEqual(SFTPFileType.directory.description, "目录")
        XCTAssertEqual(SFTPFileType.symbolicLink.description, "符号链接")
        
        XCTAssertEqual(SFTPFileType.regularFile.icon, "📄")
        XCTAssertEqual(SFTPFileType.directory.icon, "📁")
        XCTAssertEqual(SFTPFileType.symbolicLink.icon, "🔗")
    }
    
    func testSFTPProgressCalculation() {
        let progress = SFTPProgress(
            transferredBytes: 500,
            totalBytes: 1000,
            direction: .upload,
            filename: "test.txt"
        )
        
        XCTAssertEqual(progress.progress, 0.5)
        XCTAssertEqual(progress.progressPercentage, 50)
        XCTAssertFalse(progress.isCompleted)
        
        let completed = SFTPProgress(
            transferredBytes: 1000,
            totalBytes: 1000,
            direction: .download,
            filename: "test.txt"
        )
        
        XCTAssertEqual(completed.progress, 1.0)
        XCTAssertEqual(completed.progressPercentage, 100)
        XCTAssertTrue(completed.isCompleted)
    }
    
    func testSFTPTransferResult() {
        let result = SFTPTransferResult(
            operation: .upload,
            localPath: "/local/file.txt",
            remotePath: "/remote/file.txt",
            fileSize: 1024,
            transferredBytes: 1024,
            executionTime: 2.5,
            isSuccess: true
        )
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.operation, .upload)
        XCTAssertEqual(result.fileSize, 1024)
        XCTAssertEqual(result.transferredBytes, 1024)
        XCTAssertEqual(result.executionTime, 2.5)
        
        let speed = result.averageSpeed
        XCTAssertGreaterThan(speed, 0)
    }
    
    // MARK: - SFTP 客户端测试
    
    func testSFTPClientInitialization() {
        let sftpClient = SFTPClient(sshClient: sshClient)
        XCTAssertNotNil(sftpClient)
        XCTAssertFalse(sftpClient.isActive)
        XCTAssertEqual(sftpClient.currentDirectory, "/")
    }
    
    func testSFTPStartWithoutAuthentication() async {
        let sftpClient = SFTPClient(sshClient: sshClient)
        
        do {
            try await sftpClient.start()
            XCTFail("期望SFTP启动失败")
        } catch let error as SSHError {
            if case .sessionNotEstablished = error {
                // 预期的会话未建立错误
                XCTAssertTrue(true)
            } else {
                XCTFail("期望 sessionNotEstablished 错误，实际收到: \(error)")
            }
        } catch {
            XCTFail("期望 SSHError 类型错误，实际收到: \(error)")
        }
    }
    
    // MARK: - 错误类型测试
    
    func testSSHErrorTypes() {
        let connectionError = SSHError.connectionFailed("Connection refused")
        XCTAssertEqual(connectionError.localizedDescription, "SSH连接失败: Connection refused")
        
        let authError = SSHError.authenticationFailed("Invalid credentials")
        XCTAssertEqual(authError.localizedDescription, "SSH认证失败: Invalid credentials")
        
        let notConnectedError = SSHError.notConnected
        XCTAssertEqual(notConnectedError.localizedDescription, "SSH未连接")
        
        let sessionError = SSHError.sessionNotEstablished
        XCTAssertEqual(sessionError.localizedDescription, "SSH会话未建立")
        
        let keyError = SSHError.keyNotFound("key.pem")
        XCTAssertEqual(keyError.localizedDescription, "SSH密钥文件未找到: key.pem")
    }
    
    // MARK: - 配置验证测试
    
    func testSSHConfigurationEdgeCases() {
        // 测试极端端口号
        XCTAssertThrowsError(try SSHConfiguration(host: "test", port: -1).validate())
        XCTAssertThrowsError(try SSHConfiguration(host: "test", port: 70000).validate())
        
        // 测试正常范围内的端口号
        XCTAssertNoThrow(try SSHConfiguration(host: "test", port: 1).validate())
        XCTAssertNoThrow(try SSHConfiguration(host: "test", port: 65535).validate())
        
        // 测试超时设置
        let config = SSHConfiguration(host: "test", connectionTimeout: 0, dataTimeout: 0)
        XCTAssertThrowsError(try config.validate())
    }
    
    // MARK: - 连接信息测试
    
    func testSSHConnectionInfoDescription() {
        let info = SSHConnectionInfo(
            host: "example.com",
            port: 22,
            isConnected: true,
            isAuthenticated: true,
            sessionId: "test-session"
        )
        
        let description = info.description
        XCTAssertTrue(description.contains("example.com:22"))
        XCTAssertTrue(description.contains("已连接"))
        XCTAssertTrue(description.contains("已认证"))
        XCTAssertTrue(description.contains("test-session"))
    }
    
    // MARK: - 性能测试
    
    func testSSHCommandResultCreationPerformance() {
        measure {
            for i in 0..<1000 {
                let _ = SSHCommandResult.success(
                    command: "test command \(i)",
                    output: "test output for command \(i)",
                    executionTime: 0.1
                )
            }
        }
    }
    
    func testSFTPFileInfoCreationPerformance() {
        measure {
            for i in 0..<1000 {
                let _ = SFTPFileInfo(
                    name: "file\(i).txt",
                    path: "/path/to/file\(i).txt",
                    size: UInt64(i * 1024),
                    type: .regularFile,
                    permissions: "rw-r--r--",
                    owner: "user",
                    group: "group",
                    modificationDate: Date()
                )
            }
        }
    }
}

// MARK: - 测试辅助扩展

extension SSHClientTests {
    
    /// 创建测试用的 SSH 配置
    func createTestConfiguration() -> SSHConfiguration {
        return SSHConfiguration(
            host: "test.example.com",
            port: 2222,
            connectionTimeout: 5,
            dataTimeout: 10
        )
    }
    
    /// 创建模拟的文件信息
    func createMockFileInfo(name: String, isDirectory: Bool = false) -> SFTPFileInfo {
        return SFTPFileInfo(
            name: name,
            path: "/test/\(name)",
            size: isDirectory ? 0 : 1024,
            type: isDirectory ? .directory : .regularFile,
            permissions: isDirectory ? "rwxr-xr-x" : "rw-r--r--",
            owner: "testuser",
            group: "testgroup",
            modificationDate: Date()
        )
    }
} 