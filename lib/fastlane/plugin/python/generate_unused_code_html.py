import sys
import os
import re
from datetime import datetime

def generate_periphery_html(title, input_file, output_file):
    try:
        # 读取 Periphery 结果
        if os.path.exists(input_file):
            with open(input_file, 'r', encoding='utf-8') as f:
                periphery_content = f.read()
        else:
            periphery_content = "无扫描结果文件"

        # 用于存储所有的类型
        all_types = set()
        
        # 解析 Periphery 输出并生成表格行
        rows_html = ""
        lines = periphery_content.strip().split('\n') if periphery_content.strip() else []
        
        for line in lines:
            line = line.strip()
            # 跳过空行和系统警告
            if not line or line.startswith('*') or line.startswith('warning: When using') or line.startswith('warning: Declaration conflict'):
                continue
                
            # Periphery 输出格式: /path/to/file.swift:123:45: warning: Function 'getProducts()' is unused
            # 匹配模式: 文件路径:行号:列号: warning: 描述
            match = re.match(r"^(.*?):(\d+):(\d+):\s*warning:\s*(.+)$", line)
            if match:
                file_path = match.group(1)
                line_number = match.group(2)
                column_number = match.group(3)
                description = match.group(4)
                
                # 从描述中提取类型
                issue_type = extract_issue_type(description)
                all_types.add(issue_type)
                
                # 生成表格行
                rows_html += f"""
                <tr>
                    <td class="file-name">{os.path.basename(file_path)}</td>
                    <td class="line-number">{line_number}</td>
                    <td class="description">{description}</td>
                    <td class="issue-type">{issue_type}</td>
                </tr>"""
            else:
                # 如果格式不匹配，可能是其他格式的输出，尝试简单解析
                if "warning:" in line:
                    # 简单的备用解析
                    parts = line.split("warning:")
                    if len(parts) >= 2:
                        description = parts[1].strip()
                        issue_type = extract_issue_type(description)
                        all_types.add(issue_type)
                        
                        rows_html += f"""
                        <tr>
                            <td class="file-name">未知文件</td>
                            <td class="line-number">-</td>
                            <td class="description">{description}</td>
                            <td class="issue-type">{issue_type}</td>
                        </tr>"""

        # 统计信息
        total_issues = len([line for line in lines if line.strip() and not line.startswith('*') and not line.startswith('warning: When using') and not line.startswith('warning: Declaration conflict') and 'warning:' in line])
        
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
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
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
            overflow: hidden;
            word-wrap: break-word;
        }}
        th {{
            background-color: #f8f9fa;
            cursor: pointer;
            font-weight: 600;
            color: #495057;
        }}
        /* 设置各列的宽度比例 */
        .file-name, .file-name-header {{
            width: 20%;
        }}
        .line-number, .line-number-header {{
            width: 10%;
            text-align: center;
        }}
        .description, .description-header {{
            width: 50%;
        }}
        .issue-type, .issue-type-header {{
            width: 20%;
            text-align: center;
        }}
        .filter-select {{
            background: white;
            border: 1px solid #ced4da;
            border-radius: 4px;
            padding: 4px 8px;
            font-size: 14px;
            margin-left: 10px;
        }}
        .hidden {{
            display: none;
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
    <script>
        function filterByType(selectedType) {{
            const rows = document.querySelectorAll("tbody tr");
            rows.forEach(row => {{
                const typeCell = row.querySelector("td:last-child");
                if (selectedType === "All" || typeCell.textContent === selectedType) {{
                    row.classList.remove("hidden");
                }} else {{
                    row.classList.add("hidden");
                }}
            }});
            
            // 更新显示的问题数量
            updateVisibleCount();
        }}
        
        function updateVisibleCount() {{
            const visibleRows = document.querySelectorAll("tbody tr:not(.hidden)");
            const countElement = document.getElementById("visible-count");
            if (countElement) {{
                countElement.textContent = visibleRows.length;
            }}
        }}
    </script>
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
                    <div class="stat-number" id="visible-count">{total_issues}</div>
                    <div class="stat-label">发现的问题</div>
                </div>
            </div>
        </div>
        <div class="content">"""

        if total_issues == 0:
            html_content += """
            <div class="no-issues">
                🎉 太棒了！没有发现无用代码
            </div>"""
        else:
            # 添加表格头部和过滤器
            html_content += """
            <table>
                <thead>
                    <tr>
                        <th class="file-name-header">文件</th>
                        <th class="line-number-header">行号</th>
                        <th class="description-header">描述</th>
                        <th class="issue-type-header">
                            类型
                            <select class="filter-select" onchange="filterByType(this.value)">
                                <option value="All">全部</option>"""
            
            # 添加所有类型到下拉框
            for issue_type in sorted(all_types):
                html_content += f'<option value="{issue_type}">{issue_type}</option>'
            
            html_content += """
                            </select>
                        </th>
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

def extract_issue_type(description):
    """从描述中提取问题类型"""
    description_lower = description.lower()
    
    # 匹配各种类型的未使用代码
    if "function" in description_lower and "unused" in description_lower:
        return "unused function"
    elif "parameter" in description_lower and "unused" in description_lower:
        return "unused parameter"
    elif "variable" in description_lower and "unused" in description_lower:
        return "unused variable"
    elif "class" in description_lower and "unused" in description_lower:
        return "unused class"
    elif "enum" in description_lower and "unused" in description_lower:
        return "unused enum"
    elif "protocol" in description_lower and "unused" in description_lower:
        return "unused protocol"
    elif "struct" in description_lower and "unused" in description_lower:
        return "unused struct"
    elif "property" in description_lower and "unused" in description_lower:
        return "unused property"
    elif "typealias" in description_lower and "unused" in description_lower:
        return "unused typealias"
    elif "import" in description_lower and "unused" in description_lower:
        return "unused import"
    elif "initializer" in description_lower and "unused" in description_lower:
        return "unused initializer"
    elif "extension" in description_lower and "unused" in description_lower:
        return "unused extension"
    else:
        return "other"

if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(1)
    
    title = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]
    
    generate_periphery_html(title, input_file, output_file)
