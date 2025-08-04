#!/bin/bash

# 日志功能测试脚本
echo "=== 日志功能测试 ==="

# 1. 测试日志目录创建
echo "1. 测试日志目录创建"
if [ -d "logs" ]; then
    echo "✅ 日志目录存在"
else
    echo "❌ 日志目录不存在"
    mkdir -p logs
fi

# 2. 测试日志文件生成
echo "2. 测试日志文件生成"
if [ -f "logs/rate-limiter.log" ]; then
    echo "✅ 日志文件存在"
    echo "   文件大小: $(du -h logs/rate-limiter.log | cut -f1)"
    echo "   行数: $(wc -l < logs/rate-limiter.log)"
else
    echo "❌ 日志文件不存在"
fi

# 3. 测试日志格式
echo "3. 测试日志格式"
if [ -f "logs/rate-limiter.log" ]; then
    echo "   第一条日志:"
    head -1 logs/rate-limiter.log | jq . 2>/dev/null || head -1 logs/rate-limiter.log
fi

# 4. 测试日志级别
echo "4. 测试日志级别统计"
make logs-stats

# 5. 测试日志查看功能
echo "5. 测试日志查看功能"
echo "   最后5行日志:"
tail -5 logs/rate-limiter.log

echo ""
echo "=== 日志功能测试完成 ==="
echo ""
echo "可用命令:"
echo "  make logs-view    - 实时查看日志"
echo "  make logs-stats   - 查看日志统计"
echo "  make logs-clean   - 清理日志文件"
echo "  ./scripts/view_logs.sh - 使用脚本查看日志" 