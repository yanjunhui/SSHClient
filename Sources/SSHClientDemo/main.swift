import Foundation
import SSHClient
import Logging

/// SSH 客户端演示程序
/// 展示基本的SSH连接、命令执行和SFTP操作功能

@main
struct SSHClientDemo {
    
    static func main() async {
        // 配置日志
        LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
        
        print("🚀 Swift SSH 客户端演示程序")
        print(String(repeating: "=", count: 50))
        
        // 演示配置
        let config = SSHConfiguration(
            host: "localhost",
            port: 2222,
            connectionTimeout: 15,
            dataTimeout: 30
        )
        
        let client = SSHClient(configuration: config)
        
        // 演示连接和认证
        await demonstrateConnection(client: client)
        
        // 演示终端操作
        await demonstrateTerminal(client: client)
        
        // 演示SFTP操作
        await demonstrateSFTP(client: client)
        
        // 清理
        await client.disconnect()
        print("\n✅ 演示程序完成")
    }
    
    /// 演示SSH连接和认证
    static func demonstrateConnection(client: SSHClient) async {
        print("\n📡 1. SSH 连接演示")
        print(String(repeating: "-", count: 30))
        
        do {
            print("正在连接到 \(client.configuration.host):\(client.configuration.port)...")
            
            // 尝试认证（注意：这需要真实的SSH服务器）
            try await client.authenticate(username: "testuser", password: "password123")
            
            let info = client.connectionInfo
            print("✅ 连接成功！")
            print("   状态: \(info.statusDescription)")
            print("   会话ID: \(info.sessionId ?? "N/A")")
            
        } catch let error as SSHError {
            print("⚠️  连接失败 (这是正常的，如果没有运行SSH服务器): \(error.localizedDescription)")
            print("💡 提示: \(error.suggestion)")
        } catch {
            print("❌ 连接错误: \(error)")
        }
    }
    
    /// 演示终端操作
    static func demonstrateTerminal(client: SSHClient) async {
        print("\n💻 2. 终端操作演示")
        print(String(repeating: "-", count: 30))
        
        guard client.isAuthenticated else {
            print("⚠️  跳过终端演示（未认证）")
            return
        }
        
        let terminal = SSHTerminal(sshClient: client)
        
        // 设置回调
        terminal.outputHandler = { output in
            print("📤 输出: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        
        terminal.errorHandler = { error in
            print("📤 错误: \(error)")
        }
        
        do {
            try await terminal.start()
            print("✅ 终端会话已启动")
            
            // 演示命令执行
            let commands = ["whoami", "pwd", "ls -la", "date"]
            
            for command in commands {
                print("\n🔧 执行命令: \(command)")
                let result = try await terminal.executeCommand(command)
                print("   结果: \(result.isSuccess ? "成功" : "失败")")
                print("   执行时间: \(String(format: "%.3f", result.executionTime))秒")
                if !result.output.isEmpty {
                    print("   输出: \(result.output.prefix(100))...")
                }
            }
            
            await terminal.close()
            print("✅ 终端会话已关闭")
            
        } catch {
            print("❌ 终端操作失败: \(error)")
        }
    }
    
    /// 演示SFTP操作
    static func demonstrateSFTP(client: SSHClient) async {
        print("\n📁 3. SFTP 操作演示")
        print(String(repeating: "-", count: 30))
        
        guard client.isAuthenticated else {
            print("⚠️  跳过SFTP演示（未认证）")
            return
        }
        
        let sftpClient = SFTPClient(sshClient: client)
        
        // 设置进度回调
        sftpClient.progressHandler = { progress in
            print("📊 传输进度: \(progress.progressPercentage)% - \(progress.filename)")
        }
        
        do {
            try await sftpClient.start()
            print("✅ SFTP 会话已启动")
            print("   当前目录: \(sftpClient.currentDirectory)")
            
            // 演示目录列表
            print("\n📋 列出当前目录内容:")
            let files = try await sftpClient.listDirectory()
            for file in files.prefix(5) {  // 只显示前5个
                print("   \(file.type.icon) \(file.name) (\(formatFileSize(file.size)))")
            }
            
            // 演示文件上传
            await demonstrateFileUpload(sftpClient: sftpClient)
            
            await sftpClient.close()
            print("✅ SFTP 会话已关闭")
            
        } catch {
            print("❌ SFTP操作失败: \(error)")
        }
    }
    
    /// 演示文件上传
    static func demonstrateFileUpload(sftpClient: SFTPClient) async {
        print("\n📤 文件上传演示:")
        
        // 创建临时测试文件
        let testContent = """
        Swift SSH 客户端演示文件
        创建时间: \(Date())
        这是一个测试文件，用于演示SFTP上传功能。
        """
        
        let tempFile = "/tmp/ssh_demo_test.txt"
        let remoteFile = "uploaded_demo_file.txt"
        
        do {
            // 创建本地文件
            try testContent.write(toFile: tempFile, atomically: true, encoding: .utf8)
            print("   创建测试文件: \(tempFile)")
            
            // 上传文件
            let result = try await sftpClient.uploadFile(from: tempFile, to: remoteFile)
            print("   ✅ 上传成功: \(result.summary)")
            
            // 清理本地文件
            try? FileManager.default.removeItem(atPath: tempFile)
            
        } catch {
            print("   ❌ 上传失败: \(error)")
        }
    }
    
    /// 格式化文件大小
    static func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// 字符串重复扩展
extension String {
    static func *(string: String, times: Int) -> String {
        return String(repeating: string, count: times)
    }
} 