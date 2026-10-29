# -*- coding: utf-8 -*-
# ==============================================================================
# retex.py —— 换表头后处理器
# 把 esttab / collect 导出的原始 tex，统一换成 thuthesis booktabs 三线表格式
# ==============================================================================
# 输入：命令行第 1 个参数 = JSON 配置文件路径；第 2 个参数 = 输出 tex 路径
# 配置文件字段：
#   raw         原始 tex 文件路径（esttab / collect 的输出）
#   source      来源："collect"（需换表头：去 | 、\cline 换 \toprule/\midrule/\bottomrule）
#                       或 "esttab"（已是 booktabs，只需包 table 环境）
#   caption     表题（放在 \caption{} 内）
#   label       标签（放在 \label{tab:...} 内）
#   mode        independ（套导言区 + 文档壳，可独立编译）/ input（只出片段，交论文 \input）
#   orientation portrait（纵向）/ landscape（横向，包 \begin{landscape}）
#   note        可选：表注（放在 \end{table} 之后）
# ==============================================================================

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent          # 根目录 = 本文件父目录的父目录
TEMPLATE_DIR = ROOT / "templates"                       # 模板目录（导言区 _preamble.tex 在这里）
PREAMBLE_FILE = TEMPLATE_DIR / "_preamble.tex"          # 共享导言区（mode=independ 时套在最前）

CFG = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))   # 读配置 JSON
OUT = Path(sys.argv[2])                                            # 输出文件路径


# ----------------------------------------------------------------------------
# 1. 提取 tabular 主体：去掉 collect 的 table 外壳 / esttab 的外层花括号
# ----------------------------------------------------------------------------
def _extract_tabular(raw, source):
    """返回 (tabular_block, 是否需要换表头)。
    tabular_block 是 \begin{tabular}...\end{tabular} 的完整内容；
    esttab 若带 \def\sym 宏定义，也一并保留在块前。"""
    if source == "collect":
        lines = []
        for ln in raw.splitlines():
            s = ln.strip()
            if s.startswith(r"\begin{table}") or s.startswith(r"\end{table}"):
                continue                                   # 丢掉 collect 自带的 table 外壳，稍后自己包
            lines.append(ln)
        return "\n".join(lines), True
    else:  # esttab：去掉外层 { }，其余照旧（booktabs 已就位，只需包 table 环境）
        s = raw.strip()
        if s.startswith("{") and s.endswith("}"):
            s = s[1:-1].strip()
        return s, False


# ----------------------------------------------------------------------------
# 2. 换表头：collect 的 | 竖线 + \cline 边框 → booktabs 三线
# ----------------------------------------------------------------------------
def _reheader_collect(block):
    """把 collect 默认的 | 竖线去掉，把 \cline{1-N} 换成
    第一条 \toprule、最后一条 \bottomrule、中间 \midrule。"""
    out = []
    for ln in block.splitlines():
        s = ln.strip()
        if s.startswith(r"\cline"):                        # 边框线：先占位，稍后按位置替换
            out.append("__RULE__")
        else:
            out.append(ln.replace("|", ""))                # 其余行只去掉竖线
    rule_idx = [i for i, x in enumerate(out) if x == "__RULE__"]
    n = len(rule_idx)
    for k, i in enumerate(rule_idx):
        if k == 0:
            out[i] = "\\toprule"
        elif k == n - 1:
            out[i] = "\\bottomrule"
        else:
            out[i] = "\\midrule"
    return "\n".join(out)


# ----------------------------------------------------------------------------
# 3. 包 table 环境：caption 在上、label、\small、\centering
# ----------------------------------------------------------------------------
def _indent_core(core):
    """统一缩进 tabular 主体：\begin{tabular}/\end{tabular} 缩 2 格，其余行缩 4 格。
    注意：不 strip 原始行，保留 esttab 数据行自带的列对齐空格。"""
    lines = core.splitlines()
    out = []
    for ln in lines:
        if ln.strip().startswith(r"\begin{tabular}") or ln.strip().startswith(r"\end{tabular}"):
            out.append("  " + ln)
        else:
            out.append("    " + ln)
    return "\n".join(out)


def _wrap_table(core, cfg):
    """core = \begin{tabular}...\end{tabular}（含可能的前导 \def\sym）。"""
    parts = ["\\begin{table}[htbp]", "  \\centering"]
    caption = cfg.get("caption", "")
    label = cfg.get("label", "")
    if caption:
        parts.append(f"  \\caption{{ {caption} }}")
    if label:
        parts.append(f"  \\label{{tab:{label}}}")
    parts.append("  \\small")
    parts.append(_indent_core(core))
    parts.append("\\end{table}")
    text = "\n".join(parts) + "\n"
    note = cfg.get("note", "")
    if note:
        text += "\n% 表注：\n\n" + note + "\n"
    return text


# ----------------------------------------------------------------------------
# 主流程
# ----------------------------------------------------------------------------
raw = Path(CFG["raw"]).read_text(encoding="utf-8")
source = CFG.get("source", "collect")
mode = CFG.get("mode", "independ")
orientation = CFG.get("orientation", "portrait")

tabular, need_reheader = _extract_tabular(raw, source)
if need_reheader:
    tabular = _reheader_collect(tabular)

body = _wrap_table(tabular, CFG)

if orientation == "landscape":                             # 横向：包 landscape（pdflscape 已在导言区加载）
    body = "\\begin{landscape}\n" + body + "\\end{landscape}\n"

if mode == "independ":                                     # 独立编译：套导言区 + 文档壳
    preamble = PREAMBLE_FILE.read_text(encoding="utf-8")
    latex = (
        preamble.rstrip()
        + "\n\n\\begin{document}\n\n"
        + body
        + "\\end{document}\n"
    )
else:                                                      # 片段：交给论文主文件 \input
    latex = body

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(latex, encoding="utf-8")

print(f"LaTeX generated: {OUT}")
