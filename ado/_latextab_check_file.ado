*==============================================================================*
**#	 					【公共工具程序：文件名与覆盖处理】
*==============================================================================*
capture program drop _latextab_check_file
//////////////////////////////////【程序语法】//////////////////////////////////
program define _latextab_check_file
    syntax anything(name=filename), [REPLACE]
	* 0. 去掉 anything 捕获到的外层引号（调用方用引号包裹文件名传入）
	local filename = `filename'
	* 1. 确保带有 .tex 后缀
	if regexm("`filename'", "\.tex$") == 0 {
		local filename "`filename'.tex"
	}
	
	* 2. 核心冲突处理逻辑：重名+序号，有replace则替换
	if fileexists("`filename'") & "`replace'" == "" {
		local original "`filename'"
		local base = subinstr("`filename'", ".tex", "", .)
		local i = 1
		while fileexists("`filename'") {
			local filename "`base'_`i'.tex"
			local i = `i' + 1
		}
		display as text "目标路径存在同名文件 `original'，文件重命名为：`filename'"
	}
		
	* 3. 将最终确定的安全文件名回传给子程序
		c_local using "`filename'"
end