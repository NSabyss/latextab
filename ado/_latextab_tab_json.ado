*==============================================================================*
**#						【子程序：json文件编写与输出】
*==============================================================================*
capture program drop _latextab_tab_json
//////////////////////////////////【程序目标】//////////////////////////////////
* 把 tab 结果序列化成 JSON 配置文件，交给 Python 渲染 LaTeX。
* 结构：header 字段 → columns 数组（表头声明层）→ rows 数组（数据层）。
* 必须与矩阵程序算出的 ncols / ndata 严格对齐。
* 频数/合计列在 Python 端按 centerstat / marginstat 计算百分比，本程序只传原始数值。
/*——————————————————————————————————————————————————————————————————————————————
[入口]
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ 第①步 写 header 字段                                            │
│   template / mode / caption / label / column_format / ncols     │
│   bydirection / centerstat / marginstat / row_title             │
│   有 colvar → col_title     有 by → by_var                      │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ 第②步 写 columns 数组（表头声明层）                             │
│   Q1: colgroup 是否为空？                                        │
└──────────────────────────────────────────────────────────────────┘
  │
  ├── 否 → 【多级表头】
  │    first_header = rowtitle
  │    column_groups = [groups_json]
  │    columns = nc 个列名（无合计列）
  │
  └── 是 → 【常规】
       ├── Q2.1: colvar 非空？【二维】
       │    ├── Q2.1.1: by=="" 或 bydirection=="vertical"？
       │    │    ├── 是 → rowtitle + nc列名 + ["合计" 若无 nototal]
       │    │    └── 否（横向）→ rowtitle + (组名:列名)×sub_nc + ["合计"]
       │    │
       │    └── （无其他分支）
       │
       └── 否 → 【一维】
            ├── Q2.2.1: by 非空 且 horizontal？
            │    ├── 是 → rowtitle + 组名×ngroup
            │    └── 否 → rowtitle + "频数"
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ 第③步 写 rows 数组（数据层）                                    │
│   Q3: by 非空 且 bydirection == "vertical"？                     │
└──────────────────────────────────────────────────────────────────┘
  │
  ├── 是 → 【纵向堆叠】
  │    ① 先数非空组 total_groups（空组 skip，防末尾多逗号）
  │    ② 每组写 Panel 标题行 [\textbf{Panel: 组名}, ndata 个空]
  │    ③ 每组 tabulate → Fg/Rg(/Cg)，逐行写
  │       [rname, nc 频数(缺列填0), null(若无 nototal)]
  │    ④ 最后一组最后一行不加逗号
  │
  └── 否 → 【无分组 / 横向】
       逐行写 [rname, nc 个 F[i,j]]
       if nototal=="" & colvar!="" & colgroup=="" & (by==""|horizontal)
           → 追加 null（合计列占位）
       最后一行不加逗号
  │
  ▼
  file close js → _latextab_finish（调 Python 渲染 + jsonkeep 清理）
——————————————————————————————————————————————————————————————————————————————*/
//////////////////////////////////【程序语法】//////////////////////////////////
program define _latextab_tab_json
	version 19.0
	syntax, ///
		[jsonfile(string) template(string) mode(string) ///
		caption(string) label(string) colformat(string) ///
		ncols(string) bydirection(string) ///
		centerstat(string) marginstat(string) ///
		rowtitle(string) coltitle(string) ///
		by(string) by_levels(string) by_vlab(string) ///
		colgroup(string) groups_json(string) ///
		rowvar(string) colvar(string) ///
		row_vlab(string) col_vlab(string) ///
		nototal(string) nr(string) nc(string) ndata(string) ///
		script(string) using(string) python(string) jsonkeep(string)]

/////////////////////////////【输出 JSON 配置文件】/////////////////////////////
	file open js using "`jsonfile'", write text replace		//	写入覆盖已有文件
	file write js "{" _n									//	开始写json文件
	file write js `"  "template": "`template'", "' _n		//	模板名
	file write js `"  "mode": "`mode'", "' _n				//	模板类型
	file write js `"  "caption": "`caption'", "' _n			//	表题
	file write js `"  "label": "`label'", "' _n				//	表简称
	file write js `"  "column_format": "`colformat'", "' _n	//	列对齐
	file write js `"  "ncols": `ncols', "' _n				//	列数
	file write js `"  "bydirection": "`bydirection'", "' _n	//	分组表格合并方式
	file write js `"  "centerstat": "`centerstat'", "' _n  	//	中间单元格控制
	file write js `"  "marginstat": "`marginstat'", "' _n 	//	边缘单元格控制
	file write js `"  "row_title": "`rowtitle'", "' _n   	//	行标题
	if "`colvar'" != "" {									//	列标题（二维表）
		file write js `"  "col_title": "`coltitle'", "' _n
	}

	if "`by'" != "" {										//	分组变量（如果有）
		file write js `"  "by_var": "`by'", "' _n			//	写入变量名
	}
/////////////////////////////【写入 columns 数组】//////////////////////////////
*【本节任务】
* "表头声明层"：按"有无 colvar × 有无 by × 横向/纵向"四种组合
* 把 columns 数组填满，让 Python 端知道每列该挂什么标题
* 必须与 #3 的 ncols、#4 的 rows 严格对齐。

	if `"`colgroup'"' != "" {
		* 多级表头：first_header + column_groups + columns（无合计列）
		file write js `"  "first_header": "`rowtitle'", "' _n
		file write js `"  "column_groups": [`groups_json'], "' _n
		file write js `"  "columns": ["'
		forvalues j = 1/`nc' {
			local cvalue = C[1,`j']
			local cname "`cvalue'"
			if "`col_vlab'" != "" local cname : label (`colvar') `cvalue'
			if `j' == 1 file write js `""`cname'""'
			else file write js `", "`cname'""'
		}
		file write js "]," _n
	}
	else {
		file write js `"  "columns": [ "`rowtitle'" "'			//	写入行标题
	*——————————————————————————————————————————————————————————————————————————*
	**#【1】					【有列变量的二维表】
	*——————————————————————————————————————————————————————————————————————————*
	if "`colvar'" != "" {									//	【条件行】
	*--------------------------------------------------------------------------*
		if "`by'" == "" | "`bydirection'" == "vertical" {	//	【无分组或纵向堆叠】
	*--------------------------------------------------------------------------*
			forvalues j = 1/`nc' {							//	对每一列循环
				local cvalue = C[1,`j']						//	提取第1行第j列
				local cname "`cvalue'"						//	没值标签就显示数字
				if "`col_vlab'" != "" {						//	有值标签则label
					local cname : label (`colvar') `cvalue'
				}
				file write js `", "`cname'""'				//	写入第1行：列名
			}
			if "`nototal'" == "" file write js `", "合计""'	//	有合计
		}
	*--------------------------------------------------------------------------*
		else {												//	【横向拼接】
	*--------------------------------------------------------------------------*
			foreach g of local by_levels {					//	对分组变量每一层
				local gname "`g'"							//	无标签显示数字
				if "`by_vlab'" != "" {
					local gname : label (`by') `g'		//	有值标签用值标签
				}
				local sub_nc = colsof(C)					//	默认分组内列数相同
				forvalues j = 1/`sub_nc' {					//	对组内每一列循环
					local cvalue = C[1,`j']
					local cname "`cvalue'"
					if "`col_vlab'" != "" {
						local cname : label (`colvar') `cvalue'
					}
					file write js `", "`gname': `cname'""'	//	写入第1行：组名：列名
				}
			}
			if "`nototal'" == "" file write js `", "合计""'	// ← 补这一行
		}
	}
	*——————————————————————————————————————————————————————————————————————————*
	**#【2】					【无列变量的一维表】
	*——————————————————————————————————————————————————————————————————————————*
	else {													//	【条件行】
	*--------------------------------------------------------------------------*
		if "`by'" != "" & "`bydirection'" == "horizontal" {	//	【横向拼接】
	*--------------------------------------------------------------------------*
			foreach g of local by_levels {
				local gname "`g'"
				if "`by_vlab'" != "" local gname : label (`by') `g'
				file write js `", "`gname'""'
			}
		}
	*--------------------------------------------------------------------------*
		else {												//	【无by，或纵向堆叠】
	*--------------------------------------------------------------------------*
			file write js `", "频数""'
		}
	}
	file write js "]," _n										//	行标题处理完毕

	}

/////////////////【写入 rows 数组（区分纵向堆叠和常规/横向）】//////////////////
	file write js `"  "rows": ["' _n						//	写入列数组
	*——————————————————————————————————————————————————————————————————————————*
	**#【1】			【有分组且纵向堆叠二维表】
	*——————————————————————————————————————————————————————————————————————————*
	if "`by'" != "" & "`bydirection'" == "vertical" {		//	【条件行】
	*--------------------------------------------------------------------------*
		* 先数非空组，空组 continue 跳过
		local total_groups = 0
		foreach g of local by_levels {
			quietly count if `by' == `g' & !missing(`rowvar')
			if r(N) > 0 local total_groups = `total_groups' + 1
		}
		local g_cnt = 1

		foreach g of local by_levels {						//	处理每组表头标题
			* 先判空，再 tabulate
			quietly count if `by' == `g' & !missing(`rowvar')
			if r(N) == 0 continue
			* 组名
			local gname "`g'"
			if "`by_vlab'" != "" local gname : label (`by') `g'

			* 写入组别小标题行（作为 Panel 分隔）
			file write js `"    ["\\textbf{Panel: `gname'}""'
			forvalues j = 1/`ndata' {						//	写ndata个
				file write js `", """'						//	空字符串占位
			}
			file write js "]," _n

			* 获取该组的矩阵（2D 需 matcol 用于列对齐；1D 无列变量）
			if "`colvar'" != "" {
				quietly tabulate `rowvar' `colvar' 			///
					if `by' == `g', matcell(Fg) matrow(Rg) matcol(Cg)
			}
			else {
				quietly tabulate `rowvar' if `by' == `g', matcell(Fg) matrow(Rg)
			}

			local nr_g = rowsof(Fg)							//	该组行数储存

			forvalues i = 1/`nr_g' {						//	对组内每行
				local rvalue = Rg[`i',1]					//	第i行第1列：标签
				local rname "`rvalue'"
				if "`row_vlab'" != "" {
					local rname : label (`rowvar') `rvalue'
				}

				file write js `"    ["`rname'""'			//	写入行名

				if "`colvar'" != "" {						//	有列变量的情况下
					local ncfg = colsof(Fg)					//	本组实际列数
					forvalues j = 1/`nc' {					//	对每列循环
						local x = 0							//	默认0（该列在本组缺失）
						forvalues cj = 1/`ncfg' {			//	在组内矩阵中找该列
							if Cg[1,`cj'] == C[1,`j'] {
								local x = Fg[`i',`cj']
								continue, break
							}
						}
						file write js `", `x'"'  	// 传原始数值给 Python 算百分比
					}
					if "`nototal'" == "" {
						file write js `", null"' 	// 合计列占位
					}
				}
				else {
					local x = Fg[`i',1]
					file write js `", `x'"'
				}

				* 判断是否是最后一行
				if `g_cnt' == `total_groups' 		///	这是前面数的分组数
					& `i' == `nr_g' {				//	最后一组、最后一行
					file write js "]" _n			//	不要逗号
				}
				else {
					file write js "]," _n			//	前面都要逗号
				}
			}
			local g_cnt = `g_cnt' + 1
		}
	}
	*——————————————————————————————————————————————————————————————————————————*
	**#【2】			【无分组或横向拼接】
	*——————————————————————————————————————————————————————————————————————————*
	else {											//	【条件行】
	*--------------------------------------------------------------------------*
		forvalues i = 1/`nr' {
			local rvalue = R[`i',1]					//	每行第一列
			local rname "`rvalue'"
			if "`row_vlab'" != "" {					//	有标签用行标签
				local rname : label (`rowvar') `rvalue'
			}

			file write js `"    ["`rname'""'

			forvalues j = 1/`nc' {
				local x = F[`i',`j']
				file write js `", `x'"'  			// 传原始数值给 Python 算百分比
			}

			if "`nototal'" == "" & "`colvar'" != "" & "`colgroup'" == "" & ///
				("`by'" == "" | "`bydirection'" == "horizontal") {
				file write js `", null"'
			}

			if `i' < `nr' file write js "]," _n
			else file write js "]" _n
		}
	}

	file write js "  ]" _n
	file write js "}" _n
	file close js
//////////////////【公共工具程序：调用 Python 引擎与结果反馈】//////////////////
	_latextab_finish, ///
	script("`script'") using("`using'") python("`python'") ///
	jsonfile("`jsonfile'") jsonkeep("`jsonkeep'")

end
