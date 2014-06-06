package com.plugback.jpa.clause

import com.plugback.jpa.proxy.Call
import java.util.List

class OrderByProcessor extends CallsProcessor {

	override modifyQuery(StringBuilder query, List<Call> calls) {
		query.append(" ORDER BY")
		calls.forEach [ call |
			if (call.key == "asc" || call.key == "desc")
				query.append(" " + call.key)
			else
				query.append(" x." + call.key)
		]
	}

}
