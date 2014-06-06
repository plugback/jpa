package com.plugback.jpa.proxy

import java.util.List
import javassist.util.proxy.MethodHandler
import javassist.util.proxy.ProxyFactory

class JavassistProxyCreator {

	def <T> T createProxy(Class<T> originalClass, Class<?>... additionalInterfaces) {
		val calls = new CallsImpl
		val prefix = ""
		createProxyWithCalls(originalClass, calls, prefix, additionalInterfaces)
	}

	private def <T> T createProxyWithCalls(Class<T> originalClass, CallsImpl calls, String prefix,
		Class<?>... additionalInterfaces) {
		val MethodHandler operation = [ selfObject, thisMethod, proceed, args |
			if (thisMethod.name == "getOrderedCalls")
				return calls.orderedCalls
			else {

				val syntethicMethod = proceed == null
				var returnedObject = if (proceed != null) {
						proceed.invoke(selfObject, args)
					} else
						null
				if (thisMethod.name.startsWith("get") && returnedObject == null && proceed != null &&
					proceed.returnType == Long)
					returnedObject = -5555555555L
				val returnedSelfObject = returnedObject == selfObject
				val returnedPrimitiveType = thisMethod.returnType.primitive || #[Integer, Long, Double, String, Float,
					Character, Byte, Short, Void].contains(thisMethod.returnType)
				if (syntethicMethod || returnedPrimitiveType || returnedSelfObject) {
					val value = if(args.size > 0) args.get(0) else null
					val type = if (thisMethod.name.startsWith("get"))
							"get"
						else if (thisMethod.name.startsWith("set"))
							"set"
						else if(thisMethod.name.startsWith("is")) "is" else "unknown"
					val c = new Call(prefix + normalize(thisMethod.name), value, type)
					calls.orderedCalls.add(c)
					return returnedObject
				} else {
					if (!returnedSelfObject)
						return createProxyWithCalls(thisMethod.returnType, calls,
							prefix + normalize(thisMethod.name) + ".")
				}
			}
		]
		val factory = new ProxyFactory
		factory.setSuperclass(originalClass)
		factory.setInterfaces(originalClass.interfaces + #[Calls] + additionalInterfaces)
		val x = factory.create(<Class<?>>newArrayOfSize(0), newArrayOfSize(0), operation) as T
		return x
	}

	private def normalize(String methodName) {
		if (methodName.startsWith("get") || methodName.startsWith("set"))
			return methodName.substring(3).toFirstLower
		if (methodName.startsWith("is"))
			return methodName.substring(2).toFirstLower
		else
			return methodName
	}

}

@Data
class Call {
	String key
	Object value
	String type
}

interface Calls {
	def List<Call> getOrderedCalls();
}

class CallsImpl implements Calls {

	val calls = <Call>newArrayList

	override getOrderedCalls() {
		return calls
	}

}
