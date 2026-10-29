*==============================================================================*
**#1 					【子程序：table/tabulate说明】
*==============================================================================*
capture program drop _latextab_tab
//////////////////////////////////【程序目标】//////////////////////////////////
* - 简单的一维、二维tab表格
* - by分组
* - 同一个变量不同分类小计
* - 多级表头留给python处理
///////////////////////////【程序结构：调用的子程序】///////////////////////////
* ——【编排层】_latextab_tab ：只做语法解析 + 参数分发，
* 	重活都交给子程序。改动前先分清「公共」与「tab 专用」两类。
*
* ——【公共工具程序】（latextab 各子命令共用，独立 .ado，勿在此改）——
*   _latextab_set_defaults   按 cap > using > lab 优先级定 base/using 文件名，
*                            回传 c_local（base/using/jsonfile 等）
*   _latextab_check_file     检查目标文件；无 replace 且已存在 → 报错拦截
*   _latextab_finish         调 Python 引擎渲染 LaTeX + 结果反馈 + jsonkeep 清理
*                            （由 _latextab_tab_json 末尾调，本程序不直接调）
*
* ——【tab 专用子程序】（本模块拆出的两个，独立 .ado）——
*   _latextab_tab_matrix     #3 矩阵提取：tabulate → 全局矩阵 F/R/C，
*                            回传 nr/nc/ndata/ncols/colformat/template
*   _latextab_tab_json       #4 JSON 序列化，末尾再调 _latextab_finish 渲染
*
* 调用链：
*   _latextab_tab（编排，本文件）
*     ├─ _latextab_set_defaults    #2 参数默认值与文件名
*     ├─ _latextab_check_file      #2 文件名覆盖检查
*     ├─ _latextab_tab_matrix      #3 矩阵提取
*     └─ _latextab_tab_json        #4 JSON + 渲染
*           └─ _latextab_finish      （Python 引擎 + 反馈）
//////////////////////////////////【程序语法】//////////////////////////////////
program define _latextab_tab
	version 19.0
	syntax varlist(min=1 max=2 numeric) [using/], 	/// 【可选】文件名
		ROOT(string) SCRIPT(string) PYTHON(string)  /// 主程序公共路径，自动传入
		[									///	【可选】剩余所有可选项列表
		CAPtion(string) 						/// 【必选】表题
		LABel(string) 							/// 【必选】标签(用于交叉引用)
		MODE(string) 							///	【模板】类型
		TEMPLATE(string) 						///	【模板】文件名
		Centerstat(string)						///	【数据格式】中间单元格
		Marginstat(string)						///	【数据格式】边缘/合计单元格
		BY(varname)   							/// 【分组】变量
		BYDirection(string) 					/// 【分组】排版方向
		COLGroup(string) 						/// 【分组】表头列分组规则
		ROWLabel(string)						/// 【标签】行标题
		COLLabel(string)						///	【标签】列标题
		COLFormat(string)						///	【格式】列对齐
		NOTotal  								/// 【合计列】
		REPLACE									/// 【替换】
		]
*==============================================================================*
**#2 						【参数设置：公共与特殊】
*==============================================================================*
//////////////////////【公共工具程序：默认值与文件名处理】//////////////////////
*【公共参数：公共工具程序】
	_latextab_set_defaults, 			///	必须先定 base 和 using
		type("tab") mode("`mode'") 		///	cap > using > lab 名称优先级
		caption(`"`caption'"') using("`using'") label("`label'")
*【公共工具程序：文件名覆盖】
	if "`replace'" == "" {
		_latextab_check_file "`using'"
	}
	else {
		_latextab_check_file "`using'", replace
	}

/////////////////////////////【变量读取：1 or 2维】/////////////////////////////
	local rowvar : word 1 of `varlist'
	local colvar : word 2 of `varlist'

///////////////////////////【特殊参数：数据内容选择】///////////////////////////
*——————————————————————————————————————————————————————————————————————————————*
* latextab 单元格格式参数速查表 (CenterStat & MarginStat)
*——————————————————————————————————————————————————————————————————————————————*
*
* 1. centerstat() - 控制表格核心交叉区域（中心单元格）的统计量格式：
*    - freq        	: 仅输出绝对频数（默认）
*    - colpct      	: 仅输出列百分比
*    - rowpct      	: 仅输出行百分比
*    - cellpct     	: 仅输出总百分比
*    - freq_colpct 	: 频数与列百分比组合 (例: 120 (35.2%))
*    - freq_rowpct 	: 频数与行百分比组合 (例: 120 (42.5%))
*    - freq_cellpct	: 频数与总百分比组合 (例: 120 (20.8%))
*
* 2. marginstat() - 控制行合计 / 列合计（边缘单元格）的统计量格式：
*    - freq        	: 仅输出绝对频数（默认）
*    - colpct      	: 仅输出列百分比
*    - rowpct      	: 仅输出行百分比
*    - cellpct     	: 仅输出总百分比
*    - freq_colpct 	: 频数与列百分比组合 (例: 120 (35.2%))
*    - freq_rowpct 	: 频数与行百分比组合 (例: 120 (42.5%))
*    - freq_cellpct	: 频数与总百分比组合 (例: 120 (20.8%))
*    - none        : 不显示合计/边缘数据
*
* 典型学术论文搭配示例（中间填行百分比，右侧总计列显示绝对样本量）：
*   latextab tab 变量1 变量2, centerstat(rowpct) marginstat(freq)
*——————————————————————————————————————————————————————————————————————————————*
*【中间单元格统计量默认值 (centerstat)】
	if "`centerstat'" == "" local centerstat "freq"
	else if !inlist("`centerstat'", ///
		"freq", "colpct", "rowpct", "cellpct", ///
		"freq_colpct", "freq_rowpct", "freq_cellpct") {
		di as error ///
		"centerstat() must be freq, colpct, rowpct, cellpct, freq_colpct, freq_rowpct, or freq_cellpct"
		exit 198
	}

*【边缘合计单元格统计量默认值 (marginstat)】
	if "`marginstat'" == "" local marginstat "freq"
	else if !inlist("`marginstat'", ///
		"freq", "colpct", "rowpct", "cellpct", ///
		"freq_colpct", "freq_rowpct", "freq_cellpct", "none") {
		di as error ///
		"marginstat() must be freq, colpct, rowpct, cellpct, freq_colpct, freq_rowpct, freq_cellpct, or none"
		exit 198
	}
//////////////////////////【特殊参数：by分组逻辑处理】//////////////////////////
*【特殊参数】by
	if "`by'" != "" {								//	如果有分组变量
		levelsof `by', local(by_levels)				//	取值水平存入by_levels
		local by_vlab : value label `by'			//	提取值标签名称
	}
	else {
		local by_levels ""
	}

*【特殊参数】bydirection
	if "`bydirection'" == "" {
		local bydirection "vertical"  				//	默认纵向拼接
	}
	else if !inlist("`bydirection'", 				///	报错信息
		"horizontal", "vertical") {
		di as error "bydirection() must be horizontal or vertical"
		exit 198
	}

////////////////////////////【特殊参数：多级列标题】////////////////////////////
*【colgroup 多级表头解析】
* 格式：colgroup("组名1:跨度1 组名2:跨度2 ...")
* 例：colgroup("低年龄:2 高年龄:3") → 前2类归"低年龄"、后3类归"高年龄"
* 要求：必须有列变量(colvar)、不能与 by 分组并用；跨度之和 = 列变量类别数 nc
	if `"`colgroup'"' != "" {
		if "`colvar'" == "" {
			di as error "colgroup() requires a column variable (二维表)"
			exit 198
		}
		if "`by'" != "" {
			di as error "colgroup() cannot be combined with by()"
			exit 198
		}
		local total_span = 0
		local ngroups = 0
		local groups_json ""
		local col_start = 2						//	LaTeX列号：第1列是行标题，数据列从2起
		tokenize `"`colgroup'"'
		while "`1'" != "" {
			local token "`1'"
			gettoken gname gspan : token, parse(":")
			local gspan = strtrim(subinstr("`gspan'", ":", "", .))
			local ++ngroups
			local col_end = `col_start' + `gspan' - 1
			local groups_json ///
`"`groups_json'{"name": "`gname'", "span": `gspan', "start": `col_start', "end": `col_end'}"'
			local total_span = `total_span' + `gspan'
			local col_start = `col_end' + 1
			macro shift
			if "`1'" != "" local groups_json "`groups_json',"
		}
	}


/////////////////////////////【特殊参数：行列标签】/////////////////////////////
*【行标签】
	if `"`rowlabel'"' != "" {
		local rowtitle "`rowlabel'"  				//	优先用用户显式指定的行标题
	}
	else {
		local rowtitle : variable label `rowvar'	//	其次用变量标签
		if `"`rowtitle'"' == "" local rowtitle "`rowvar'"	//	再次为变量名
	}

	local row_vlab : value label `rowvar'			//	提取值标签用于标记分类
*【列标签】（注意：仅在有列变量时提取）
	if "`colvar'" != "" {
		if `"`collabel'"' != "" {
			local coltitle `"`collabel'"'         // 优先用用户显式指定的列标题
		}
		else {
			local coltitle : variable label `colvar' // 其次用变量标签
			if `"`coltitle'"' == "" local coltitle "`colvar'" // 再次用变量名
		}

		local col_vlab : value label `colvar'     // 提取列变量的值标签名称
	}

*==============================================================================*
**#3 		【tabulate与矩阵提取】（子程序 _latextab_tab_matrix）
*==============================================================================*
* 矩阵 F / R / C 为全局对象，子程序算好后回传 nr / nc / ndata / ncols / colformat / template。
	_latextab_tab_matrix, ///
		rowvar("`rowvar'") colvar("`colvar'") ///
		by("`by'") bydirection("`bydirection'") by_levels("`by_levels'") ///
		colgroup(`"`colgroup'"') total_span("`total_span'") nototal("`nototal'") ///
		template("`template'") colformat("`colformat'")

*==============================================================================*
**#4 		【json文件编写与输出】（子程序 _latextab_tab_json）
*==============================================================================*
* 序列化 JSON → 调 Python 渲染 LaTeX。矩阵 F / R / C 直接按名访问。
	_latextab_tab_json, ///
		jsonfile("`jsonfile'") template("`template'") mode("`mode'") ///
		caption(`"`caption'"') label("`label'") colformat("`colformat'") ///
		ncols("`ncols'") bydirection("`bydirection'") ///
		centerstat("`centerstat'") marginstat("`marginstat'") ///
		rowtitle(`"`rowtitle'"') coltitle(`"`coltitle'"') ///
		by("`by'") by_levels("`by_levels'") by_vlab("`by_vlab'") ///
		colgroup(`"`colgroup'"') groups_json(`"`groups_json'"') ///
		rowvar("`rowvar'") colvar("`colvar'") ///
		row_vlab("`row_vlab'") col_vlab("`col_vlab'") ///
		nototal("`nototal'") nr("`nr'") nc("`nc'") ndata("`ndata'") ///
		script("`script'") using("`using'") python("`python'") jsonkeep("`jsonkeep'")

end
