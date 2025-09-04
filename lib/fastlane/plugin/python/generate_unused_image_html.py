#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re
import os
from datetime import datetime

def generate_fengniao_html(title, input_file, output_file):
    try:
        # 读取 FengNiao 结果
        if os.path.exists(input_file):
            with open(input_file, 'r', encoding='utf-8') as f:
                fengniao_content = f.read()
        else:
            fengniao_content = "无扫描结果文件"
        
        # 解析 FengNiao 输出并生成表格行
        rows_html = ""
        unused_images = []
        lines = fengniao_content.strip().split('\n') if fengniao_content.strip() else []
        
        for line in lines:
            line = line.strip()
            # 跳过空行和系统信息
            if not line or line.startswith('[') or line.startswith('Searching') or line.startswith('Found'):
                continue
            
            # FengNiao 输出格式: "226.56 KB /path/to/image.png"
            # 使用正则表达式匹配：文件大小 + 空格 + 文件路径
            match = re.match(r'^(\d+(?:\.\d+)?\s*[KMGT]?B)\s+(.+\.(png|jpg|jpeg|gif|pdf|svg))$', line, re.IGNORECASE)
            
            if match:
                file_size = match.group(1)
                file_path = match.group(2)
                file_name = os.path.basename(file_path)
                file_ext = os.path.splitext(file_name)[1].lower()
                
                unused_images.append({
                    'name': file_name,
                    'path': file_path,
                    'size': file_size,
                    'ext': file_ext
                })
                
                # 生成表格行
                rows_html += f"""
                <tr>
                    <td class="file-name">{file_name}</td>
                    <td class="file-path">{file_path}</td>
                    <td class="file-size">{file_size}</td>
                    <td class="file-type">{file_ext}</td>
                </tr>"""
            else:
                # 备用解析：如果正则匹配失败，检查是否包含图片扩展名
                if re.search(r'\.(png|jpg|jpeg|gif|pdf|svg)$', line, re.IGNORECASE):
                    # 可能是只有路径没有大小的格式
                    file_path = line
                    file_name = os.path.basename(file_path)
                    file_ext = os.path.splitext(file_name)[1].lower()
                    file_size = "未知"
                    
                    unused_images.append({
                        'name': file_name,
                        'path': file_path,
                        'size': file_size,
                        'ext': file_ext
                    })
                    
                    rows_html += f"""
                    <tr>
                        <td class="file-name">{file_name}</td>
                        <td class="file-path">{file_path}</td>
                        <td class="file-size">{file_size}</td>
                        <td class="file-type">{file_ext}</td>
                    </tr>"""

        # 统计信息
        total_images = len(unused_images)
        
        # 计算总大小
        total_size = calculate_total_size(unused_images)
        
        # 生成完整的 HTML
        html_content = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }}
        .header {{
            background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%);
            color: white;
            padding: 30px;
            text-align: center;
            position: relative;
        }}
        .header h1 {{
            margin: 0;
            font-size: 2em;
            font-weight: 300;
        }}
        .header-timestamp {{
            position: absolute;
            bottom: 15px;
            right: 20px;
            font-size: 0.8em;
            opacity: 0.8;
        }}
        .stats {{
            display: flex;
            justify-content: center;
            gap: 30px;
            margin-top: 20px;
        }}
        .stat-item {{
            text-align: center;
        }}
        .stat-number {{
            font-size: 2em;
            font-weight: bold;
            margin-bottom: 5px;
        }}
        .stat-label {{
            font-size: 0.9em;
            opacity: 0.9;
        }}
        .content {{
            padding: 30px;
        }}
        table {{
            border-collapse: collapse;
            width: 100%;
            margin-top: 20px;
            table-layout: fixed; /* 固定表格布局 */
        }}
        th, td {{
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
            vertical-align: top;
            overflow: hidden; /* 隐藏溢出内容 */
        }}
        th {{
            background-color: #f8f9fa;
            font-weight: 600;
            color: #495057;
        }}
        /* 设置各列的宽度 */
        .file-name-header, .file-name {{
            width: 25%;
        }}
        .file-path-header, .file-path {{
            width: 45%;
            word-break: break-all; /* 长路径自动换行 */
            font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
            font-size: 0.85em;
            color: #6c757d;
        }}
        .file-size-header, .file-size {{
            width: 15%;
            text-align: center;
        }}
        .file-type-header, .file-type {{
            width: 15%;
            text-align: center;
        }}
        .no-issues {{
            text-align: center;
            padding: 50px;
            color: #28a745;
            font-size: 1.2em;
            background-color: #d4edda;
            border-radius: 8px;
            border: 1px solid #c3e6cb;
        }}
        tr:nth-child(even) {{
            background-color: #f8f9fa;
        }}
        tr:hover {{
            background-color: #e9ecef;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>{title}</h1>
            <div class="header-timestamp">
                报告生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
            </div>
            <div class="stats">
                <div class="stat-item">
                    <div class="stat-number">{total_images}</div>
                    <div class="stat-label">无用图片数量</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">{total_size}</div>
                    <div class="stat-label">总大小</div>
                </div>
            </div>
        </div>
        <div class="content">"""

        if total_images == 0:
            html_content += """
            <div class="no-issues">
                🎉 太棒了！没有发现无用的图片文件
            </div>"""
        else:
            # 添加表格
            html_content += """
            <table>
                <thead>
                    <tr>
                        <th class="file-name-header">文件名</th>
                        <th class="file-path-header">文件路径</th>
                        <th class="file-size-header">文件大小</th>
                        <th class="file-type-header">类型</th>
                    </tr>
                </thead>
                <tbody>"""
            
            # 添加表格行
            html_content += rows_html
            
            html_content += """
                </tbody>
            </table>"""

        html_content += """
        </div>
    </div>
</body>
</html>"""

        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        # 写入 HTML 文件
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"HTML 报告已生成: {output_file}")

    except Exception as e:
        print(f"生成 HTML 报告时出错: {e}")

def calculate_total_size(unused_images):
    """计算总文件大小"""
    total_bytes = 0
    
    for img in unused_images:
        size_str = img['size']
        if size_str == "未知":
            continue
            
        # 解析大小字符串，如 "226.56 KB"
        match = re.match(r'(\d+(?:\.\d+)?)\s*([KMGT]?B)', size_str, re.IGNORECASE)
        if match:
            size_value = float(match.group(1))
            size_unit = match.group(2).upper()
            
            # 转换为字节
            if size_unit == "B":
                total_bytes += size_value
            elif size_unit == "KB":
                total_bytes += size_value * 1024
            elif size_unit == "MB":
                total_bytes += size_value * 1024 * 1024
            elif size_unit == "GB":
                total_bytes += size_value * 1024 * 1024 * 1024
            elif size_unit == "TB":
                total_bytes += size_value * 1024 * 1024 * 1024 * 1024
    
    # 转换回易读格式
    if total_bytes < 1024:
        return f"{total_bytes:.1f} B"
    elif total_bytes < 1024 * 1024:
        return f"{total_bytes / 1024:.1f} KB"
    elif total_bytes < 1024 * 1024 * 1024:
        return f"{total_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{total_bytes / (1024 * 1024 * 1024):.1f} GB"

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("使用方法: python3 generate_fengniao_html.py <title> <input_file> <output_file>")
        sys.exit(1)
    
    title = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]
    
    generate_fengniao_html(title, input_file, output_file)
