#!/usr/bin/env python3
"""
IP 国内/境外 离线判断
- 数据源: APNIC delegated(权威、免费), 提取中国(CN) IP 段
- 本地缓存 7 天, 离线可用
- 仅依赖 python3 标准库

用法:
    echo -e "8.8.8.8\\n114.114.114.114" | python3 ip-cn-check.py
输出:
    8.8.8.8<TAB>境外
    114.114.114.114<TAB>国内
"""
import sys
import os
import time
import urllib.request
import ipaddress
import bisect

CACHE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "var")
V4_CACHE = os.path.join(CACHE_DIR, "apnic-cn-v4.txt")
V6_CACHE = os.path.join(CACHE_DIR, "apnic-cn-v6.txt")
URL = "https://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest"
TTL = 7 * 24 * 3600  # 缓存 7 天


def need_refresh(path):
    return not os.path.exists(path) or (time.time() - os.path.getmtime(path)) > TTL


def refresh():
    os.makedirs(CACHE_DIR, exist_ok=True)
    print("正在从 APNIC 下载中国 IP 段数据(首次较慢)...", file=sys.stderr)
    data = urllib.request.urlopen(URL, timeout=120).read().decode("ascii", "ignore")
    v4 = []   # [start_int, end_int]
    v6 = []   # IPv6Network
    for line in data.splitlines():
        if not line or line.startswith("#"):
            continue
        p = line.split("|")
        if len(p) < 7 or p[0] != "apnic" or p[1] != "CN":
            continue
        if p[2] == "ipv4":
            try:
                s = int(ipaddress.IPv4Address(p[3]))
                c = int(p[4])
            except ValueError:
                continue
            v4.append([s, s + c - 1])
        elif p[2] == "ipv6":
            try:
                v6.append(ipaddress.IPv6Network(p[3] + "/" + p[4]))
            except ValueError:
                continue
    # 合并相邻/重叠的 ipv4 区间
    v4.sort()
    merged = []
    for s, e in v4:
        if merged and s <= merged[-1][1] + 1:
            merged[-1][1] = max(merged[-1][1], e)
        else:
            merged.append([s, e])
    with open(V4_CACHE, "w") as f:
        for s, e in merged:
            f.write(f"{s} {e}\n")
    with open(V6_CACHE, "w") as f:
        for net in v6:
            f.write(str(net) + "\n")
    print(f"缓存已更新: {len(merged)} 条 IPv4 区间, {len(v6)} 条 IPv6 前缀", file=sys.stderr)


def load():
    if need_refresh(V4_CACHE) or need_refresh(V6_CACHE):
        refresh()
    starts, ends = [], []
    with open(V4_CACHE) as f:
        for line in f:
            s, e = line.split()
            starts.append(int(s))
            ends.append(int(e))
    v6 = []
    if os.path.exists(V6_CACHE):
        with open(V6_CACHE) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        v6.append(ipaddress.IPv6Network(line))
                    except ValueError:
                        pass
    return starts, ends, v6


def classify(ip, starts, ends, v6):
    try:
        obj = ipaddress.ip_address(ip.strip())
    except ValueError:
        return "无效IP"
    if isinstance(obj, ipaddress.IPv4Address):
        i = int(obj)
        idx = bisect.bisect_right(starts, i) - 1
        return "国内" if idx >= 0 and i <= ends[idx] else "境外"
    return "国内" if any(obj in net for net in v6) else "境外"


def main():
    starts, ends, v6 = load()
    for line in sys.stdin:
        ip = line.strip()
        if not ip:
            continue
        print(f"{ip}\t{classify(ip, starts, ends, v6)}")


if __name__ == "__main__":
    main()
