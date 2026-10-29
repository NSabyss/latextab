*==============================================================================*
**#1				【子程序：tab / stat / table 的 collect 薄包装】
*==============================================================================*
capture program drop _latextab_collect
//////////////////////////////////【程序目标】//////////////////////////////////
* - 把 tab（频数/交叉表）、stat（描述统计）、table（通用多级表）统一交给 collect：
*   多级行列表头 + 小计、维度、统计量全由 collect 原生给出，本程序只拼命令 + 导出 tex，
*   再交给 retex.py 换表头（去 | 竖线、\cline 换三线）
* - type(tab|stat|table) 决定维度与统计量的拼法；collectopts() 是逃生舱，
*   原样追加到 table 命令后（如 nototals、额外 statistic()、nformat() 等）
//////////////////////////////////【程序语法】//////////////////////////////////
program define _latextab_collect
	version 19.0
	syntax [anything] [using/] ,					/// anything：stat/tab=变量，table=维度规格
		TYPE(string) PYTHON(string) RETEX(string)	/// 主程序公共路径 + 子命令类型
		[											/// 【可选】
		CAPtion(string) 							/// 表题
		LABel(string) 								/// 标签(交叉引用)
		MODE(string) 								/// 模式 input/independ
		ORIENTation(string) 						/// 方向 portrait/landscape
		STATISTIC(string)							/// 统计量（stat: 空格分隔列表；tab/table: 单个）
		BY(varname)									/// 分组变量（仅 stat 用，含小计）
		COLLECTOPTS(string)							/// 逃生舱：原样追加到 table 命令
		REPLACE										/// 替换同名文件
		]

*==============================================================================*
**#2						【参数设置：公共与特殊】
*==============================================================================*
//////////////////////【公共工具程序：默认值与文件名处理】//////////////////////
	_latextab_set_defaults, 			/// 必须先定 base 和 using
		type("`type'") mode("`mode'") 	/// cap > using > lab 名称优先级
		caption(`"`caption'"') using("`using'") label("`label'") orientation("`orientation'")
*【公共工具程序：文件名覆盖】
	if "`replace'" == "" {
		_latextab_check_file "`using'"
	}
	else {
		_latextab_check_file "`using'", replace
	}

*==============================================================================*
**#3						【按类型拼 table 命令】
*==============================================================================*
	local dims ""
	local statopts ""

	if "`type'" == "stat" {
		* 描述统计：行=统计量(或分组)，列=变量(或统计量)
		if "`anything'" == "" {
			di as error "stat requires at least one variable: latextab stat varlist"
			exit 198
		}
		if "`statistic'" == "" local statistic "mean sd min max n"
		foreach s of local statistic {				// 逐统计量拼 statistic(stat varlist)
			if inlist("`s'", "n", "N") {
				local sname "count"					// n → collect 的 count（样本量）
			}
			else {
				local sname "`s'"
			}
			local statopts "`statopts' statistic(`sname' `anything')"
		}
		if "`by'" != "" {
			local dims "(`by') (result)"			// 行=分组(含 Total 小计)，列=统计量
		}
		else {
			local dims "(result) (var)"				// 行=统计量，列=变量
		}
	}
	else if "`type'" == "tab" {
		* 频数/交叉表：1 维或 2 维
		if "`anything'" == "" {
			di as error "tab requires at least one variable: latextab tab rowvar [colvar]"
			exit 198
		}
		if "`statistic'" == "" local statistic "freq"
		local rowvar : word 1 of `anything'
		local colvar : word 2 of `anything'
		if "`colvar'" != "" {
			local dims "(`rowvar') (`colvar')"		// 二维交叉，含行列 Total 小计
		}
		else {
			local dims "(`rowvar')"					// 一维频数
		}
		local statopts "statistic(`statistic')"
	}
	else if "`type'" == "table" {
		* 通用多级表：anything 直接是 collect 的维度规格，如 (foreign) (rep78)
		local dims "`anything'"
		if "`statistic'" != "" local statopts "statistic(`statistic')"
	}
	else {
		di as error "type() must be tab, stat, or table"
		exit 198
	}

*==============================================================================*
**#4						【collect 导出原始 tex】
*==============================================================================*
	local raw = subinstr("`using'", ".tex", "_raw.tex", .)

	collect clear
	table `dims', `statopts' `collectopts'
	collect style tex, begintable
	collect export "`raw'", tableonly replace

*==============================================================================*
**#5						【retex 换表头 + 套壳】
*==============================================================================*
	_latextab_retex, using("`using'") python("`python'") retex("`retex'") raw("`raw'") ///
		source("collect") mode("`mode'") orientation("`orientation'") ///
		caption(`"`caption'"') label("`label'") jsonkeep("`jsonkeep'")

end
