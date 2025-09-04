import os
import sys
import xml.etree.ElementTree as ET
from html import escape
from datetime import datetime

def parse_xml(file_path):
    tree = ET.parse(file_path)
    root = tree.getroot()
    namespace = {'ns': 'https://pmd-code.org/schema/cpd-report'}

    duplications = []
    for duplication in root.findall('ns:duplication', namespace):
        code_fragment = duplication.find('ns:codefragment', namespace).text.strip()
        files = []
        for file in duplication.findall('ns:file', namespace):
            path = file.get('path')
            line = file.get('line')
            files.append({'path': path, 'line': line})
        duplications.append({'code': code_fragment, 'files': files})

    return duplications

def generate_html(html_name, duplications, output_file):
    total_duplications = len(duplications)
    
    html_content = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>代码重复检测报告</title>
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
            background: linear-gradient(135deg, #74b9ff 0%, #0984e3 100%);
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
        .block {{
            margin: 20px 0;
            padding: 20px;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            background-color: #fafafa;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        .block-header {{
            background: linear-gradient(135deg, #fdcb6e 0%, #e17055 100%);
            color: white;
            padding: 10px 15px;
            margin: -20px -20px 15px -20px;
            border-radius: 8px 8px 0 0;
            font-weight: 600;
        }}
        .code {{
            font-family: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, monospace;
            font-size: 14px;
            background-color: #f8f8f8;
            padding: 15px;
            border-radius: 6px;
            overflow-x: auto;
            border: 1px solid #e0e0e0;
            line-height: 1.5;
            max-height: 400px;
            overflow-y: auto;
        }}
        .file-list {{
            margin-top: 15px;
            padding: 15px;
            background-color: #e8f4fd;
            border-radius: 6px;
            border-left: 4px solid #0984e3;
        }}
        .file-list ul {{
            margin: 5px 0 0 0;
            padding-left: 20px;
            list-style-type: none;
        }}
        .file-list li {{
            margin: 8px 0;
            color: #2d3436;
            padding: 8px 12px;
            background-color: #ffffff;
            border-radius: 4px;
            border: 1px solid #ddd;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
        }}
        .file-info {{
            display: flex;
            flex-direction: column;
            flex: 1;
            min-width: 0; /* 允许收缩 */
        }}
        .file-name {{
            font-weight: 600;
            color: #2d3436;
            margin-bottom: 4px;
        }}
        .file-path {{
            font-family: "SF Mono", Monaco, "Cascadia Code", monospace;
            font-size: 0.85em;
            color: #636e72;
            word-break: break-all;
            line-height: 1.4;
        }}
        .line-info {{
            background-color: #74b9ff;
            color: white;
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 0.8em;
            font-weight: 500;
            white-space: nowrap;
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
        
        /* 响应式设计 */
        @media (max-width: 768px) {{
            .file-list li {{
                flex-direction: column;
                align-items: flex-start;
            }}
            .line-info {{
                align-self: flex-end;
            }}
        }}
    </style>
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
                    <div class="stat-number">{total_duplications}</div>
                    <div class="stat-label">重复代码块</div>
                </div>
            </div>
        </div>
        <div class="content">"""

    if total_duplications == 0:
        html_content += """
            <div class="no-issues">
                🎉 太棒了！没有发现重复代码
            </div>"""
    else:
        for i, duplication in enumerate(duplications, 1):
            html_content += f"""
            <div class="block">
                <div class="block-header">
                    重复代码块 #{i}
                </div>
                <div class="code">
                    <pre>{escape(duplication['code'])}</pre>
                </div>
                <div class="file-list">
                    <strong>📍 出现位置:</strong>
                    <ul>"""
            
            for file in duplication['files']:
                filename = os.path.basename(file['path'])
                filepath = file['path']
                line_num = file['line']
                
                html_content += f"""
                        <li>
                            <div class="file-info">
                                <div class="file-name">{escape(filename)}</div>
                                <div class="file-path">{escape(filepath)}</div>
                            </div>
                            <div class="line-info">第 {line_num} 行</div>
                        </li>"""
            
            html_content += """
                    </ul>
                </div>
            </div>"""

    html_content += """
        </div>
    </div>
</body>
</html>"""

    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html_content)

    print(f"HTML 报告已生成: {output_file}")

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("用法: python3 generate_duplicity_html.py <html_name> <input_file> <output_file>")
        sys.exit(1)
        
    html_name = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]

    if not os.path.exists(input_file):
        print(f"输入文件 {input_file} 不存在.")
        sys.exit(1)
    
    duplicates_data = parse_xml(input_file)
    generate_html(html_name, duplicates_data, output_file)
