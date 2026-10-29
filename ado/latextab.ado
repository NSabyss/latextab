*==============================================================================*
**#1					【stata表格 to latex表格程序介绍】
*==============================================================================*
//////////////////////////////////【程序功能】//////////////////////////////////
* 主程序
//////////////////////////////////【程序结构】//////////////////////////////////
* Stata -> esttab/collect -> tex -> retex换表头 -> LaTeX 三线表
//////////////////////////////////【程序预备】//////////////////////////////////
* 预删除防重复
capture program drop latextab
* latextab v0.3.0                                  	//  程序包版本
*==============================================================================*
**#2					【主程序：路由分发器】
*==============================================================================*
program define latextab                             //  开始定义程序
	version 19.0                                    //  适用 Stata 版本

	*【公共路径定义：全局宏优先，缺失则报错提示先运行安装入口】
	* 安装时在 doado_latextab.do 里定义 LATEXTAB_ROOT / LATEXTAB_PYTHON（可再细分
	* LATEXTAB_SCRIPT / LATEXTAB_RETEX），本程序据此自动推导。
	if `"$LATEXTAB_ROOT"' != "" {
		local root `"$LATEXTAB_ROOT"'
	}
	else {
		di as error "LATEXTAB_ROOT 未定义：请先 cd 到仓库根目录并运行 do doado_latextab.do"
		exit 198
	}
	if `"$LATEXTAB_PYTHON"' != "" {
		local python `"$LATEXTAB_PYTHON"'
	}
	else {
		di as error "LATEXTAB_PYTHON 未定义：请先 cd 到仓库根目录并运行 do doado_latextab.do"
		exit 198
	}
	if `"$LATEXTAB_SCRIPT"' != "" {
		local script `"$LATEXTAB_SCRIPT"'
	}
	else {
		local script "`root'/code_py/json2tex.py"    //  list 等 Jinja2 模板渲染
	}
	if `"$LATEXTAB_RETEX"' != "" {
		local retex `"$LATEXTAB_RETEX"'
	}
	else {
		local retex "`root'/code_py/retex.py"        //  reg/tab/stat/table 换表头
	}

	*【命令抓取：第一个词为子命令】
	gettoken subcmd 0 : 0, parse(" ,")

	*【程序分发】剩下的参数根据子命令分发
	if "`subcmd'" == "tab" {
		_latextab_collect `0' type(tab) python(`python') retex(`retex')
	}
	else if "`subcmd'" == "stat" {
		_latextab_collect `0' type(stat) python(`python') retex(`retex')
	}
	else if "`subcmd'" == "table" {
		_latextab_collect `0' type(table) python(`python') retex(`retex')
	}
	else if "`subcmd'" == "list" {
		_latextab_list `0' root(`root') script(`script') python(`python')
	}
	else if "`subcmd'" == "reg" {
		_latextab_reg `0' python(`python') retex(`retex')
	}
	else {
		di as error "subcommand `subcmd' not found. Must be tab, stat, table, list, or reg."
		exit 198
	}
end
