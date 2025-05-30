#!/bin/bash

# Swift SSH 客户端测试脚本
# 功能：自动化测试环境搭建和测试执行

set -e  # 遇到错误立即退出

# 配置变量
COMPOSE_FILE="docker-compose.test.yml"
SSH_PORT=2222
ALPINE_PORT=2223
TEST_USER="testuser"
TEST_PASSWORD="password123"
CONTAINER_NAME="swift-ssh-test-server"
ALPINE_CONTAINER="swift-ssh-alpine-server"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "Swift SSH 客户端测试脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  setup     - 启动Docker测试环境"
    echo "  test      - 运行所有测试"
    echo "  real      - 只运行真实SSH测试"
    echo "  unit      - 只运行单元测试"
    echo "  cleanup   - 清理Docker环境"
    echo "  status    - 检查测试环境状态"
    echo "  logs      - 查看SSH服务器日志"
    echo "  shell     - 连接到SSH服务器（调试用）"
    echo "  help      - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 setup test    # 搭建环境并运行测试"
    echo "  $0 cleanup       # 清理环境"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖工具..."
    
    local deps=("docker" "swift" "nc")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "缺少依赖工具: ${missing[*]}"
        log_info "请安装缺少的工具后重试"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 搭建测试环境
setup_environment() {
    log_info "搭建SSH测试环境..."
    
    # 创建必要的目录
    mkdir -p test-data test-files
    
    # 启动Docker容器
    if docker-compose -f "$COMPOSE_FILE" up -d; then
        log_success "Docker容器启动成功"
    else
        log_error "Docker容器启动失败"
        exit 1
    fi
    
    # 等待SSH服务器就绪
    wait_for_ssh_server
}

# 等待SSH服务器启动
wait_for_ssh_server() {
    log_info "等待SSH服务器启动..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z localhost $SSH_PORT 2>/dev/null; then
            log_success "SSH服务器已就绪 (端口 $SSH_PORT)"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "SSH服务器启动超时"
    return 1
}

# 检查环境状态
check_status() {
    log_info "检查测试环境状态..."
    
    echo ""
    echo "=== Docker 容器状态 ==="
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo ""
    echo "=== 端口检查 ==="
    for port in $SSH_PORT $ALPINE_PORT; do
        if nc -z localhost $port 2>/dev/null; then
            log_success "端口 $port: 可用"
        else
            log_warning "端口 $port: 不可用"
        fi
    done
    
    echo ""
    echo "=== SSH 连接测试 ==="
    if command -v sshpass &> /dev/null; then
        if sshpass -p "$TEST_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
           "$TEST_USER@localhost" -p "$SSH_PORT" "echo 'SSH连接正常'" 2>/dev/null; then
            log_success "SSH认证测试通过"
        else
            log_warning "SSH认证测试失败"
        fi
    else
        log_info "跳过SSH连接测试 (需要安装 sshpass)"
    fi
}

# 运行单元测试
run_unit_tests() {
    log_info "运行单元测试..."
    
    echo ""
    if swift test --filter SSHClientTests; then
        log_success "单元测试通过"
        return 0
    else
        log_error "单元测试失败"
        return 1
    fi
}

# 运行真实SSH测试
run_real_tests() {
    log_info "运行真实SSH连接测试..."
    
    # 确保SSH服务器运行
    if ! nc -z localhost $SSH_PORT 2>/dev/null; then
        log_warning "SSH服务器未运行，尝试启动..."
        setup_environment
    fi
    
    echo ""
    if swift test --filter RealSSHTests; then
        log_success "真实SSH测试通过"
        return 0
    else
        log_error "真实SSH测试失败"
        return 1
    fi
}

# 运行所有测试
run_all_tests() {
    log_info "运行完整测试套件..."
    
    local failed=0
    
    # 运行单元测试
    if ! run_unit_tests; then
        ((failed++))
    fi
    
    echo ""
    
    # 运行真实测试
    if ! run_real_tests; then
        ((failed++))
    fi
    
    echo ""
    echo "=== 测试总结 ==="
    if [ $failed -eq 0 ]; then
        log_success "所有测试通过！"
        return 0
    else
        log_error "$failed 个测试套件失败"
        return 1
    fi
}

# 清理环境
cleanup_environment() {
    log_info "清理测试环境..."
    
    # 停止并删除容器
    docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans
    
    # 清理测试数据
    if [ -d "test-data" ]; then
        rm -rf test-data
    fi
    
    if [ -d "test-files" ]; then
        rm -rf test-files
    fi
    
    log_success "环境清理完成"
}

# 查看日志
show_logs() {
    log_info "查看SSH服务器日志..."
    docker-compose -f "$COMPOSE_FILE" logs -f ssh-server
}

# 连接到SSH服务器（调试用）
connect_ssh() {
    log_info "连接到SSH测试服务器..."
    log_info "用户名: $TEST_USER, 密码: $TEST_PASSWORD"
    
    if command -v sshpass &> /dev/null; then
        sshpass -p "$TEST_PASSWORD" ssh -o StrictHostKeyChecking=no \
            "$TEST_USER@localhost" -p "$SSH_PORT"
    else
        log_info "请手动连接: ssh $TEST_USER@localhost -p $SSH_PORT"
        log_info "密码: $TEST_PASSWORD"
    fi
}

# 构建项目
build_project() {
    log_info "构建Swift项目..."
    
    if swift build; then
        log_success "项目构建成功"
        return 0
    else
        log_error "项目构建失败"
        return 1
    fi
}

# 主函数
main() {
    # 检查参数
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    # 检查依赖
    check_dependencies
    
    # 处理命令
    while [ $# -gt 0 ]; do
        case $1 in
            setup)
                setup_environment
                ;;
            test)
                build_project && run_all_tests
                ;;
            real)
                build_project && run_real_tests
                ;;
            unit)
                build_project && run_unit_tests
                ;;
            cleanup)
                cleanup_environment
                ;;
            status)
                check_status
                ;;
            logs)
                show_logs
                ;;
            shell)
                connect_ssh
                ;;
            build)
                build_project
                ;;
            help)
                show_help
                ;;
            *)
                log_error "未知命令: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# 执行主函数
main "$@" 