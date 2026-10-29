{smcl}
{* *! version 0.3.0  20oct2026}{...}
{viewerjumpto "syntax" "Syntax"}{...}
{viewerjumpto "description" "Description"}{...}
{viewerjumpto "options" "Options"}{...}
{viewerjumpto "install" "Installation"}{...}
{viewerjumpto "examples" "Examples"}{...}
{title:latextab — Stata 表格转 LaTeX 三线表}

{pstd}
{cmd:latextab} 把 Stata 的统计结果（回归、频数/交叉表、描述统计、变量定义表）
直接输出成 {cmd:booktabs} 三线表 LaTeX 片段，可直接 {cmd:\input} 进 thuthesis 论文，
也可独立编译预览。

{pstd}
底层不手写表格，而是薄包装两个成熟命令：
{cmd:reg} 包 {help esttab}（读已存估计、t 分布星号），
{cmd:tab}/{cmd:stat}/{cmd:table} 包 {help table}（多级行列表头 + 小计），
导出原始 tex 后再经 retex.py 换表头统一成三线表。

{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:latextab} {cmd:reg} [{it:estnames}] [using {it:filename}] {cmd:,}
[{opth caption:(string)} {opth label:(string)}
{opt mode(independ|input)} {opt orientation(portrait|landscape)}
{opth models:(string)} {opth note:(string)} {opt replace}]

{p 8 16 2}
{cmd:latextab} {cmd:tab} {it:varlist} [{cmd:min=1 max=2}] [using {it:filename}] {cmd:,}
[{opth statistic:(string)} {it:options}]

{p 8 16 2}
{cmd:latextab} {cmd:stat} {it:varlist} [using {it:filename}] {cmd:,}
[{opth statistic:(string)} {opth by:(varname)} {it:options}]

{p 8 16 2}
{cmd:latextab} {cmd:table} [{it:dimspec}] [using {it:filename}] {cmd:,}
[{opth statistic:(string)} {opth collectopts:(string)} {it:options}]

{p 8 16 2}
{cmd:latextab} {cmd:list} {it:varlist} [using {it:filename}] {cmd:,}
[{opth template:(string)} {opth columns:(string)} {opth colformat:(string)} {it:options}]

{pstd}
其中 {it:options} 为公共选项（见下）。

{marker description}{...}
{title:Description}

{pstd}
{cmd:latextab reg} 输出线性回归结果表：系数 + 括号内标准误 + 显著性星号
（t 分布，* p<0.05 / ** p<0.01 / *** p<0.001）+ 样本量 N + R{superscript:2}。
{it:estnames} 为 {cmd:estimates store} 存的估计名；省略时用最近一次回归的 {cmd:e()}。

{pstd}
{cmd:latextab tab} 输出一维频数表或二维交叉表（含行列 Total 小计）。
{cmd:latextab stat} 输出描述统计表：默认行为「行=统计量、列=变量」，
加 {cmd:by()} 后「行=分组（含小计）、列=统计量」。
{cmd:latextab table} 是逃生舱，{it:dimspec} 直接按 {help table} 的维度语法写
（如 {cmd:(foreign) (rep78)}），适合任意多级表。

{marker options}{...}
{title:Options}

{pstd}
公共选项（各子命令通用）：

{phang}
{opth caption:(string)} 表题，放在 {cmd:\caption} 内。未指定时用输出文件名兜底。

{phang}
{opth label:(string)} 标签，自动生成 {cmd:\label\{tab:XXX\}}（只需写 XXX，不含 {cmd:tab:} 前缀）。未指定时用输出文件名兜底。

{phang}
{opt mode(independ|input)} 输出模式。默认 {cmd:independ}（套导言区 + 文档壳，可独立编译）；
{cmd:input} 只出表格片段，交给论文主文件 {cmd:\input}。默认 {cmd:independ}。

{phang}
{opt orientation(portrait|landscape)} 排版方向。{cmd:landscape} 时把表格包进
{cmd:\begin\{landscape\}}（{cmd:pdflscape} 宏包）。默认 {cmd:portrait}。

{phang}
{opt replace} 覆盖同名输出文件；不加 {cmd:replace} 且文件已存在时自动改名加序号。

{pstd}
各子命令专属选项：

{phang}
{cmd:reg}：{opth models:(string)} 表头列名（映射 esttab 的 {cmd:mtitles()}）；
{opth note:(string)} 表注（默认给出中文显著性说明）。

{phang}
{cmd:stat}：{opth statistic:(string)} 统计量列表（空格分隔，如
{cmd:mean sd min max}），{cmd:n} 等价于 {cmd:count}（样本量）。默认 {cmd:mean sd min max n}；
{opth by:(varname)} 分组变量，自动带 Total 小计。

{phang}
{cmd:tab}：{opth statistic:(string)} 单元格统计量，默认 {cmd:freq}（频数）。

{phang}
{cmd:table}：{opth statistic:(string)} 单个统计量；
{opth collectopts:(string)} 原样追加到 {cmd:table} 命令后（如 {cmd:nototals}、
额外的 {cmd:statistic()}、{cmd:nformat()} 等）。

{phang}
{cmd:list}：{opth template:(string)} 模板名（默认 {cmd:02_变量定义表.tex}）；
{opth columns:(string)} 三列表头；{opth colformat:(string)} 列对齐。

{marker install}{...}
{title:Installation}

{pstd}
只需两步：

{p 4 8 2}
1. 运行一次安装入口 {cmd:doado_latextab.do}（在 Stata 里 {cmd:do} 它），
它会把 ado 目录加入 {cmd:adopath} 并定义工具路径全局宏。

{p 4 8 2}
2. 换机器 / 换目录时，只需改 {cmd:doado_latextab.do} 顶部的全局宏定义：
{cmd:LATEXTAB_ROOT}（工具根目录，含 code_py/ 与 templates/）、
{cmd:LATEXTAB_PYTHON}（装有 jinja2 的 Python 解释器）、
{cmd:LATEXTAB_ADO}（ado 目录）。可选再覆盖 {cmd:LATEXTAB_SCRIPT} /
{cmd:LATEXTAB_RETEX} 两个脚本路径。

{pstd}
路径解析优先级：全局宏 {cmd:LATEXTAB_ROOT} 等 &gt; 兜底默认
（{cmd:F:\.tools\latextab} 与 {cmd:F:\.venv\Scripts\python.exe}）。

{marker examples}{...}
{title:Examples}

{pstd}准备{p_end}
{phang2}{cmd:. sysuse auto, clear}

{pstd}回归：先存估计再出表{p_end}
{phang2}{cmd:. regress price mpg weight}
{phang2}{cmd:. estimates store m1}
{phang2}{cmd:. regress price mpg weight length}
{phang2}{cmd:. estimates store m2}
{phang2}{cmd:. latextab reg m1 m2 using reg.tex, caption("回归结果") label(reg)}

{pstd}描述统计（行=统计量，列=变量）{p_end}
{phang2}{cmd:. latextab stat price mpg weight, statistic(mean sd min max n)}

{pstd}分组描述统计（含小计）{p_end}
{phang2}{cmd:. latextab stat price, by(foreign) statistic(mean sd)}

{pstd}二维交叉表{p_end}
{phang2}{cmd:. latextab tab foreign rep78}

{pstd}通用多级表（逃生舱）{p_end}
{phang2}{cmd:. latextab table (foreign) (rep78), statistic(freq)}

{pstd}横向排版、独立编译{p_end}
{phang2}{cmd:. latextab stat price mpg weight headroom, orientation(landscape)}
