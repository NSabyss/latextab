*==============================================================================*
**#						【公共工具程序：公共参数默认值】
*==============================================================================*
capture program drop _latextab_set_defaults
//////////////////////////////////【程序语法】//////////////////////////////////
program define _latextab_set_defaults
    syntax, ///
	type(string) 									///	必选：子程序名
	[												///	可选
	mode(string) 									///	模式
	caption(string) 								///	标题
	label(string)									///	标签
	using(string)									///	文件
	orientation(string)									///	方向 portrait/landscape
	json(string)								///	json地址与是否开启
	]
//////////////////////////////////【默认模式】//////////////////////////////////
	if "`mode'" == "" {
		local mode "independ"						//	默认为independe方便查看
	}
	else if !inlist("`mode'", 						/// 不在可选模板范围内则报错
		"input", "independ") {
		di as error 								///	报错信息
		"mode() must be input (用于直接插入论文) or independ (用于独立编译)"
		exit 198
	}

	//////////////////////////////【默认方向】//////////////////////////////
	if "`orientation'" == "" {
		local orientation "portrait"				//	默认纵向
	}
	else if !inlist("`orientation'", "portrait", "landscape") {
		di as error "orientation() must be portrait (纵向) or landscape (横向)"
		exit 198
	}

///////////////////////////【默认标题、标签和文件名】///////////////////////////
* 用base来填充空值
* 如果caption label using三项都没有指定，则以type为base
* 如果有任意一项制定了，则按优先级捕获第一个非空的值作为 base (标题 > 文件名 > 标签)
	if `"`caption'"' == "" & "`label'" == "" & "`using'" == "" {
		local base "`type'"
	}
	else {
		if `"`caption'"' != "" {
			local base `"`caption'"'
		}
		else if "`using'" != "" {
			local base = subinstr("`using'", ".tex", "", .)
		}
		else {
			local base "`label'"
		}
	}

* 【核心填充逻辑：空的填 base，非空保持原值】
	if `"`caption'"' == "" {
		local caption "`base'"
	}
	if "`label'" == "" {
		local label "`base'"
	}
	if "`using'" == "" {
		local using "`base'"
	}
//////////////////////////////【JSON文件管理设置】//////////////////////////////
*【解析复合选项 json(path, clean)】
    local json_path ""
    local json_keep ""
    
    if "`json'" != "" {
        * 1. 检查用户输入中是否包含逗号
        local has_comma = strpos("`json'", ",")
        
        if `has_comma' > 0 {
            * 有逗号：说明既有路径，又有开关（如：path.json, off）
            local json_path = strtrim(substr("`json'", 1, `has_comma'-1))
            local json_keep = strtrim(substr("`json'", `has_comma'+1, .))
        }
        else {
            * 无逗号：需要判断用户写的是开关(1/0)还是纯路径
			local arg = strtrim(`"`json'"')
			if inlist("`arg'", "0", "1") {
				local json_keep "`arg'"
			}
			else {
				local json_path "`arg'"
			}
		}
	}

    * 2. 赋予最终的默认值兜底
    * 如果用户没传路径，则使用默认的临时 JSON 路径
    if "`json_path'" == "" {
        	local jsonfile "`base'.json"
    }
    else {
        local jsonfile "`json_path'"
    }
    
    * 如果用户没传开关，则默认设为 0（不保留json文件，即生成后自动清理）
    if "`json_keep'" == "" {
        local jsonkeep "0"
    }
    else {
        local jsonkeep "`json_keep'"
    }
////////////////////////////////【回传给子程序】////////////////////////////////
	c_local mode       "`mode'"
	c_local label      "`label'"
	c_local caption    `"`caption'"'
	c_local using      "`using'"
	c_local jsonfile   "`jsonfile'"
	c_local jsonkeep   "`jsonkeep'"			// 回传保留开关 (1=保留, 0=不保留)
	c_local orientation "`orientation'"			// 回传方向
end
