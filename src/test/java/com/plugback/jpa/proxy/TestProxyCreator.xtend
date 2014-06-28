package com.plugback.jpa.proxy

import com.plugback.active.properties.Property
import com.plugback.jpa.clause.Where
import org.junit.Test

import static org.junit.Assert.*

class TestProxyCreator {

	@Test
	def void testProxyCreation() {
		val pc = new JavassistProxyCreator
		val proxy = pc.createProxy(TestPojo)
		proxy.x = "ciao"
		proxy.y = "ciao 2"
		proxy.o = 3
		proxy.p = false
		val calls = (proxy as Calls).orderedCalls.map[key -> value]
		assertEquals("[x->ciao, y->ciao 2, o->3, p->false]", calls.toString)
	}

	@Test
	def void testWhereInterface() {
		val pc = new JavassistProxyCreator
		val proxy = pc.createProxy(TestPojo, Where)
		proxy.x = "ciao"
		(proxy as Where).and
		proxy.y = "ciao 2"
		(proxy as Where).and
		proxy.o = 3
		(proxy as Where).and
		proxy.p = false
		val calls = (proxy as Calls).orderedCalls.map[key -> value]
		assertEquals("[x->ciao, and->null, y->ciao 2, and->null, o->3, and->null, p->false]", calls.toString)
	}

	@Test
	def void testWhereInterfaceWithOrAndLike() {
		val pc = new JavassistProxyCreator
		val proxy = pc.createProxy(TestPojo, Where)
		proxy.x = "ciao"
		(proxy as Where).and
		proxy.p = false
		(proxy as Where).and
		proxy.getYoyo()
		(proxy as Where).like("%me%")
		(proxy as Where).or
		proxy.o = 3
		val calls = (proxy as Calls).orderedCalls.map[key -> value]
		assertEquals("[x->ciao, and->null, p->false, and->null, yoyo->null, like->%me%, or->null, o->3]",
			calls.toString)
	}

	@Test
	def void testNestedObject() {
		val pc = new JavassistProxyCreator
		val proxy = pc.createProxy(TestPojo, Where)
		proxy.x = "ciao"
		(proxy as Where).and
		proxy.nestedObject.a = "ok"
		(proxy as Where).or
		proxy.nestedObject.x2.b = "nested ok"
		val calls = (proxy as Calls).orderedCalls.map[key -> value]
		assertEquals("[x->ciao, and->null, nestedObject.a->ok, or->null, nestedObject.x2.b->nested ok]",
			calls.toString)
	}

}

class TestPojo {
	@Property String x
	@Property String y
	@Property String yoyo
	@Property Integer o
	@Property Boolean p
	@Property TestPojo2 nestedObject
}

class TestPojo2 {
	@Property String a
	@Property String b
	@Property TestPojo2 x2
}
