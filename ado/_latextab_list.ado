*==============================================================================*
**#1					【子程序：list 变量定义/编码表】
*==============================================================================*
capture program drop _latextab_list
//////////////////////////////////【程序目标】//////////////////////////////////
* - 变量定义/编码表：变量名 + 口径(变量标签) + 定义与编码(值标签)
* - 输出到 02_变量定义表.tex 模板（rows 为 {varname, scope, definition}）
//////////////////////////////////【程序语法】//////////////////////////////////
program define _latextab_list
	version 19.0
	syntax varlist(min=1) [using/], 		/// 变量列表：需要定义的变量
		ROOT(string) SCRIPT(string) PYTHON(string)  /// 主程序公共路径，自动传入
		[									/// 【可选】
		CAPtion(string) 					/// 【必选】表题
		LABel(string) 						/// 【必选】标签
		MODE(string) 						/// 【模板】类型
		TEMPLATE(string) 					/// 【模板】文件名
		COLumns(string) 					/// 【表头】三列表头(空格分隔)
		COLFormat(string) 					/// 【格式】列对齐(默认 p{} 定宽)
		REPLACE								/// 【替换】
		]

*==============================================================================*
**#2						【参数设置：公共与特殊】
*==============================================================================*
	_latextab_set_defaults, 			///
		type("list") mode("`mode'") 	///
		caption(`"`caption'"') using("`using'") label("`label'")
*【公共工具程序：文件名覆盖】
	if "`replace'" == "" {
		_latextab_check_file "`using'"
	}
	else {
		_latextab_check_file "`using'", replace
	}
*【模板默认值】
	if "`template'" == "" | "`template'" == "auto" {
		local template "02_变量定义表.tex"
	}
*【表头三列默认值】
	if "`columns'" == "" {
		local c1 "变量"
		local c2 "口径"
		local c3 "定义与编码"
	}
	else {
		tokenize `"`columns'"'
		local c1 "`1'"
		local c2 "`2'"
		local c3 "`3'"
		if "`c3'" == "" {
			di as error "columns() requires 3 header labels (变量 口径 定义与编码)"
			exit 198
		}
	}
*【列格式默认值】（p{} 定宽列，承载长文本）
	if "`colformat'" == "" {
		local colformat "p{3cm}p{4cm}p{7cm}"
	}

*==============================================================================*
**#3						【json文件编写与输出】
*==============================================================================*
	file open js using "`jsonfile'", write text replace
	file write js "{" _n
	file write js `"  "template": "`template'", "' _n
	file write js `"  "mode": "`mode'", "' _n
	file write js `"  "caption": "`caption'", "' _n
	file write js `"  "label": "`label'", "' _n
	file write js `"  "column_format": "`colformat'", "' _n
	file write js `"  "columns": ["`c1'", "`c2'", "`c3'"], "' _n

	* rows 数组：每个变量一行
	file write js `"  "rows": ["' _n
	local nvar : word count `varlist'
	local vi = 0
	foreach var of local varlist {
		local ++vi
		local varname "`var'"
		local scope : variable label `var'
		* 值标签 → "0=女；1=男"
		local definition ""
		local vlab : value label `var'
		if "`vlab'" != "" {
			levelsof `var', local(levels)
			foreach lv of local levels {
				local lbl : label (`var') `lv'
				if `"`definition'"' != "" local definition "`definition'；"
				local definition "`definition'`lv'=`lbl'"
			}
		}
		file write js `"    {"varname": "`varname'", "scope": "`scope'", "definition": "`definition'"}"'
		if `vi' < `nvar' file write js ","
		file write js _n
	}
	file write js "  ]" _n
	file write js "}" _n
	file close js

//////////////////【公共工具程序：调用 Python 引擎与结果反馈】//////////////////
	_latextab_finish, ///
		script("`script'") using("`using'") python("`python'") ///
		jsonfile("`jsonfile'") jsonkeep("`jsonkeep'")

end
