import os
import re
import sys
from datetime import datetime

def generate_html(html_name, input_file, output_file):
    # 用于存储所有的类型
    all_types = set()
    
    # 处理日志文件内容
    rows_html = ""
    total_issues = 0

    with open(input_file, 'r') as file:
        for line in file:
            # 使用正则表达式解析日志行
            match = re.match(r"^(.*):(\d+):(\d+): (\w+): (.+) \((.+)\)$", line.strip())
            if match:
                file_path = match.group(1)
                line_number = match.group(2)
                column_number = match.group(3)
                level = match.group(4)
                description = match.group(5)
                violation_type = match.group(6)

                # 收集所有 Type
                all_types.add(violation_type)
                total_issues += 1

                # 生成表格行
                rows_html += f"""
                <tr>
                    <td class="file-name">{os.path.basename(file_path)}</td>
                    <td class="line-number">{line_number}</td>
                    <td class="level {level.lower()}">{level}</td>
                    <td class="description">{description}</td>
                    <td class="violation-type">{violation_type}</td>
                </tr>"""

    # 初始化 HTML 内容
    html_content = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{html_name}</title>
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
            background: linear-gradient(135deg, #ff7675 0%, #fd79a8 100%);
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
        .level, .level-header {{
            width: 10%;
            text-align: center;
        }}
        .description, .description-header {{
            width: 45%;
        }}
        .violation-type, .violation-type-header {{
            width: 15%;
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
        .warning {{
            color: #ff9800;
            font-weight: bold;
        }}
        .error {{
            color: #f44336;
            font-weight: bold;
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
            <h1>{html_name}</h1>
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
                🎉 太棒了！没有发现代码规范问题
            </div>"""
    else:
        # 添加表格头部和过滤器
        html_content += """
            <table>
                <thead>
                    <tr>
                        <th class="file-name-header">文件</th>
                        <th class="line-number-header">行号</th>
                        <th class="level-header">级别</th>
                        <th class="description-header">描述</th>
                        <th class="violation-type-header">
                            类型
                            <select class="filter-select" onchange="filterByType(this.value)">
                                <option value="All">全部</option>"""
        
        # 将所有 Type 添加到下拉框
        for violation_type in sorted(all_types):
            html_content += f'<option value="{violation_type}">{violation_type}</option>'

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
    # 将 HTML 写入文件
    with open(output_file, 'w', encoding='utf-8') as output_file:
        output_file.write(html_content)

    print(f"HTML 报告已生成: {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("用法: python3 generate_lint_html.py <html_name> <input_file> <output_file>")
        sys.exit(1)

    html_name = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]

    if not os.path.exists(input_file):
        print(f"错误: 日志文件 '{input_file}' 不存在.")
        sys.exit(1)

    generate_html(html_name, input_file, output_file)
