#!/bin/bash
# LT_ID=fuck_rm
# LT_NAME=危险命令防护
# LT_CATEGORY=安全防护
# LT_DESC=防止误执行 rm/dd/mkfs 等危险命令
# LT_VERSION=0.1.0
# LT_AUTHOR=Xynrin
# LT_DEPS=bash,coreutils
# LT_DANGEROUS=true

# Description: Linux危险命令防护脚本，防止误执行危险的系统命令如rm、dd等
# 用途：防止误执行危险的系统命令
# 使用方法：fuck_rm

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

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "错误：请使用 sudo 运行此脚本"
    exit 1
fi

echo "=== Linux系统安全防护脚本 ==="
echo "此脚本将创建安全别名和包装函数来防止危险命令的误执行"
echo ""

# 备份原始配置
BACKUP_DIR="/root/safety_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "创建备份目录: $BACKUP_DIR"

# 创建全局安全配置文件
SAFETY_PROFILE="/etc/profile.d/command_safety.sh"

cat > "$SAFETY_PROFILE" << 'EOF'
# 危险命令安全包装函数

# 安全的rm函数
safe_rm() {
    # 检查是否尝试删除根目录
    for arg in "$@"; do
        if [[ "$arg" == "/" ]] || [[ "$arg" == "/*" ]] || [[ "$arg" == "/." ]]; then
            echo "❌ 安全警告：禁止删除根目录！"
            echo "如果确实需要，请使用原始命令：/bin/rm"
            return 1
        fi
    done
    
    # 检查是否使用了 -rf / 组合
    if [[ "$*" =~ -.*r.*f.*/$ ]] || [[ "$*" =~ -.*f.*r.*/$ ]]; then
        echo "❌ 安全警告：检测到危险的 rm -rf / 模式！"
        return 1
    fi
    
    # 执行原始rm命令
    /bin/rm "$@"
}

# 安全的dd函数
safe_dd() {
    # 检查输出目标是否为硬盘设备
    if [[ "$*" =~ of=/dev/(sd[a-z]|nvme[0-9]n[0-9]|hd[a-z])$ ]]; then
        echo "❌ 安全警告：禁止直接写入磁盘设备！"
        echo "这可能会销毁所有数据。如果确实需要，请使用：/bin/dd"
        return 1
    fi
    /bin/dd "$@"
}

# 安全的mkfs函数
safe_mkfs() {
    echo "❌ 安全警告：mkfs命令已被限制"
    echo "格式化磁盘是危险操作，如果确实需要，请使用完整路径："
    echo "  /sbin/mkfs.ext4 或其他格式化命令"
    return 1
}

# 安全的chmod函数
safe_chmod() {
    # 检查是否尝试递归修改根目录权限
    if [[ "$*" =~ -R.*777.*/ ]] || [[ "$*" =~ 777.*-R.*/ ]]; then
        echo "❌ 安全警告：禁止递归设置根目录为777权限！"
        return 1
    fi
    /bin/chmod "$@"
}

# Fork炸弹检测（这个比较难通过别名阻止，主要是教育提醒）
forkbomb() {
    echo "❌ 危险：Fork炸弹会导致系统崩溃，已阻止执行"
    return 1
}

# 创建别名
alias rm='safe_rm'
alias dd='safe_dd'
alias mkfs='safe_mkfs'
alias mkfs.ext4='safe_mkfs'
alias mkfs.ext3='safe_mkfs'
alias mkfs.xfs='safe_mkfs'
alias chmod='safe_chmod'

# 导出函数使其在子shell中可用
export -f safe_rm safe_dd safe_mkfs safe_chmod

echo "✅ 系统安全防护已加载"
EOF

chmod 644 "$SAFETY_PROFILE"
echo "✅ 已创建安全配置文件: $SAFETY_PROFILE"

# 为当前用户的bashrc添加配置
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo ~$SUDO_USER)
    USER_BASHRC="$USER_HOME/.bashrc"
    
    if [ -f "$USER_BASHRC" ]; then
        cp "$USER_BASHRC" "$BACKUP_DIR/bashrc.backup"
        echo "✅ 已备份用户bashrc到 $BACKUP_DIR"
    fi
fi

# 创建恢复脚本
RESTORE_SCRIPT="/root/restore_commands.sh"
cat > "$RESTORE_SCRIPT" << 'EOF'
#!/bin/bash
# 恢复原始命令的脚本

echo "移除安全别名配置..."
rm -f /etc/profile.d/command_safety.sh

echo "请重新登录以使更改生效"
echo "或运行: source ~/.bashrc"
EOF

chmod +x "$RESTORE_SCRIPT"
echo "✅ 已创建恢复脚本: $RESTORE_SCRIPT"

# 创建使用说明
cat << 'EOF'

=== 安装完成 ===

✅ 防护措施已启用，将在下次登录时生效

立即生效方法：
  source /etc/profile.d/command_safety.sh

被保护的命令：
  • rm -rf / - 禁止删除根目录
  • dd if=/dev/zero of=/dev/sda - 禁止直接写入磁盘
  • mkfs.* - 限制格式化命令
  • chmod -R 777 / - 禁止不安全的权限设置

绕过保护（需要时）：
  使用命令的完整路径，例如：
  • /bin/rm -rf /path
  • /bin/dd if=... of=...

恢复原始行为：
  sudo bash /root/restore_commands.sh

备份位置：
  $BACKUP_DIR

注意：
  • 这些保护措施主要防止误操作
  • root用户仍可使用完整路径执行原始命令
  • 建议配合其他安全措施（如定期备份、权限管理等）

EOF

echo "🎉 系统安全防护配置完成！"
