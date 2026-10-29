# latextab 表格自动化工具

Stata → LaTeX 三线表自动生成工具。核心分工一句话：

**Stata 负责算数出数据，Python/Jinja2 负责套模板，LaTeX（xelatex）负责排版出 PDF。**

---

## 一、制作思路

### 为什么分三层

把「数据」和「排版」彻底分离，各管各的：

1. **Stata（`latextab.ado`）**：负责统计（`tabulate` 交叉表、回归等），把结果写成一份 JSON（纯数据）。
2. **Python（`code_py/json2tex.py` + Jinja2）**：读 JSON，按指定模板把数据填进三线表骨架，渲染成 `.tex`。
3. **LaTeX（xelatex）**：把 `.tex` 编译成 PDF。

好处：

- 换排版 = 只改模板，数据不动；换数据 = 只改 JSON，模板不动。
- 同一份数据能出两种形态（用 `mode` 选项切换，见下）。

### 数据流

```
Stata: latextab tab ...              →  tmp_json/table.json
Python: json2tex.py table.json 输出.tex  →  生成的 .tex
xelatex / VS Code 绿色三角           →  PDF
```

### 两种形态（mode）

| mode | 输出形态 | 用途 |
|---|---|---|
| `independ`（默认） | 完整文档（自带导言区 + 宏包） | 独立编译预览 |
| `input` | 纯表格片段（无 `\documentclass`） | `\input` 进论文 |

---

## 二、目录结构

| 路径 | 作用 |
|---|---|
| `ado/` | Stata 命令：`latextab.ado`（主程序）+ `_latextab_*.ado`（子程序）+ `latextab.sthlp` + `doado_latextab.do`（安装入口） |
| `code_py/retex.py` | 换表头：esttab/collect 原始 tex → booktabs 三线表 |
| `code_py/json2tex.py` | Jinja2 渲染：JSON + 模板 → `.tex`（list 子命令用） |
| `templates/` | 模板目录：`01~06_*.tex` body 片段 + `_preamble.tex` 共享导言区 |
| `config/` | 配置：`config.json` + `requirements.txt` |
| `examples/` | 示例：各子命令的 `.tex` / `.do` 样例 |
| `tmp_json/` `tmp_tex/` `tmp_pdf/` | 中间产物：JSON / 生成的 tex / PDF（已 gitignore） |

---

## 三、模板体系：body 片段 + 共享导言区

### 模板只维护一份，导言区独立成段

- **body 片段（`01~06_*.tex`）**：纯表格骨架（`\begin{table}...\end{table}` 或 `\begin{landscape}...`），含 Jinja2 占位符，无 `\documentclass`、不加载宏包。这是**唯一**的模板来源。
- **共享导言区（`_preamble.tex`）**：`\documentclass{ctexart}` + 全套宏包。`json2tex.py` 在 `mode=independ` 时自动把它套在 body 前，拼成完整文档。

> 不再有 input/independ 两份同名模板。两种形态由 `mode` 切换：`input` 只出 body 片段（交给论文 `\input`，宏包由论文主文件 thusetup.tex 加载）；`independ` 出「导言区 + 文档壳 + body」，可单独编译预览。增删宏包只改 `_preamble.tex` 一处。

### 通用约定

- 表题在上：`\caption{...}` 置于 `tabular` 之前；`\label{tab:章-序号}` 紧随其后。
- 三线表：`\toprule` / `\midrule` / `\bottomrule`（booktabs），**不用竖线**。
- 字号：正文表格统一 `\small`。
- 表注：置于 `\end{table}` 之后的正文段落（非表格内）；显著性 `$^{*}p<0.05$，$^{**}p<0.01$，$^{***}p<0.001$`，标准误加括号 `( )`。
- 依赖宏包：`booktabs`、`multirow`、`makecell`、`array`、`longtable`、`pdflscape`、`threeparttable`、`siunitx`。论文 thusetup.tex 已全部加载；`_preamble.tex` 已自带全套（`independ` 模式用）。

### 模板索引（6 个）

| 模板 | 用途 | 关键结构 |
|---|---|---|
| `01_基础三线表` | 单 tabular 通用（频数/百分比/均值/描述统计）；可加二级表头 | table + 单 tabular（可选 `\multicolumn`+`\cmidrule` 二级表头） |
| `02_变量定义表` | 变量名/口径/定义编码 | `p{}` 定宽列 + `\texttt{}` |
| `03_回归结果表` | 系数 + 标准误（括号）+ N/R² | 括号标准误行 |
| `04_多面板三线表` | 一个表内多个 tabular（面板 A/B/C） | 多 tabular + 面板循环 |
| `05_横向宽表` | 超宽表横排整页；可跨页分组 | `landscape` + `longtable`（可选分组标题行） |
| `06_跨行分组表` | 跨行合并分组 | `multirow` + `addlinespace` |

> 常用占位符：`caption` `label` `column_format` `columns` `rows` `ncols`；多面板用 `panel.*`，分组表用 `group.*` / `column_groups`。具体以各模板文件为准。

---

## 四、使用方法

### 1. 在 Stata 里生成表格

```stata
latextab tab 行变量 列变量 using 输出.tex, ///
    caption("表题") label("章-序号")     ///
    mode(input) template("01_基础三线表.tex") replace
```

参数说明：

- `tab`：子命令（交叉表）。`reg`（回归表）/`list`（变量定义表）子命令已实现。
- 行变量、列变量：1~2 个数值型变量。
- `using()`：输出 `.tex` 的路径（必填）。
- `caption()`：表题（必填）；`label()`：交叉引用标签（必填）。
- `mode(input|independ)`：默认 `input`。
- `template()`：模板文件名；不填则自动选（总列数 ≤7 用 `01_基础三线表`，否则 `05_横向宽表`）。
- `name()`：临时 JSON 名（默认 `table`）；`nototal`：不输出合计列；`replace`：覆盖已存在文件。

### 2. 编译成 PDF

> 关键：模板是 **jinja2 模板**（含 `{{ caption }}`、`{% for %}` 等占位符），**不能直接 xelatex 编译**。必须先经 `latextab` / `json2tex.py` 渲染成真实数据，再编译。

- **独立预览**：用 `mode(independ)` 生成完整文档后，点 VS Code 右上角绿色三角（latexmk + xelatex），PDF 生成在 `.tex` 同目录，中间文件进 `build/` 子文件夹。
- **手动编译**：`xelatex -interaction=nonstopmode 输出.tex`（必须 xelatex，ctexart 中文依赖 xelatex）。
- **论文**：用 `mode(input)` 生成片段，交给论文主文件统一编译（见下）。

### 3. 集成进论文

1. 定稿后，把 `mode(input)` 生成的片段复制到论文 `tables/tab{章}-{序号}_{简称}.tex`。
2. 在章节里 `\input{tables/tab{章}-{序号}_{简称}}`（无 `.tex` 后缀，与主文件一致）。
3. 宏包由论文 thusetup.tex 加载，片段内无需再加载。

---

## 六、编译配置（VS Code）

- 绿色三角编译由工作区 `f:\.vscode\settings.json` 的 recipe 驱动：`latexmk (xelatex)`，第一步「unpack-thuthesis」为条件执行（目录里有 `thuthesis.ins` 才解包，表格目录自动跳过），因此论文和表格共用一个 recipe，无需切换。

### PDF 统一输出到 tmp_pdf

`F:\.tools\latextab` 下所有 `.tex` 编译后，PDF 会自动落到 `F:\.tools\latextab\tmp_pdf`，而不是 `.tex` 旁边；论文（`F:\project\...`）仍原地出 PDF，不受影响。

实现是「条件路由」，两个文件配合：

1. `f:\.vscode\settings.json` 里 `xelatexmk` / `lualatexmk` 两个 latexmk 工具加了 `-r "F:/.tools/latextab/.latexmkrc"`，让每次 latexmk 编译都加载这个 rc 文件。
2. `F:\.tools\latextab\.latexmkrc` 判断「当前编译目录」（= 被编译 `.tex` 所在目录）是否在 latextab 树下：是则把 `$out_dir` 设为 tmp_pdf，否则什么都不做。

```perl
use Cwd;
my $cwd = Cwd::cwd();
if ($cwd =~ /F:[\/\\]\.tools[\/\\]latextab([\/\\]|$)/i) {
    $out_dir = 'F:/.tools/latextab/tmp_pdf';
}
```

结果：PDF（连同 `.synctex.gz`）落到 `tmp_pdf`；aux/log/xdv 等中间文件仍在各 `.tex` 旁的 `build/` 子目录。

- 详细配置与 autoClean 开关说明见 `F:\.vscode\使用说明.md`。
