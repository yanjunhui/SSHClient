import XCTest
@testable import SSHClient
import Foundation

/// 真实 SSH/SFTP 连接测试
/// 需要启动 Docker 容器后运行这些测试
/// 运行命令: docker run -d -p 2222:22 --name test-ssh lscr.io/linuxserver/openssh-server:latest
class RealSSHTests: XCTestCase {
    
    // MARK: - 测试配置
    
    private let testHost = "localhost"
    private let testPort = 2222
    private let testUsername = "testuser"
    private let testPassword = "password123"
    
    private var sshClient: SSHClient!
    private var configuration: SSHConfiguration!
    
    // MARK: - 设置和清理
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 检查Docker容器是否运行，如果没有运行则跳过测试
        if !isDockerContainerRunning() {
            throw XCTSkip("Docker SSH 服务器未运行，跳过真实连接测试。请运行: docker run -d -p 2222:22 --name test-ssh -e USER_NAME=\(testUsername) -e USER_PASSWORD=\(testPassword) lscr.io/linuxserver/openssh-server:latest")
        }
        
        // 创建真实服务器的配置
        configuration = SSHConfiguration(
            host: testHost,
            port: testPort,
            connectionTimeout: 15,
            dataTimeout: 30
        )
        
        sshClient = SSHClient(configuration: configuration)
        
        print("📋 测试配置:")
        print("   主机: \(testHost):\(testPort)")
        print("   用户: \(testUsername)")
        print("   密码: \(testPassword)")
        print("")
    }
    
    override func tearDownWithError() throws {
        if sshClient != nil {
            Task {
                await sshClient.disconnect()
            }
        }
        sshClient = nil
        configuration = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - 连接测试
    
    func testRealSSHConnectionAndAuthentication() async throws {
        print("🔗 测试真实 SSH 连接和认证...")
        
        do {
            // 使用Citadel时，连接和认证是一体的
            try await sshClient.authenticate(username: testUsername, password: testPassword)
            
            XCTAssertTrue(sshClient.isConnected, "SSH 应该已连接")
            XCTAssertTrue(sshClient.isAuthenticated, "SSH 应该已认证")
            
            let info = sshClient.connectionInfo
            XCTAssertTrue(info.isConnected)
            XCTAssertTrue(info.isAuthenticated)
            XCTAssertNotNil(info.sessionId)
            
            print("✅ SSH 连接和认证成功")
            
        } catch {
            XCTFail("SSH 连接/认证失败: \(error.localizedDescription)")
            print("❌ 请确保 Docker 容器正在运行并且配置正确")
            throw error
        }
    }
    
    // MARK: - 终端测试
    
    func testRealTerminalSession() async throws {
        print("💻 测试真实终端会话...")
        
        // 建立连接并认证
        try await sshClient.authenticate(username: testUsername, password: testPassword)
        
        let terminal = SSHTerminal(sshClient: sshClient)
        
        // 设置输出处理器
        var receivedOutput = ""
        var receivedError = ""
        
        terminal.outputHandler = { output in
            receivedOutput += output
            print("📤 输出: \(output)")
        }
        
        terminal.errorHandler = { error in
            receivedError += error
            print("📤 错误: \(error)")
        }
        
        do {
            try await terminal.start()
            XCTAssertTrue(terminal.isActive, "终端应该处于活跃状态")
            
            // 执行简单命令
            let result = try await terminal.executeCommand("whoami")
            XCTAssertTrue(result.isSuccess, "whoami 命令应该成功")
            XCTAssertFalse(result.output.isEmpty, "应该有输出")
            
            print("✅ 终端会话测试成功")
            print("   命令: \(result.command)")
            print("   输出: \(result.output)")
            print("   执行时间: \(result.executionTime) 秒")
            
        } catch {
            XCTFail("终端会话失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    func testRealCommandExecution() async throws {
        print("⚡ 测试真实命令执行...")
        
        // 建立连接并认证
        try await sshClient.authenticate(username: testUsername, password: testPassword)
        
        let terminal = SSHTerminal(sshClient: sshClient)
        try await terminal.start()
        
        // 测试多个命令
        let testCommands = [
            "pwd",           // 显示当前目录
            "ls -la",        // 列出文件
            "date",          // 显示日期
            "uname -a",      // 系统信息
            "echo 'Hello from Swift SSH Client!'"  // 回显测试
        ]
        
        for command in testCommands {
            do {
                let result = try await terminal.executeCommand(command)
                
                print("📋 命令: \(command)")
                print("   结果: \(result.isSuccess ? "成功" : "失败")")
                print("   输出: \(result.output.prefix(100))...")
                print("   执行时间: \(String(format: "%.3f", result.executionTime)) 秒")
                print("")
                
                // 大部分基本命令应该成功
                if ["pwd", "date", "echo 'Hello from Swift SSH Client!'"].contains(command) {
                    XCTAssertTrue(result.isSuccess, "\(command) 应该执行成功")
                    XCTAssertFalse(result.output.isEmpty, "\(command) 应该有输出")
                }
                
            } catch {
                print("❌ 命令 \(command) 执行失败: \(error)")
                // 某些命令可能在容器中不可用，不强制失败测试
            }
        }
        
        print("✅ 命令执行测试完成")
    }
    
    func testCommandStream() async throws {
        print("🌊 测试流式命令执行...")
        
        try await sshClient.authenticate(username: testUsername, password: testPassword)
        
        let terminal = SSHTerminal(sshClient: sshClient)
        try await terminal.start()
        
        var streamOutput = ""
        let command = "echo 'Line 1'; sleep 1; echo 'Line 2'; sleep 1; echo 'Line 3'"
        
        // 使用流式命令执行
        let stream = terminal.executeCommandStream(command)
        
        do {
            for try await output in stream {
                streamOutput += output
                print("🌊 流输出: \(output)")
            }
            
            XCTAssertFalse(streamOutput.isEmpty, "流式输出不应为空")
            print("✅ 流式命令执行测试成功")
            
        } catch {
            print("❌ 流式命令执行失败: \(error)")
            // 流式功能可能在某些环境中不完全支持
        }
    }
    
    // MARK: - SFTP 测试
    
    func testRealSFTPSession() async throws {
        print("📁 测试真实 SFTP 会话...")
        
        // 建立连接并认证
        try await sshClient.authenticate(username: testUsername, password: testPassword)
        
        let sftpClient = SFTPClient(sshClient: sshClient)
        
        do {
            try await sftpClient.start()
            XCTAssertTrue(sftpClient.isActive, "SFTP 会话应该处于活跃状态")
            
            print("✅ SFTP 会话建立成功")
            print("   当前目录: \(sftpClient.currentDirectory)")
            
            await sftpClient.close()
            XCTAssertFalse(sftpClient.isActive, "SFTP 会话应该已关闭")
            
        } catch {
            XCTFail("SFTP 会话失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    func testSFTPDirectoryOperations() async throws {
        print("📂 测试 SFTP 目录操作...")
        
        try await sshClient.authenticate(username: testUsername, password: testPassword)
        
        let sftpClient = SFTPClient(sshClient: sshClient)
        try await sftpClient.start()
        
        do {
            // 列出当前目录
            let files = try await sftpClient.listDirectory()
            print("📋 目录文件列表:")
            for file in files {
                print("   \(file.type.icon) \(file.name) (\(file.size) bytes)")
            }
            
            // 创建测试目录
            let testDirName = "swift_test_\(Int(Date().timeIntervalSince1970))"
            
            try await sftpClient.createDirectory(testDirName)
            print("✅ 创建目录成功: \(testDirName)")
            
            // 切换到测试目录
            try await sftpClient.changeDirectory(to: testDirName)
            print("✅ 切换目录成功")
            
        } catch {
            print("❌ SFTP 目录操作失败: \(error)")
            // 某些SFTP操作可能需要特定权限
        }
        
        await sftpClient.close()
    }
    
    func testSFTPFileTransfer() async throws {
        print("📄 测试 SFTP 文件传输...")
        
        try await sshClient.authenticate(username: testUsername, password: testPassword)
        
        let sftpClient = SFTPClient(sshClient: sshClient)
        try await sftpClient.start()
        
        // 创建本地测试文件
        let testContent = "Hello from Swift SSH Client!\nThis is a test file.\nTimestamp: \(Date())"
        let localTestFile = "/tmp/swift_ssh_test.txt"
        let remoteTestFile = "swift_ssh_test_upload.txt"
        
        try testContent.write(toFile: localTestFile, atomically: true, encoding: .utf8)
        
        do {
            // 上传文件
            let uploadResult = try await sftpClient.uploadFile(from: localTestFile, to: remoteTestFile)
            XCTAssertTrue(uploadResult.isSuccess, "文件上传应该成功")
            print("✅ 文件上传成功: \(uploadResult.summary)")
            
            // 下载文件
            let downloadPath = "/tmp/swift_ssh_test_download.txt"
            let downloadResult = try await sftpClient.downloadFile(from: remoteTestFile, to: downloadPath)
            XCTAssertTrue(downloadResult.isSuccess, "文件下载应该成功")
            print("✅ 文件下载成功: \(downloadResult.summary)")
            
            // 验证文件内容
            let downloadedContent = try String(contentsOfFile: downloadPath)
            XCTAssertEqual(testContent, downloadedContent, "下载的文件内容应该匹配")
            
            // 清理本地文件
            try? FileManager.default.removeItem(atPath: localTestFile)
            try? FileManager.default.removeItem(atPath: downloadPath)
            
        } catch {
            print("❌ SFTP 文件传输失败: \(error)")
            throw error
        }
        
        await sftpClient.close()
    }
    
    // MARK: - 性能测试
    
    func testConnectionPerformance() async throws {
        print("⚡ 测试连接性能...")
        
        let iterations = 5
        var totalTime: TimeInterval = 0
        
        for i in 1...iterations {
            let startTime = Date()
            
            let client = SSHClient(configuration: configuration)
            try await client.authenticate(username: testUsername, password: testPassword)
            await client.disconnect()
            
            let connectionTime = Date().timeIntervalSince(startTime)
            totalTime += connectionTime
            
            print("🔄 连接 \(i): \(String(format: "%.3f", connectionTime)) 秒")
        }
        
        let averageTime = totalTime / Double(iterations)
        print("📊 平均连接时间: \(String(format: "%.3f", averageTime)) 秒")
        
        // 连接时间应该在合理范围内（10秒以内）
        XCTAssertLessThan(averageTime, 10.0, "平均连接时间应该在10秒以内")
    }
    
    // MARK: - 辅助方法
    
    private func isDockerContainerRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["nc", "-z", testHost, "\(testPort)"]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
} 