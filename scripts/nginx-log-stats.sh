#!/bin/bash
#
# nginx access log 统计脚本
# 自动识别真实客户端IP(行末引号内 X-Forwarded-For)，无则回退到行首代理IP
#
# Usage:
#   ./nginx-log-stats.sh [选项] <日志文件...>
#
# 选项:
#   -e, --exclude png,css,js    排除指定后缀(逗号分隔)
#   -o, --only-ext html        只统计指定后缀(逗号分隔)
#   --no-spider                排除爬虫/蜘蛛 UA
#   -t, --top N                每项统计只显示前 N 条(默认全部)
#   -s, --split                按文件分别统计(默认合并)
#   --proxy                    按代理/节点 IP 统计(默认按真实客户端 IP)
#   -g, --geo                  输出国内/境外 IP 分布(基于 APNIC 中国 IP 段)
#   -S, --list-spider          列出爬虫/程序化客户端明细(按名称、IP、国内外)
#   -h, --help                 显示帮助
#
# 示例:
#   ./nginx-log-stats.sh a.log b.log
#   ./nginx-log-stats.sh -o html *.log
#   ./nginx-log-stats.sh -e png,css,js,mp4 --no-spider *.log
#   ./nginx-log-stats.sh -o html -t 10 -s *.log
#   ./nginx-log-stats.sh -o html --geo *.log
#   ./nginx-log-stats.sh -S *.log              # 列出爬虫明细
#   ./nginx-log-stats.sh -S --geo -t 10 *.log  # 爬虫明细+国内外、取前10

set -e

EXCLUDE=""
ONLY_EXT=""
NO_SPIDER=false
TOP=0
SPLIT=false
BY_PROXY=false
GEO=false
LIST_SPIDER=false

while [ $# -gt 0 ]; do
    case "$1" in
        -e|--exclude)  EXCLUDE="$2"; shift 2;;
        -o|--only-ext) ONLY_EXT="$2"; shift 2;;
        --no-spider)   NO_SPIDER=true; shift;;
        -t|--top)      TOP="$2"; shift 2;;
        -s|--split)    SPLIT=true; shift;;
        --proxy)       BY_PROXY=true; shift;;
        -g|--geo)      GEO=true; shift;;
        -S|--list-spider) LIST_SPIDER=true; shift;;
        -h|--help)     sed -n '3,20p' "$0"; exit 0;;
        --)            shift; break;;
        -*)            echo "未知选项: $1"; exit 1;;
        *)             break;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES=("$@")
if [ ${#FILES[@]} -eq 0 ]; then
    sed -n '3,20p' "$0"
    exit 1
fi

# 统计单个/多个文件的核心函数
# 参数: 文件列表(可多个)
run_stats() {
    local files=("$@")
    local head_cmd="cat"
    [ "$TOP" != "0" ] && head_cmd="head -n $TOP"

    # awk: 解析 + 过滤，输出 "IP\tURL"
    local data
    data=$(awk -F'"' \
        -v exclude="$EXCLUDE" \
        -v only="$ONLY_EXT" \
        -v nospider="$NO_SPIDER" \
        -v byproxy="$BY_PROXY" '
    BEGIN {
        if (exclude != "") ne = split(exclude, ex, ",")
        if (only    != "") no = split(only, on, ",")
    }
    {
        req = $2
        ua  = $6
        xff = $(NF - 1)
        split($1, a, " ")
        proxy = a[1]
        realip = (xff ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) ? xff : proxy
        ip = (byproxy == "true") ? proxy : realip
        n = split(req, r, " ")
        method = r[1]; url = r[2]
        if (url == "") next
        sub(/\?.*/, "", url)
        # 取最后一个 . 后的内容作为后缀
        m = split(url, p, "."); ext = (m > 1) ? tolower(p[m]) : ""
        skip = 0
        if (ne) for (i = 1; i <= ne; i++) if (ext == tolower(ex[i])) { skip = 1; break }
        if (no) {
            hit = 0
            for (i = 1; i <= no; i++) if (ext == tolower(on[i])) { hit = 1; break }
            if (!hit) skip = 1
        }
        if (nospider == "true" && ua ~ /[Bb]ot|[Ss]pider|[Cc]rawl|[Ss]lurp|[Ff]etch/) skip = 1
        if (!skip) print ip "\t" url
    }' "${files[@]}")

    local total
    total=$(printf '%s\n' "$data" | grep -c . || true)

    echo "总访问次数: $total"
    echo ""
    echo "按真实客户端 IP 排名:"
    printf '%s\n' "$data" | cut -f1 | sort | uniq -c | sort -rn | $head_cmd \
        | awk '{printf "  %2d  %s  (%.1f%%)\n", $1, $2, $1*100/'"$total"'}'
    echo ""
    echo "去重 IP 数: $(printf '%s\n' "$data" | cut -f1 | sort -u | grep -c . || true)"
    echo ""
    echo "按页面 URL 排名:"
    printf '%s\n' "$data" | cut -f2 | sort | uniq -c | sort -rn | $head_cmd \
        | awk '{printf "  %2d  %s\n", $1, $2}'

    if [ "$GEO" = true ]; then
        local label="真实客户端 IP"
        if [ "$BY_PROXY" = true ]; then label="代理/节点 IP"; fi
        echo ""
        echo "国内/境外 IP 分布(基于${label}):"
        local ips geo cn foreign
        ips=$(printf '%s\n' "$data" | cut -f1 | sort -u | grep . || true)
        if [ -z "$ips" ]; then
            echo "  无可用 IP"
        else
            geo=$(printf '%s\n' "$ips" | python3 "$SCRIPT_DIR/ip-cn-check.py" 2>/dev/null || true)
            if [ -z "$geo" ]; then
                echo "  (解析失败,请确认 python3 可用且已联网下载 APNIC 数据)"
            else
                cn=$(printf '%s\n' "$geo" | awk -F'\t' '$2=="国内"{c++} END{print c+0}')
                foreign=$(printf '%s\n' "$geo" | awk -F'\t' '$2=="境外"{c++} END{print c+0}')
                echo "  国内 IP: $cn 个"
                echo "  境外 IP: $foreign 个"
                echo "  国内 IP 列表:"
                printf '%s\n' "$geo" | awk -F'\t' '$2=="国内"{print "    "$1}' | $head_cmd
                echo "  境外 IP 列表:"
                printf '%s\n' "$geo" | awk -F'\t' '$2=="境外"{print "    "$1}' | $head_cmd
            fi
        fi
    fi

    if [ "$LIST_SPIDER" = true ]; then
        echo ""
        echo "爬虫/程序化客户端识别(全量,不受后缀过滤影响):"
        local total_all spider sc
        total_all=$(cat "${files[@]}" | grep -c . || true)
        spider=$(awk -F'"' '
        function name(u,   cnt,i,n){
            cnt=split("Googlebot Baiduspider bingbot YandexBot CCBot PetalBot Bytespider 360Spider Sogou SemrushBot AhrefsBot DuckDuckBot facebookexternalhit Twitterbot MJ12bot DotBot MauiBot GPTBot ClaudeBot Amazonbot Applebot LinkedInBot YoudaoBot",n," ")
            for(i=1;i<=cnt;i++) if(index(u,n[i])) return n[i]
            if(u ~ /[Bb]ot|[Ss]pider|[Cc]rawl|[Ss]lurp|[Ff]etch|[Ss]craper/) return "其他爬虫"
            if(u ~ /Java\/|Python-|curl\/|Go-http-client|okhttp|Apache-HttpClient|Wget|libwww|scrapy/) return "程序化客户端"
            return ""
        }
        { u=$6; ip=$(NF-1); gsub(/^[ \t]+|[ \t]+$/,"",ip); n=name(u); if(n!="") print n "\t" ip }
        ' "${files[@]}")
        sc=$(printf '%s\n' "$spider" | grep -c . || true)
        echo "  爬虫请求: $sc / $total_all"
        echo ""
        echo "  按爬虫名称:"
        printf '%s\n' "$spider" | cut -f1 | sort | uniq -c | sort -rn | $head_cmd
        echo ""
        echo "  爬虫按真实IP(次数/IP):"
        printf '%s\n' "$spider" | cut -f2 | sort | uniq -c | sort -rn | $head_cmd | sed 's/^/    /'
        if [ "$GEO" = true ] && [ -n "$sc" ] && [ "$sc" != "0" ]; then
            echo "  爬虫IP 国内外:"
            printf '%s\n' "$spider" | cut -f2 | sort -u | python3 "$SCRIPT_DIR/ip-cn-check.py" 2>/dev/null | sed 's/^/    /'
        fi
    fi
}

if [ "$SPLIT" = true ]; then
    for f in "${FILES[@]}"; do
        echo "========================================================"
        echo "文件: $f"
        echo "========================================================"
        run_stats "$f"
        echo ""
    done
else
    echo "========================================================"
    echo "文件: ${FILES[*]}"
    echo "========================================================"
    run_stats "${FILES[@]}"
fi
