*==============================================================================*
**#1					【子程序：regression 回归结果表（esttab 薄包装）】
*==============================================================================*
capture program drop _latextab_reg
//////////////////////////////////【程序目标】//////////////////////////////////
* - 线性回归结果表：系数 + 标准误(括号) + 显著性星号 + N / R²
* - 直接封装 esttab：读已存估计、t 分布星号、booktabs 三线表全由 esttab 原生给出
* - estnames 为空时 esttab 自动读当前 e()（最近一次回归），无需手工重跑
//////////////////////////////////【程序语法】//////////////////////////////////
program define _latextab_reg
	version 19.0
	syntax [anything(name=estnames)] [using/] , /// 估计名列表（estimates store 的 names），可空=当前 e()
		PYTHON(string) RETEX(string)					/// 主程序公共路径，自动传入
		[											/// 【可选】
		CAPtion(string) 							/// 表题
		LABel(string) 								/// 标签(交叉引用)
		MODE(string) 								/// 模式 input/independ
		ORIENTation(string) 						/// 方向 portrait/landscape
		MODELS(string) 								/// 表头列名（映射 esttab 的 mtitles）
		NOTE(string) 								/// 表注
		REPLACE										/// 替换同名文件
		]

*==============================================================================*
**#2						【参数设置：公共与特殊】
*==============================================================================*
//////////////////////【公共工具程序：默认值与文件名处理】//////////////////////
	_latextab_set_defaults, 			/// 必须先定 base 和 using
		type("reg") mode("`mode'") 		/// cap > using > lab 名称优先级
		caption(`"`caption'"') using("`using'") label("`label'") orientation("`orientation'")
*【公共工具程序：文件名覆盖】
	if "`replace'" == "" {
		_latextab_check_file "`using'"
	}
	else {
		_latextab_check_file "`using'", replace
	}
*【表注默认值】
	if `"`note'"' == "" {
		local note "注：$^{*}p<0.05$，$^{**}p<0.01$，$^{***}p<0.001$；括号内为标准误。"
	}

*==============================================================================*
**#3						【esttab 原始输出】
*==============================================================================*
* esttab 固定选项：booktabs 三线 + 3 位小数 + N/r2 + 变量标签 + 去内建脚注（用我方 note）
	local estopts `"booktabs style(tex) b(3) se(3) stats(N r2, fmt(%9.0f %9.3f)) nonotes label"'
	if `"`models'"' != "" {
		local estopts `"`estopts' mtitles(`models')"'
	}

* 原始 tex 临时文件（与 using 同基名、同目录，稍后清理）
	local raw = subinstr("`using'", ".tex", "_raw.tex", .)

* esttab 导出：estnames 为空则读当前 e()
	esttab `estnames' using "`raw'", `estopts' replace

*==============================================================================*
**#4						【retex 换表头 + 套壳】
*==============================================================================*
	_latextab_retex, using("`using'") python("`python'") retex("`retex'") raw("`raw'") ///
		source("esttab") mode("`mode'") orientation("`orientation'") ///
		caption(`"`caption'"') label("`label'") note(`"`note'"') jsonkeep("`jsonkeep'")

end
