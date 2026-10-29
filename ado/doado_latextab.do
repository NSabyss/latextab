*=============================================================================*
**#1					【doado_latextab.do：安装与配置入口】
*=============================================================================*
//////////////////////////////////【用法】//////////////////////////////////
* 先 cd 到仓库根目录（code_py/ 与 ado/ 所在目录），再运行：  do doado_latextab.do
* 或放进 profile.do 里自动加载（需先 cd 到仓库根）。
* 作用：① 把 latextab 的 ado 目录加入搜索路径；② 定义工具路径全局宏。
* 换机器 / 换目录时本文件基本无需改动（root/ado 自动取当前目录）；
* 仅当 python 不在 PATH 时，把 LATEXTAB_PYTHON 改成完整路径。
//////////////////////////////////【可改路径】//////////////////////////////////
* 1. 工具根目录（retex.py / json2tex.py / templates 所在目录）= 当前工作目录
global LATEXTAB_ROOT   "`c(pwd)'"

* 2. Python 解释器（需装 jinja2）。默认走 PATH 里的 python；
*    若用虚拟环境或 python 不在 PATH，改成完整路径，例如：
*    global LATEXTAB_PYTHON "F:\.venv\Scripts\python.exe"
global LATEXTAB_PYTHON "python"

* 3. ado 目录（latextab.ado 等所在目录）= 当前目录/ado
global LATEXTAB_ADO    "`c(pwd)'/ado"

* 4. 可选：若想单独覆盖两个 Python 脚本路径，取消注释并按需改
* global LATEXTAB_SCRIPT "`c(pwd)'/code_py/json2tex.py"
* global LATEXTAB_RETEX  "`c(pwd)'/code_py/retex.py"

//////////////////////////////////【加入搜索路径】//////////////////////////////////
adopath + "$LATEXTAB_ADO"

//////////////////////////////////【回显确认】//////////////////////////////////
display as text "latextab 配置完成：" _n ///
	"  ROOT   = $LATEXTAB_ROOT" _n ///
	"  PYTHON = $LATEXTAB_PYTHON" _n ///
	"  ADO    = $LATEXTAB_ADO"
