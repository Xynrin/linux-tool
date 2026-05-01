#!/bin/bash
# LT_ID=tool
# LT_NAME=全局命令打包
# LT_CATEGORY=系统工具
# LT_DESC=将指定 sh 文件打包成全局命令
# LT_VERSION=0.1.0
# LT_AUTHOR=Xynrin
# LT_DEPS=bash,sudo,coreutils
# LT_DANGEROUS=true

# Description: 将指定路径的sh文件打包成全局命令（usr/local/bin）
# 用途：将指定路径的sh文件打包成全局命令
# 使用方法：tool

# MIT License
#
# Copyright (c) 2025 Xiaoxinyun2008
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

TARGET_DIR="/usr/local/bin"
DESC_FILE="$TARGET_DIR/.tool_descriptions"

# 确保说明文件存在并设置合适权限
if [ ! -f "$DESC_FILE" ]; then
    sudo touch "$DESC_FILE"
    sudo chmod 644 "$DESC_FILE"
fi

show_menu() {
    echo "=============================="
    echo "🌐 全球命令管理工具"
    echo "=============================="
    echo "1. 选择并安装 .sh 文件为全局命令（支持相对/绝对路径）"
    echo "2. 修改已有命令名或说明"
    echo "3. 卸载全局命令"
    echo "4. 列出所有命令及说明"
    echo "0. 退出"
    echo "=============================="
}

list_commands() {
   
    echo "📁 实际安装的命令文件："
    found_files=false
    for file in "$TARGET_DIR"/*; do
        basename=$(basename "$file")
        if [ "$basename" != ".tool_descriptions" ] && [ -x "$file" ]; then
            # 检查是否有对应的描述
            description=$(grep "^$basename:" "$DESC_FILE" | cut -d':' -f2-)
            if [ -n "$description" ]; then
                echo "  ✓ $basename: $description"
            else
                echo "  ⚠ $basename (无描述)"
            fi
            found_files=true
        fi
    done
    if [ "$found_files" = false ]; then
        echo "  （无命令文件）"
    fi
}

install_command() {
    list_commands
    echo "------------------------------"
    read -p "请输入要安装的 .sh 文件路径（支持相对路径和绝对路径）: " SCRIPT_PATH

    # 使用 realpath 或 readlink 来规范化路径，如果这些工具不可用则手动处理
    if command -v realpath >/dev/null 2>&1; then
        FULL_SCRIPT_PATH=$(realpath "$SCRIPT_PATH" 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "❌ 错误：指定的路径无效或文件不存在"
            return
        fi
    elif command -v readlink >/dev/null 2>&1; then
        FULL_SCRIPT_PATH=$(readlink -f "$SCRIPT_PATH" 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "❌ 错误：指定的路径无效或文件不存在"
            return
        fi
    else
        # 如果没有这些工具，手动规范化路径
        if [[ "$SCRIPT_PATH" == /* ]]; then
            # 绝对路径，直接使用
            FULL_SCRIPT_PATH="$SCRIPT_PATH"
        else
            # 相对路径，转换为绝对路径
            FULL_SCRIPT_PATH="$(pwd)/$SCRIPT_PATH"
        fi

        if [ ! -f "$FULL_SCRIPT_PATH" ]; then
            echo "❌ 错误：文件不存在: $FULL_SCRIPT_PATH"
            return
        fi
    fi

    if [ ! -f "$FULL_SCRIPT_PATH" ]; then
        echo "❌ 错误：文件不存在: $FULL_SCRIPT_PATH"
        return
    fi

    # 检查扩展名
    if [[ "$FULL_SCRIPT_PATH" != *.sh ]]; then
        echo "❌ 错误：文件必须是 .sh 文件"
        return
    fi

    # 设置默认命令名
    DEFAULT_NAME=$(basename "$FULL_SCRIPT_PATH" .sh)
    read -p "请输入希望使用的命令名（回车使用默认: $DEFAULT_NAME）: " COMMAND_NAME
    COMMAND_NAME=${COMMAND_NAME:-$DEFAULT_NAME}

    read -p "请输入命令说明（支持中文）: " COMMAND_DESC

    # 检查命令名是否合法
    if [[ ! "$COMMAND_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "❌ 错误：命令名只能包含字母、数字、下划线和连字符"
        return
    fi

    chmod +x "$FULL_SCRIPT_PATH"
    sudo cp "$FULL_SCRIPT_PATH" "$TARGET_DIR/$COMMAND_NAME"

    # 检查复制是否成功
    if [ $? -ne 0 ]; then
        echo "❌ 错误：复制文件失败"
        return
    fi

    sudo chmod +x "$TARGET_DIR/$COMMAND_NAME"

    # 更新说明
    grep -v "^$COMMAND_NAME:" "$DESC_FILE" | sudo tee "$DESC_FILE.tmp" > /dev/null
    echo "$COMMAND_NAME:$COMMAND_DESC" | sudo tee -a "$DESC_FILE.tmp" > /dev/null
    sudo mv "$DESC_FILE.tmp" "$DESC_FILE"

    echo "✅ 安装完成！现在可以输入 '$COMMAND_NAME' 来运行该脚本"
    echo "📁 原始文件路径: $FULL_SCRIPT_PATH"
}

modify_command() {
    list_commands
    echo "------------------------------"
    read -p "请输入要修改的命令名: " OLD_NAME
    if [ ! -f "$TARGET_DIR/$OLD_NAME" ]; then
        echo "❌ 错误：命令不存在"
        return
    fi
    read -p "请输入新的命令名（直接回车保持不变）: " NEW_NAME
    read -p "请输入新的说明（直接回车保持不变）: " NEW_DESC

    # 获取旧描述
    OLD_DESC=$(grep "^$OLD_NAME:" "$DESC_FILE" | cut -d':' -f2-)
    
    # 如果没有输入新值，则保留原值
    if [ -z "$NEW_DESC" ]; then
        NEW_DESC="$OLD_DESC"
    fi
    
    if [ -n "$NEW_NAME" ]; then
        # 检查新命令名是否合法
        if [[ ! "$NEW_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "❌ 错误：命令名只能包含字母、数字、下划线和连字符"
            return
        fi
        
        sudo mv "$TARGET_DIR/$OLD_NAME" "$TARGET_DIR/$NEW_NAME"
        # 检查重命名是否成功
        if [ $? -ne 0 ]; then
            echo "❌ 错误：重命名命令失败"
            return
        fi
        
        # 更新描述文件中的命令名和描述
        grep -v "^$OLD_NAME:" "$DESC_FILE" | sudo tee "$DESC_FILE.tmp" > /dev/null
        echo "$NEW_NAME:$NEW_DESC" | sudo tee -a "$DESC_FILE.tmp" > /dev/null
        sudo mv "$DESC_FILE.tmp" "$DESC_FILE"
    else
        # 只更新描述，不改变命令名
        grep -v "^$OLD_NAME:" "$DESC_FILE" | sudo tee "$DESC_FILE.tmp" > /dev/null
        echo "$OLD_NAME:$NEW_DESC" | sudo tee -a "$DESC_FILE.tmp" > /dev/null
        sudo mv "$DESC_FILE.tmp" "$DESC_FILE"
    fi

    echo "✅ 修改完成！"
}

uninstall_command() {
    list_commands
    echo "------------------------------"
    read -p "请输入要卸载的命令名: " COMMAND_NAME
    if [ ! -f "$TARGET_DIR/$COMMAND_NAME" ]; then
        echo "❌ 错误：命令不存在"
        return
    fi
    sudo rm "$TARGET_DIR/$COMMAND_NAME"
    
    # 检查删除是否成功
    if [ $? -ne 0 ]; then
        echo "❌ 错误：删除命令失败"
        return
    fi
    
    grep -v "^$COMMAND_NAME:" "$DESC_FILE" | sudo tee "$DESC_FILE.tmp" > /dev/null
    sudo mv "$DESC_FILE.tmp" "$DESC_FILE"
    echo "🗑️ 已卸载命令 '$COMMAND_NAME'"
}

while true; do
    clear
    show_menu
    read -p "请选择操作编号: " choice
    case $choice in
        1) install_command ;;
        2) modify_command ;;
        3) uninstall_command ;;
        4) list_commands ;;
        0) echo "👋 再见！"; break ;;
        *) echo "❌ 无效选项，请重新输入" ;;
    esac
    echo ""
    read -p "按回车键返回主菜单..."
done
