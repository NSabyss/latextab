*==============================================================================*
**#                     【公共工具程序：收尾与Python调用】
*==============================================================================*
capture program drop _latextab_finish
//////////////////////////////////【程序语法】//////////////////////////////////
program define _latextab_finish
    syntax, script(string) using(string) python(string) ///
	[jsonfile(string) jsonkeep(string)]

//////////////////////////////////【程序定义】//////////////////////////////////
    * 1. 组装并调用 Python 引擎
    * 如果外部没传 jsonfile，则尝试直接读取默认宏
    if "`jsonfile'" == "" local jsonfile "`jsonfile'" 
    
    local cmd `""`python'" "`script'" "`jsonfile'" "`using'""'
    shell `cmd'

    * 2. 打印生成提示与可点击超链接
    display as result "LaTeX table generated: " _n ///
        `"{view "`using'":`using'}"'
        
    * 3. 计算跨平台（正斜杠）的绝对路径
    mata: st_local("fullpath", pathresolve(c("pwd"), st_local("using")))
    local fullpath = subinstr("`fullpath'", "\", "/", .)

    * 4. 打印友好的成功保存提示
    display as text ""
    display as result " LaTeX表格已保存至："
    display as text " `fullpath'"
    display as text ""

    * 5. 根据 jsonkeep 开关决定是否清理中间 JSON 文件
    * 如果 jsonkeep 不等于 1（即为 0 或未定义），则自动擦除中间文件
    if "`jsonkeep'" != "1" {
        capture erase "`jsonfile'"
    }
end