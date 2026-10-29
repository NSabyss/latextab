# latextab

**Latextab for Stata, based on esttab and collect.**

Stata → LaTeX 三线表自动生成工具。在 Stata 里一条命令生成符合学术论文规范（booktabs 三线表）的 LaTeX 表格，用于 `\input` 进论文或独立编译预览。

核心思路：**Stata 负责算数出数据，Python 负责换表头/套模板，LaTeX（xelatex）负责排版出 PDF**。不手写表格代码，而是包装 Stata 成熟的 `esttab` / `collect` 命令，再用 Python 后处理统一换成 booktabs 三线表格式。

## 特性

- **一条命令出表**：`latextab` 覆盖交叉表（tab）、描述统计（stat）、多级分组表（table）、回归结果表（reg）、变量定义表（list）五种需求。
- **包装成熟命令**：回归表包装 `esttab`（读已存估计、t 分布星号），交叉/描述/分组表包装 `collect`（原生多级表头 + 小计），星号、分组全由成熟命令给出，不自己算。
- **统一三线表**：`retex.py` 把 esttab/collect 的原始 tex 换成 thuthesis booktabs 三线表（`\toprule`/`\midrule`/`\bottomrule`，去竖线）。
- **两种形态**：`mode(input)` 出纯片段（`\input` 进论文），`mode(independ)` 出完整文档（自带导言区，可独立编译预览）；`orientation(landscape)` 出横向宽表。

## 系统要求

- Stata 17+（`collect` 从 17 引入；`latextab.ado` 声明 `version 19.0`）
- Python ≥3.10，需装 `jinja2`
- LaTeX 发行版（xelatex，中文依赖 xelatex）

## 安装

### 1. Python 依赖

```bash
pip install -r config/requirements.txt
```

### 2. Stata 配置

在 Stata 里，先 `cd` 到本仓库根目录，再运行安装入口（定义全局宏 + 加入搜索路径）：

```stata
cd "本仓库路径"          // code_py/ 与 ado/ 所在目录
do doado_latextab.do
```

安装入口会自动把 `ado/` 加入 `adopath`，并用当前目录推导工具根目录。若你的 `python` 不在 PATH，编辑 `doado_latextab.do` 里 `LATEXTAB_PYTHON` 为完整路径。

检查：

```stata
which latextab
```

## 用法

```stata
* 交叉表（频数/百分比）
latextab tab 行变量 列变量 using 输出.tex, caption("表题") label("章-序号") mode(input)

* 描述统计
latextab stat 变量1 变量2, statistic(mean sd min max n)

* 多级分组表
latextab table (行1 行2) (列1 列2), statistic(mean)

* 回归结果表（先 estimates store）
latextab reg est1 est2 using 输出.tex, caption("表题") label("章-序号")

* 变量定义表
latextab list 变量1 变量2, caption("表题") label("章-序号")
```

常用选项：`mode(input|independ)`（片段/独立编译）、`orientation(portrait|landscape)`（纵向/横向）、`caption()`（表题）、`label()`（标签，自动加 `tab:` 前缀）。

更多见 `examples/latextab_examples.do`。

## 目录结构

| 路径 | 作用 |
|---|---|
| `ado/` | Stata 命令：`latextab.ado` + `_latextab_*.ado` + `latextab.sthlp` + `doado_latextab.do` |
| `code_py/` | Python：`retex.py`（换表头）+ `json2tex.py`（Jinja2 渲染） |
| `templates/` | LaTeX 模板：body 片段 + `_preamble.tex` 共享导言区 |
| `config/` | `config.json` + `requirements.txt` |
| `examples/` | 各子命令示例 |

## License

[MIT](LICENSE)
