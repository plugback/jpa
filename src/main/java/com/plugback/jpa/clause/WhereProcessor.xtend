package com.plugback.jpa.clause

import com.plugback.active.fields.Data
import com.plugback.jpa.proxy.Call
import java.util.List

class WhereProcessor extends CallsProcessor {

	@Data
	new(List<Pair<String, Object>> parameters) {
	}

	override modifyQuery(StringBuilder query, List<Call> calls) {
		query.append(" WHERE")
		var parameterIndex = 0
		for (var index = 0; index < calls.length; index++) {
			var call = calls.get(index)
			if (index < calls.length - 1 && call.type == "get" && #["like", "greaterThan", "lessThan",
				"greaterEqualsThan", "lessEqualsThan", "notEquals"].contains(calls.get(index + 1).key)) {
				val op = calls.get(index + 1).key
				val operator = switch (op) {
					case "like": "LIKE"
					case "greaterThan": ">"
					case "lessThan": "<"
					case "greaterEqualsThan": ">="
					case "lessEqualsThan": "<="
					case "notEquals": "!="
					default: "notAnOperator"
				}
				if (operator != "notAnOperator") {
					query.append(''' x.«call.key» «operator» :p«parameterIndex»''')
					parameters.add("p" + parameterIndex -> calls.get(index + 1).value)
					index++
					parameterIndex++
				}
			} else if (call.key == "or") {
				query.append(''' or''')
			} else if (call.key == "and") {
				query.append(''' and''')
			} else {
				query.append(''' x.«call.key» = :p«parameterIndex»''')
				parameters.add("p" + parameterIndex -> calls.get(index).value)
				parameterIndex++
			}
		}
		println(query)
	}

}
