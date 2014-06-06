package com.plugback.jpa.clause

import com.plugback.jpa.proxy.Call
import com.plugback.jpa.proxy.Calls
import java.util.List

abstract class CallsProcessor {

	def <T> shouldProcess(Calls proxyObject) {
		getCalls(proxyObject).size != 0
	}

	def <T> getCalls(Calls proxyObject) {
		proxyObject.orderedCalls
	}

	def void process(StringBuilder query, Calls proxyObject) {
		if (proxyObject.shouldProcess) {
			var calls = proxyObject.calls
			modifyQuery(query, calls)
		}
	}

	abstract def void modifyQuery(StringBuilder query, List<Call> calls);

}
