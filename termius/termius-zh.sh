#!/bin/bash

# Termius 汉化自动更新脚本
# 支持多平台和多种汉化版本选择
# 作者: 基于 ArcSurge/Termius-Pro-zh_CN 项目
# 版本: 2.0
# 更新日期: $(date +%Y-%m-%d)

# 定义全局变量
REPO_OWNER="ArcSurge"
REPO_NAME="Termius-Pro-zh_CN"
GITHUB_PROXY_PREFIX="https://github.181999.xyz/"

# 平台相关路径配置
declare -A PLATFORM_PATHS=(
    ["macos"]="/Applications/Termius.app/Contents/Resources"
    ["windows"]="C:/Users/$USER/AppData/Local/Programs/Termius/resources"
    ["linux"]="/opt/Termius/resources"
)

# 汉化版本配置
declare -A VERSION_TYPES=(
    ["1"]="localize"
    ["2"]="localize-trial" 
    ["3"]="localize-skip"
)

declare -A VERSION_DESCRIPTIONS=(
    ["1"]="仅汉化，自己有会员资格请下载此版本，普通用户也可下载"
    ["2"]="汉化+试用，消除碍眼的Upgrade now等按钮，试用用户可下载此版本"
    ["3"]="汉化+跳过登录，离线用户可下载此版本"
)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================"
echo -e "    Termius 汉化自动更新脚本 v2.0"
echo -e "    支持多平台和多种汉化版本"
echo -e "========================================${NC}"
echo ""

# 检测当前操作系统
detect_platform() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

# 获取用户选择的平台
select_platform() {
    local current_platform=$(detect_platform)
    
    echo -e "${YELLOW}请选择你的操作系统平台：${NC}"
    echo "1. macOS (当前检测到: $current_platform)"
    echo "2. Windows"
    echo "3. Linux"
    echo ""
    read -p "请输入选择 (1-3): " platform_choice
    
    case $platform_choice in
        1) echo "macos" ;;
        2) echo "windows" ;;
        3) echo "linux" ;;
        *) 
            echo -e "${RED}无效选择，使用检测到的平台: $current_platform${NC}"
            echo "$current_platform"
            ;;
    esac
}

# 获取用户选择的汉化版本
select_version_type() {
    echo -e "${YELLOW}请选择汉化版本类型：${NC}"
    echo "1. 仅汉化 - ${VERSION_DESCRIPTIONS[1]}"
    echo "2. 汉化+试用 - ${VERSION_DESCRIPTIONS[2]}"
    echo "3. 汉化+跳过登录 - ${VERSION_DESCRIPTIONS[3]}"
    echo ""
    read -p "请输入选择 (1-3): " version_choice
    
    case $version_choice in
        1|2|3) echo "${VERSION_TYPES[$version_choice]}" ;;
        *) 
            echo -e "${RED}无效选择，使用默认版本: localize-trial${NC}"
            echo "localize-trial"
            ;;
    esac
}

# 检查 Termius 安装路径
check_termius_installation() {
    local platform=$1
    local target_path=""
    
    case $platform in
        "macos")
            target_path="/Applications/Termius.app"
            ;;
        "windows")
            target_path="C:/Users/$USER/AppData/Local/Programs/Termius"
            ;;
        "linux")
            target_path="/opt/Termius"
            ;;
    esac
    
    if [ ! -d "$target_path" ]; then
        echo -e "${RED}错误：Termius 应用程序目录 '$target_path' 不存在。${NC}"
        echo "请确保 Termius 已正确安装。"
        return 1
    fi
    
    # 检查资源目录
    local resources_path=""
    case $platform in
        "macos")
            resources_path="$target_path/Contents/Resources"
            ;;
        "windows"|"linux")
            resources_path="$target_path/resources"
            ;;
    esac
    
    if [ ! -d "$resources_path" ]; then
        echo -e "${RED}错误：目标资源目录 '$resources_path' 不存在。${NC}"
        echo "这可能是 Termius 安装不完整或版本不兼容导致的。"
        return 1
    fi
    
    # 检查写入权限
    if [ ! -w "$resources_path" ]; then
        echo -e "${YELLOW}警告：对目标目录 '$resources_path' 没有写入权限。${NC}"
        echo "你可能需要使用 'sudo' 运行此脚本。"
        echo ""
    fi
    
    echo "$resources_path"
    return 0
}

# 强制关闭 Termius 进程
force_close_termius() {
    local platform=$1
    
    echo -e "${YELLOW}正在强制关闭 Termius 进程...${NC}"
    
    case $platform in
        "macos")
            # macOS 使用 pkill 和 killall
            pkill -f "Termius" 2>/dev/null || true
            killall "Termius" 2>/dev/null || true
            ;;
        "windows")
            # Windows 使用 taskkill
            taskkill //F //IM "Termius.exe" 2>/dev/null || true
            ;;
        "linux")
            # Linux 使用 pkill
            pkill -f "Termius" 2>/dev/null || true
            ;;
    esac
    
    # 等待进程完全关闭
    sleep 2
    echo -e "${GREEN}✔ Termius 进程已关闭${NC}"
}

# 备份原始文件
backup_original_file() {
    local resources_path=$1
    local backup_path="${resources_path}/app.asar.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "${resources_path}/app.asar" ]; then
        echo -e "${YELLOW}正在备份原始 app.asar 文件...${NC}"
        cp "${resources_path}/app.asar" "$backup_path"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✔ 原始文件已备份到: $backup_path${NC}"
        else
            echo -e "${RED}错误：备份文件失败${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}未找到原始 app.asar 文件，跳过备份${NC}"
    fi
}

# 获取最新发布标签
get_latest_release() {
    echo -e "${YELLOW}正在从 GitHub 获取最新的 Termius 发布信息...${NC}"
    
    local latest_release_info=$(curl -s "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest")
    
    if [ -z "$latest_release_info" ]; then
        echo -e "${RED}错误：无法获取最新的发布信息。请检查你的网络连接。${NC}"
        return 1
    fi
    
    # 从 JSON 响应中解析出 tag_name
    local latest_tag=$(echo "$latest_release_info" | grep -o '"tag_name": "[^"]*' | grep -o '[^"]*$' | head -n 1)
    
    if [ -z "$latest_tag" ]; then
        echo -e "${RED}错误：无法从 GitHub API 响应中解析出最新的标签名称。${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✔ 已成功获取最新标签：$latest_tag${NC}"
    echo "$latest_tag"
}

# 下载并替换文件
download_and_replace() {
    local platform=$1
    local version_type=$2
    local latest_tag=$3
    local resources_path=$4
    
    # 构建文件名
    local new_asar_file="app-${platform}-${version_type}.asar"
    local download_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${latest_tag}/${new_asar_file}"
    local proxy_url="${GITHUB_PROXY_PREFIX}${download_url}"
    
    echo -e "${YELLOW}正在下载汉化文件: $new_asar_file${NC}"
    echo -e "${BLUE}下载链接: $proxy_url${NC}"
    
    # 下载文件
    curl -L -o "${resources_path}/${new_asar_file}" "$proxy_url"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✔ 汉化文件下载成功${NC}"
        
        # 删除旧的 app.asar 文件
        if [ -f "${resources_path}/app.asar" ]; then
            rm -f "${resources_path}/app.asar"
        fi
        
        # 重命名新文件为 app.asar
        mv "${resources_path}/${new_asar_file}" "${resources_path}/app.asar"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✔ 文件替换成功${NC}"
            return 0
        else
            echo -e "${RED}错误：文件重命名失败${NC}"
            return 1
        fi
    else
        echo -e "${RED}错误：汉化文件下载失败${NC}"
        return 1
    fi
}

# macOS 专用：执行 osxfix.sh 功能
apply_macos_fix() {
    local resources_path=$1
    local asar_path="${resources_path}/app.asar"
    local termius_path="/Applications/Termius.app"
    
    echo -e "${YELLOW}正在应用 macOS 修复...${NC}"
    
    if [[ ! -e $asar_path ]]; then
        echo -e "${RED}错误：Termius app.asar 文件未找到！${NC}"
        return 1
    fi
    
    # 计算 asar 文件 hash
    local head_len=$(od -An -j 12 -N4 -D $asar_path)
    local asar_hash=$(dd bs=1 count=$head_len skip=16 if=$asar_path 2>/dev/null | shasum -a256 -b | cut -d ' ' -f 1)
    
    # 更新 Info.plist 中的 hash
    local info_path="$termius_path/Contents/Info.plist"
    local key_path="ElectronAsarIntegrity.Resources/appA_DOT_WAS_HEREasar.hash"
    
    plutil -replace "$key_path" -string "$asar_hash" "$info_path"
    echo -e "${GREEN}✔ 已更新: $info_path${NC}"
    
    # 更新 Frameworks 中的 hash
    if [[ -d "$termius_path/Contents/Frameworks" ]]; then
        for framework in "$termius_path/Contents/Frameworks"/*; do
            if [[ -d "$framework" ]]; then
                local framework_info="$framework/Versions/A/Resources/Info.plist"
                if [[ -f "$framework_info" ]]; then
                    plutil -replace "$key_path" -string "$asar_hash" "$framework_info"
                    echo -e "${GREEN}✔ 已更新: $framework_info${NC}"
                fi
            fi
        done
    fi
    
    # 重新签名应用
    echo -e "${YELLOW}正在重新签名应用...${NC}"
    local tempfile=$(mktemp)
    codesign --display --entitlements - --xml "$termius_path" > $tempfile
    
    # 移除可能导致问题的权限
    if plutil -extract comA_DOT_WAS_HEREappleA_DOT_WAS_HEREdeveloperA_DOT_WAS_HEREteam-identifier raw $tempfile >/dev/null 2>&1; then
        plutil -remove comA_DOT_WAS_HEREappleA_DOT_WAS_HEREdeveloperA_DOT_WAS_HEREteam-identifier $tempfile
    fi
    
    if plutil -extract keychain-access-groups raw $tempfile >/dev/null 2>&1; then
        plutil -remove keychain-access-groups $tempfile
    fi
    
    codesign --force --sign - --deep --entitlements $tempfile $termius_path
    rm $tempfile
    
    echo -e "${GREEN}✔ macOS 修复完成${NC}"
}

# 主程序逻辑
main() {
    # 1. 选择平台
    local platform=$(select_platform)
    echo -e "${GREEN}已选择平台: $platform${NC}"
    echo ""
    
    # 2. 选择汉化版本
    local version_type=$(select_version_type)
    echo -e "${GREEN}已选择版本: $version_type${NC}"
    echo ""
    
    # 3. 检查 Termius 安装
    local resources_path=$(check_termius_installation "$platform")
    if [ $? -ne 0 ]; then
        echo -e "${RED}脚本已终止。${NC}"
        exit 1
    fi
    echo -e "${GREEN}✔ Termius 安装检查通过${NC}"
    echo ""
    
    # 4. 获取最新版本
    local latest_tag=$(get_latest_release)
    if [ $? -ne 0 ]; then
        echo -e "${RED}脚本已终止。${NC}"
        exit 1
    fi
    echo ""
    
    # 5. 显示更新信息
    echo -e "${BLUE}========================================"
    echo -e "    更新信息确认"
    echo -e "========================================${NC}"
    echo -e "平台: $platform"
    echo -e "版本: $version_type"
    echo -e "最新标签: $latest_tag"
    echo -e "目标路径: $resources_path"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # 6. 确认继续
    read -p "是否继续执行更新？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}用户取消操作${NC}"
        exit 0
    fi
    echo ""
    
    # 7. 强制关闭 Termius
    force_close_termius "$platform"
    echo ""
    
    # 8. 备份原始文件
    backup_original_file "$resources_path"
    echo ""
    
    # 9. 下载并替换文件
    download_and_replace "$platform" "$version_type" "$latest_tag" "$resources_path"
    if [ $? -ne 0 ]; then
        echo -e "${RED}文件替换失败，脚本已终止。${NC}"
        exit 1
    fi
    echo ""
    
    # 10. macOS 特殊处理
    if [ "$platform" = "macos" ]; then
        apply_macos_fix "$resources_path"
        if [ $? -ne 0 ]; then
            echo -e "${RED}macOS 修复失败，脚本已终止。${NC}"
            exit 1
        fi
        echo ""
    fi
    
    # 11. 完成提示
    echo -e "${GREEN}========================================"
    echo -e "    Termius 汉化更新完成！"
    echo -e "========================================${NC}"
    echo -e "${YELLOW}请重新启动 Termius 应用程序以应用更改。${NC}"
    echo ""
    echo -e "${BLUE}注意事项：${NC}"
    echo -e "• 该汉化包仅适用于本地学习和测试"
    echo -e "• 使用汉化包可能会影响 Termius 的正常更新"
    echo -e "• 如需恢复原版，请使用备份文件"
    echo ""
}

# 执行主程序
main
