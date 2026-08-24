#!/usr/bin/env bash
# 促销建议 Skill 安装脚本（macOS / Linux）
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/ligz1990/fangopenapi/main/skills/install.sh | bash
#   curl -fsSL ... | bash -s -- --help

set -uo pipefail

# ============ 配置 ============
# 你的 GitHub 仓库 raw 地址前缀
REPO_BASE="https://raw.githubusercontent.com/ligz1990/fangopenapi/main/skills"
SKILL_ZIP="promotion-suggestion.zip"
SKILL_NAME="promotion-suggestion"

# ============ 函数定义 ============
usage() {
    cat <<EOF
促销建议 Skill 安装脚本

用法:
  curl -fsSL https://raw.githubusercontent.com/ligz1990/fangopenapi/main/skills/install.sh | bash
  curl -fsSL ... | bash -s -- --help

选项:
  --skills-dir <目录>  安装到指定目录（默认自动检测）
  -h, --help           显示帮助
EOF
}

detect_skills_dir() {
    # 优先级：显式参数 > 环境变量 > 各 agent 默认目录
    if [[ -n "${SKILLS_DIR_EXPLICIT:-}" ]]; then
        printf '%s\n' "$SKILLS_DIR_EXPLICIT"
    elif [[ -n "${WORKBUDDY_HOME:-}" ]]; then
        printf '%s/skills\n' "${WORKBUDDY_HOME%/}"
    elif [[ -n "${HERMES_HOME:-}" ]]; then
        printf '%s/skills\n' "${HERMES_HOME%/}"
    elif [[ -n "${OPENCLAW_HOME:-}" ]]; then
        printf '%s/skills\n' "${OPENCLAW_HOME%/}"
    elif [[ -n "${CODEX_THREAD_ID:-}" ]]; then
        printf '%s/.codex/skills\n' "$HOME"
    elif [[ -n "${CLAUDE_CODE:-}${CLAUDECODE:-}" ]]; then
        printf '%s/.claude/skills\n' "$HOME"
    else
        printf '%s/.agents/skills\n' "$HOME"
    fi
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "错误: 需要 $1 但未安装" >&2
        exit 1
    fi
}

fatal_error() {
    echo "" >&2
    echo "错误: $1" >&2
    if [[ $# -gt 1 ]]; then
        shift
        for msg in "$@"; do
            echo "  - $msg" >&2
        done
    fi
    echo "" >&2
    exit 1
}

download() {
    local url="$1" output="$2"
    local retries=3 n=0
    while [[ $n -lt $retries ]]; do
        [[ $n -gt 0 ]] && sleep 2
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL --retry 2 --connect-timeout 30 --max-time 300 \
                -H "User-Agent: fangopenapi-skills-installer/curl-bash" \
                "$url" -o "$output" && return 0
        elif command -v wget >/dev/null 2>&1; then
            wget -q --tries=2 --connect-timeout=30 --read-timeout=300 \
                --user-agent="fangopenapi-skills-installer/curl-bash" \
                "$url" -O "$output" && return 0
        else
            echo "错误: 需要 curl 或 wget" >&2
            exit 1
        fi
        rm -f "$output" 2>/dev/null || true
        n=$((n + 1))
    done
    return 1
}

cleanup() {
    [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR" 2>/dev/null || true
}

# ============ 参数解析 ============
SKILLS_DIR_EXPLICIT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --skills-dir)
            if [[ $# -lt 2 || -z "$2" ]]; then
                echo "错误: --skills-dir 需要目录参数" >&2
                usage
                exit 1
            fi
            SKILLS_DIR_EXPLICIT="$2"
            shift 2
            ;;
        -*)
            echo "错误: 未知参数 $1" >&2
            usage
            exit 1
            ;;
        *)
            # 忽略额外参数（保持兼容）
            shift
            ;;
    esac
done

# ============ 主流程 ============
TMP_DIR="$(mktemp -d -t fang-skills-install.XXXXXX)"
trap cleanup EXIT INT TERM

require_cmd unzip

SKILLS_DIR="$(detect_skills_dir)"
echo "==> Skill 安装目录: $SKILLS_DIR"
mkdir -p "$SKILLS_DIR"

skill_dir="$SKILLS_DIR/$SKILL_NAME"
archive_file="$TMP_DIR/$SKILL_ZIP"
url="$REPO_BASE/$SKILL_ZIP"

echo "==> 安装 $SKILL_NAME..."

# 下载
echo "  下载中: $url"
if ! download "$url" "$archive_file"; then
    fatal_error "下载 $SKILL_NAME 失败" "URL: $url"
fi

# 检查文件大小
file_size=$(wc -c <"$archive_file" 2>/dev/null || echo "0")
if [[ "$file_size" -lt 1024 ]]; then
    fatal_error "下载文件过小 ($file_size bytes)，可能已损坏"
fi

# 解压
echo "  解压中..."
mkdir -p "$skill_dir"
unzip -oq "$archive_file" -d "$skill_dir" || fatal_error "解压失败"

# 检查必需文件
if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    fatal_error "压缩包格式错误（缺少 SKILL.md）"
fi

echo "  ✓ 安装成功"
echo ""
echo "=== 安装完成 ==="
echo "  • $SKILL_NAME"
echo ""
echo "位置: $SKILLS_DIR"
