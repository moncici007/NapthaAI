#!/bin/bash

set -e  # 遇到错误立即退出

# 定义颜色
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
RESET='\e[0m'

# NapthaAI 目录
INSTALL_DIR="$HOME/naptha-node"

## Author moncici_is_girl

# 检查并安装 python3-venv 包
check_python_venv() {
    if ! dpkg -l | grep -q "python3-venv"; then
        echo -e "${YELLOW}检测到 python3-venv 未安装，正在安装...${RESET}"
        sudo apt update
        sudo apt install python3.10-venv
    fi
}

# 安装 Docker 和 Docker Compose
install_docker() {
    echo -e "${GREEN}检查并安装 Docker 和 Docker Compose...${RESET}"
    if ! command -v docker &> /dev/null; then
        echo -e "${GREEN}安装 Docker...${RESET}"
        curl -fsSL https://get.docker.com | sudo bash
        sudo systemctl enable --now docker
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}安装 Docker Compose...${RESET}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

# 创建虚拟环境并安装依赖
create_virtualenv() {
    check_python_venv
    echo -e "${GREEN}创建虚拟环境并安装依赖...${RESET}"
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip
    pip install docker requests # 直接安装必要的依赖
}

# 安装 NapthaAI 节点
install_node() {
    install_docker
    echo -e "${GREEN}安装 NapthaAI 节点...${RESET}"
    if [ ! -d "$INSTALL_DIR" ]; then
        git clone https://github.com/NapthaAI/naptha-node.git "$INSTALL_DIR"
    fi
    cd "$INSTALL_DIR"

    # 创建虚拟环境并安装依赖
    create_virtualenv

    # 复制 .env 配置文件
    if [ ! -f ".env" ]; then
        echo -e "${GREEN}创建 .env 配置文件...${RESET}"
        cp .env.example .env
        sed -i 's/^LAUNCH_DOCKER=.*/LAUNCH_DOCKER=true/' .env
        sed -i 's/^LLM_BACKEND=.*/LLM_BACKEND=ollama/' .env
        sed -i 's/^youruser=.*/youruser=root/' .env  # 设置为 root 用户
    fi

    # 启动 NapthaAI 节点
    echo -e "${GREEN}启动 NapthaAI 节点...${RESET}"
    bash launch.sh

    echo -e "${GREEN}NapthaAI 节点已成功启动！${RESET}"
    echo -e "访问地址: ${YELLOW}http://$(hostname -I | awk '{print $1}'):7001${RESET}"
}

# 导出 PRIVATE_KEY
export_private_key() {
    PEM_FILE="$INSTALL_DIR/moncici.pem"
    if [ -f "$PEM_FILE" ]; then
        PRIVATE_KEY=$(cat "$PEM_FILE")
        if [ -n "$PRIVATE_KEY" ]; then
            echo -e "${GREEN}您的 PRIVATE_KEY:${RESET} ${YELLOW}$PRIVATE_KEY${RESET}"
        else
            echo -e "${RED}未找到 PRIVATE_KEY，请确认节点已安装并正确配置。${RESET}"
        fi
    else
        echo -e "${RED}未找到 PEM 文件，节点可能未安装！${RESET}"
    fi
}

# 查看日志
view_logs() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${GREEN}显示 NapthaAI 日志...${RESET}"
        cd "$INSTALL_DIR"
        docker-compose logs -f --tail=200
    else
        echo -e "${RED}未找到 NapthaAI 节点，请先安装！${RESET}"
    fi
}

# 停止并删除节点容器
stop_and_remove_containers() {
    echo -e "${YELLOW}正在停止并删除节点容器...${RESET}"
    docker-compose down
}

# 卸载 NapthaAI
uninstall_node() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}正在停止并删除 NapthaAI 节点的容器和所有文件...${RESET}"
        stop_and_remove_containers
        cd ~
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}NapthaAI 节点已成功卸载，所有容器已删除！${RESET}"
    else
        echo -e "${RED}未找到 NapthaAI 节点，无需卸载。${RESET}"
    fi
}

# 菜单
while true; do
    echo -e "1. 安装 NapthaAI 节点"
    echo -e "2. 导出 PRIVATE_KEY"
    echo -e "3. 查看日志 (显示最后 200 行)"
    echo -e "4. 卸载 NapthaAI"
    echo -e "5. 更换 PEM 文件中的私钥并重新启动节点"
    echo -e "0. 退出"
    read -p "请选择操作: " choice

    case "$choice" in
        1) install_node ;;
        2) export_private_key ;;
        3) view_logs ;;
        4) uninstall_node ;;
        5) 
            # 更换 PEM 文件中的私钥并重新启动节点
            replace_private_key_in_pem
            stop_and_remove_containers
            bash "$INSTALL_DIR/launch.sh"
            echo -e "${GREEN}密钥已更换并重新启动节点！${RESET}"
            ;;
        0) echo -e "${GREEN}退出脚本。${RESET}"; exit 0 ;;
        *) echo -e "${RED}无效选项，请重新输入！${RESET}" ;;
    esac
done
