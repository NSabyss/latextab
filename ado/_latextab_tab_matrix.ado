*==============================================================================*
**#						【子程序：tabulate 矩阵提取】
*==============================================================================*
capture program drop _latextab_tab_matrix
//////////////////////////////////【程序目标】//////////////////////////////////
* 把 tabulate 的结果统一成三个矩阵 F / R / C，并算出 nr / nc / ndata / ncols，
* 供 JSON 编写时直接取数。矩阵为全局对象，主程序可直接按名访问 F / R / C。
* 矩阵	内容								形状		来源
* F		频数矩阵							nr × nc		tabulate ... matcell(F)
* R		行变量每个类别的取值（不是标签）	nr × 1		tabulate ... matrow(R)
* C		列变量每个类别的取值				1 × nc		tabulate ... matcol(C)
* 【用tabulate而非table】
* table 依赖 collect 框架，要 collect export 或把结果转存到临时 frame 中，
* 在定制化输出 JSON 时会增加额外的解析负担。
/*——————————————————————————————————————————————————————————————————————————————
[入口]
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Q1: by 是否为空？                                                │
└──────────────────────────────────────────────────────────────────┘
  │
  ├── 是 → 【#1 无分组】
  │    ├── colvar 非空？
  │    │    ├── 是 → 二维 tabulate：F=matcell  R=matrow  C=matcol
  │    │    │    nr = rowsof(F)   nc = colsof(F)
  │    │    └── 否 → 一维 tabulate：F=matcell  R=matrow
  │    │         nr = rowsof(F)   nc = 1
  │    └── F/R/C 为全局对象，主程序按名取用
  │
  └── 否 → 【有分组】
       ├── Q2: bydirection == "horizontal"？
       │    ├── 是 → 【#2 横向拼接】
       │    │    ① 整体 tabulate → 并集 R_all / C_all（nr, ncg）
       │    │    ② 每组 tabulate → Fg/Rg/Cg，对齐到并集网格
       │    │      缺失行/列填 0 → Fg_aligned
       │    │      横向拼接 F_combined = (F_combined, Fg_aligned)
       │    │    ③ F=F_combined  R=R_all  C=C_all
       │    │       nr = rowsof(F)   nc = colsof(F)   ← 拼接后总列数，勿乘 ngroup
       │    │
       │    └── 否 → 【#3 纵向堆叠】
       │         列结构保持单组，行结构多组上下排（不做矩阵拼接）
       │         只算 R / C / nc，不设全局 F（每组 Fg 在 json 阶段按组 tabulate）
       │         colvar 非空 → R/C，nc = colsof(F_dummy)；否则 → R，nc = 1
       │
       ▼
┌──────────────────────────────────────────────────────────────────┐
│ 【汇合：colgroup 校验 + 列宽/模板 + 回传】                       │
│   colgroup 非空 → 校验 total_span == nc（不等则 r198）          │
│   ndata = nc                                                     │
│   if colvar!="" & nototal=="" & colgroup=="" → ndata += 1（合计列）│
│   ncols = ndata + 1（总列数 = 数据列 + 行标题列）                │
│   colformat 默认 = "l" + "c"×ndata                               │
│   template 默认：colgroup→01 / ncols≤7→01 / 其余→05 横向宽表    │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
c_local 回传：nr nc ndata ncols colformat template
——————————————————————————————————————————————————————————————————————————————*/
//////////////////////////////////【程序语法】//////////////////////////////////
program define _latextab_tab_matrix
	version 19.0
	syntax, ///
		[rowvar(string) colvar(string) ///
		by(string) bydirection(string) by_levels(string) ///
		colgroup(string) total_span(string) nototal(string) ///
		template(string) colformat(string)]

	*——————————————————————————————————————————————————————————————————————————*
	**#【1】						【无分组】
	*——————————————————————————————————————————————————————————————————————————*
	if "`by'" == "" {								//	【条件行】
	*--------------------------------------------------------------------------*
		if "`colvar'" != "" {						//	【二维表条件行】
	*--------------------------------------------------------------------------*
			quietly tabulate `rowvar' `colvar', 	///	静默执行二维tab
			matcell(F) 								///	每个单元格频数保存到矩阵F
			matrow(R) 								///	行变量类别取值保存到矩阵R
			matcol(C)								//	列变量类别取值保存到矩阵C
			local nr = rowsof(F)					//	提取行数
			local nc = colsof(F)					//	提取列数
		}
	*--------------------------------------------------------------------------*
		else {										//	【一维表条件行】
	*--------------------------------------------------------------------------*
			quietly tabulate `rowvar', matcell(F) matrow(R)
			local nr = rowsof(F)
			local nc = 1
		}
	}
	*——————————————————————————————————————————————————————————————————————————*
	**#【2】						【有分组-横向拼接】
	*——————————————————————————————————————————————————————————————————————————*
	else if "`bydirection'" == "horizontal" {		//	【条件行】
	*--------------------------------------------------------------------------*
	* 先做一次整体 tabulate，得到行/列类别的并集，作为各组矩阵对齐的基准。
	* 否则各组行/列类别不一致时，直接横向拼接会报 conformability error (r503)。
		if "`colvar'" != "" {						//	【二维表条件行】
			quietly tabulate `rowvar' `colvar', 	///	整体二维tab
				matcell(F_all) matrow(R_all) matcol(C_all)
			local nr = rowsof(R_all)				//	并集行数
			local ncg = colsof(C_all)				//	并集列类别数
		}
		else {										//	【一维表条件行】
			quietly tabulate `rowvar', matcell(F_all) matrow(R_all)
			local nr = rowsof(R_all)
			local ncg = 1
		}

		tempname F_combined
		local group_idx = 1							//	定义分组宏
		foreach g of local by_levels {				//	对每一个分组类别
			if "`colvar'" != "" {
				quietly tabulate `rowvar' `colvar' 	///
					if `by' == `g', 				///	按by变量的每个类别做tab
					matcell(Fg) matrow(Rg) matcol(Cg)
			}
			else {
				quietly tabulate `rowvar' if `by' == `g', matcell(Fg) matrow(Rg)
			}
		* 把本组矩阵对齐到并集网格（缺失的行/列填 0）
			tempname Fg_aligned
			matrix `Fg_aligned' = J(`nr', `ncg', 0)
			local nrg = rowsof(Rg)
			forvalues i = 1/`nr' {					//	遍历并集行
				local rv = R_all[`i',1]
				local ri = 0
				forvalues k = 1/`nrg' {				//	在组内矩阵中找该行
					if Rg[`k',1] == `rv' {
						local ri = `k'
						continue, break
					}
				}
				if `ri' == 0 continue				//	该行在本组缺失，保持0
				if "`colvar'" != "" {
					local ncfg = colsof(Fg)			//	本组实际列数
					forvalues j = 1/`ncg' {			//	遍历并集列
						local cv = C_all[1,`j']
						local cj = 0
						forvalues k = 1/`ncfg' {
							if Cg[1,`k'] == `cv' {
								local cj = `k'
								continue, break
							}
						}
						if `cj' > 0 {
							matrix `Fg_aligned'[`i',`j'] = Fg[`ri',`cj']
						}
					}
				}
				else {
					matrix `Fg_aligned'[`i',1] = Fg[`ri',1]
				}
			}
			if `group_idx' == 1 {
				matrix `F_combined' = `Fg_aligned'
			}
			else {
				matrix `F_combined' = (`F_combined', `Fg_aligned')
			}
			local group_idx = `group_idx' + 1
		}
		matrix F = `F_combined'
		matrix R = R_all
		if "`colvar'" != "" matrix C = C_all
		local nr = rowsof(F)						//	拼接后总行数
		local nc = colsof(F)						//	拼接后总列数
	}
	*——————————————————————————————————————————————————————————————————————————*
	**#【3】						【有分组-纵向堆叠】
	*——————————————————————————————————————————————————————————————————————————*
		else {										//	【条件行】
		* 纵向模式下，列结构保持单组不变，行结构变成多组上下排列
		* 横向改变了列（需要提前拼矩阵算总列宽）
		* 纵向只增加了行，列结构不变，数据在写入 JSON 时按 group 循环提取即可
	*--------------------------------------------------------------------------*
		if "`colvar'" != "" {						//	【二维表条件行】
	*--------------------------------------------------------------------------*
			quietly tabulate `rowvar' `colvar', matcell(F_dummy) matrow(R) matcol(C)
			local nc = colsof(F_dummy)
		}
	*--------------------------------------------------------------------------*
		else {										//	【一维表条件行】
	*--------------------------------------------------------------------------*
			quietly tabulate `rowvar', matcell(F_dummy) matrow(R)
			local nc = 1
		}
	}
*【colgroup 跨度校验】（nc 已在 #3 算好，此处校验）
	if `"`colgroup'"' != "" {
		if `total_span' != `nc' {
			di as error "colgroup() 跨度之和 (`total_span') 必须等于列变量类别数 (`nc')"
			exit 198
		}
	}

///////////////////////////////【模板与列宽计算】///////////////////////////////
	local ndata = `nc'								//	【基础数据列数】

	if "`colvar'" != "" & "`nototal'" == "" & "`colgroup'" == "" {		//	【合计列】
		local ndata = `ndata' + 1					//	+1
	}

	local ncols = `ndata' + 1						//	【总列数】=数据列+1个行标题列

/////////////////////////////【特殊参数：行列格式】/////////////////////////////
	if "`colformat'" == "" {
		local colformat "l"							//	默认格式为lcccccc……
		forvalues j = 1/`ndata' {
			local colformat "`colformat'c"
		}
	}

/////////////////////////////【特殊参数：模板选择】/////////////////////////////
	if "`template'" == "" | "`template'" == "auto" {
		if `"`colgroup'"' != "" local template "01_基础三线表.tex"
		else if `ncols' <= 7 local template "01_基础三线表.tex"
		else local template "05_横向宽表.tex"
	}

////////////////////////////////【回传给主程序】////////////////////////////////
	c_local nr        "`nr'"
	c_local nc        "`nc'"
	c_local ndata     "`ndata'"
	c_local ncols     "`ncols'"
	c_local colformat "`colformat'"
	c_local template  "`template'"
end
