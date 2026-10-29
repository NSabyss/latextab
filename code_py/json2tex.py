from pathlib import Path                                    # 导入Path，以面向对象的方式处理文件和路径
import json                                                 # 用以处理json模块
import sys                                                  # sys：访问和操作解释器与环境变量和函数
from jinja2 import Environment, FileSystemLoader            # jinja2：模板引擎
                                                            # Environment：Jinja2模板运行环境
                                                            # FileSystemLoader：从文件系统目录中加载模板

ROOT = Path(__file__).resolve().parent.parent               # 根目录 = 当前python文件（__file__）
                                                            #   的父目录的父目录(.parent.parent)的
                                                            #   绝对路径(.resolve()：返回绝对路径)
JSON_FILE = Path(sys.argv[1])                               # json文件路径 = 命令行参数的第一个参数(sys.argv[1])
OUTPUT_FILE = Path(sys.argv[2])                             # 输出文件路径 = 命令行参数的第二个参数(sys.argv[2])

with open(JSON_FILE, "r", encoding="utf-8") as f:           # 以读取模式("r")打开json文件(命名为f)，并指定编码为utf-8
    data = json.load(f)                                     # 将f加载为Python对象，并赋值给data变量

TEMPLATE_DIR = ROOT / "templates"                           # 模板统一目录：body 片段 + 共享导言区都放这里
PREAMBLE_FILE = TEMPLATE_DIR / "_preamble.tex"              # 共享导言区文件（mode=independ 时套在 body 之前）

env = Environment(                                          # 创建Jinja2模板运行环境
    loader=FileSystemLoader(TEMPLATE_DIR),                  # 指定模板文件夹路径为TEMPLATE_DIR
    autoescape=False,                                       # 禁用自动转义，否则&、<等可能被转义成HTML实体
    trim_blocks=True,                                       # 删除块语句前的空行
    lstrip_blocks=True                                      # 删除块语句后的空行
)

template = env.get_template(data["template"])               # 获取模板文件名为data["template"]的模板对象（body 片段）
body = template.render(**data)                              # 渲染模板，传入data字典中的键值对作为参数，生成LaTeX代码

if data.get("mode") == "independ":                          # mode=independ：套上共享导言区，生成可独立编译的完整文档
    preamble = PREAMBLE_FILE.read_text(encoding="utf-8")    # 读共享导言区（\documentclass + 宏包，不含\begin{document}）
    latex = (                                               # 组合：导言区 + \begin{document} + body + \end{document}
        preamble.rstrip()                                   # 去掉导言区末尾多余空行
        + "\n\n\\begin{document}\n\n"                        # 文档开始
        + body                                              # 表格片段
        + "\n\\end{document}\n"                             # 文档结束
    )
else:                                                       # mode=input（默认）：只输出 body 片段，交给论文 \input 引入
    latex = body                                            # 片段无需导言区（宏包由论文主文件 thusetup.tex 统一加载）

OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)       # 确保输出文件的目录存在
OUTPUT_FILE.write_text(latex, encoding="utf-8")             # 将生成的LaTeX代码写入输出文件

print(f"LaTeX generated: {OUTPUT_FILE}")                    # 打印生成的LaTeX文件路径


# ============================================================
# 代码学习：两个关键对象 + 一次拼接的分工
# ============================================================
#
# data = json.load(f)
#   → 读取 JSON，得到 Python 字典 data
#
# env = Environment(...)
#   → Environment 不是函数，是类；env 是实例对象，用以创建 Jinja2 模板引擎配置对象
#   → 负责保存“怎么加载模板、怎么转义、怎么处理空白”等规则
#
# template = env.get_template(data["template"])
#   → 根据模板名，从 templates/ 目录加载 body 片段
#   → 返回 Jinja2 的 Template 对象
#
# body = template.render(**data)
#   → 把 data 作为变量数据传给模板，渲染出表格片段
#
# mode=independ 时：
#   → 读 templates/_preamble.tex，与 body 拼成「导言区 + 文档壳 + 表格」
# mode=input 时：
#   → 只输出 body 片段（宏包由论文主文件加载）
#
# OUTPUT_FILE.write_text(latex, encoding="utf-8")
#   → 把最终文本保存到磁盘
#
#
# 通俗类比：
# ------------------------------------------------------------
# json.load(f)          → 准备好要填写的数据
# Environment(...)      → 设置打印机：去哪拿纸、怎么排版
# FileSystemLoader(...) → 告诉打印机：空白表格放在哪个文件夹
# env.get_template(...) → 根据名字取出一张空白表格，装入打印机
# template.render(...)  → 把数据填进表格，打印出片段
# （mode=independ）      → 再给片段套上封面（导言区），变成一本可独立装订的册子
# write_text(...)       → 把打印结果保存到磁盘
#
# ============================================================
