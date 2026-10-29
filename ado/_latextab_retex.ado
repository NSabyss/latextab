*==============================================================================*
**#					【公共工具程序：retex 换表头 + 渲染收尾】
*==============================================================================*
capture program drop _latextab_retex
//////////////////////////////////【程序目标】//////////////////////////////////
* - 写 retex.py 所需的配置 JSON，调 Python 把 esttab/collect 的原始 tex
*   换成 thuthesis booktabs 三线表（去 | 竖线、\cline 换 \toprule/\midrule/\bottomrule），
*   再按 mode(独立编译/片段) × orientation(纵向/横向) 两层套壳
* - 与 _latextab_finish 并列：_latextab_finish 走 json2tex.py(Jinja2 模板)，
*   本程序走 retex.py(换表头)，二者都是「写中间文件 → 调 Python → 清理」
//////////////////////////////////【程序语法】//////////////////////////////////
program define _latextab_retex
	syntax, using(string) python(string) retex(string) raw(string)	/// 原始 tex 与工具路径
		source(string) mode(string) orientation(string)				/// 来源/模式/方向
		[caption(string) label(string) note(string) jsonkeep(string)]	/// 表题/标签/表注/清理开关

////////////////////////////////【程序定义】////////////////////////////////
	* 0. 路径统一正斜杠，供 JSON 与 Python 使用
	local raw   = subinstr("`raw'", "\", "/", .)
	local using = subinstr("`using'", "\", "/", .)

	* 1. 配置 JSON 与原始 tex 同目录、同基名
	local cfgfile = subinstr("`raw'", ".tex", ".json", .)

	file open js using "`cfgfile'", write text replace
	file write js "{" _n
	file write js `"  "raw": "`raw'", "' _n
	file write js `"  "source": "`source'", "' _n
	file write js `"  "mode": "`mode'", "' _n
	file write js `"  "orientation": "`orientation'", "' _n
	file write js `"  "caption": "`caption'", "' _n
	file write js `"  "label": "`label'", "' _n
	file write js `"  "note": "`note'""' _n
	file write js "}" _n
	file close js

	* 3. 调 Python retex.py：<配置json> <输出tex>
	local cmd `""`python'" "`retex'" "`cfgfile'" "`using'""'
	shell `cmd'

	* 4. 打印成功提示与可点击超链接
	display as result "LaTeX table generated: " _n ///
		`"{view "`using'":`using'}"'

	* 5. 按 jsonkeep 开关清理中间文件（原始 tex + 配置 json）
	if "`jsonkeep'" != "1" {
		capture erase "`cfgfile'"
		capture erase "`raw'"
	}
end
