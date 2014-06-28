package com.plugback.jpa

import com.plugback.active.properties.Property
import java.lang.annotation.Retention
import java.lang.annotation.RetentionPolicy
import java.text.SimpleDateFormat
import java.util.Date
import java.util.concurrent.Executors
import javax.persistence.Entity
import javax.persistence.Id
import javax.persistence.Temporal
import javax.persistence.TemporalType
import org.junit.After
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test

import static org.junit.Assert.*

import static extension com.plugback.jpa.DBX.*

class TestDBExtension extends DBTest {

	@BeforeClass
	def static initDBWithSomeData() {
		new TestDBExtension().insertSomeData
	}

	@Before
	def void inserData() {
	}

	@After
	def void clearDB() {
		//clear(TestUserPojo)
	}

	@Concurrent
	@Test
	def void testDBWhereQuery() {
		val result = db.find(TestUserPojo).where[email = "me@salvatoreromeo.com"].resultList
		assertEquals(1, result.size)
		assertEquals("me@salvatoreromeo.com", result.get(0).email)
	}

	@Concurrent
	@Test
	def void testDBWhereQuery2() {
		val result = db.find(TestUserPojo).where[name = "romeo"].resultList
		assertEquals(2, result.size)
		assertTrue(result.filter[email == "me@salvatoreromeo.com"].size == 1)
		assertTrue(result.filter[email == "me2@salvatoreromeo.com"].size == 1)
	}

	@Concurrent
	@Test
	def void testDBWhereQueryOrOnSameField() {
		val result = db.find(TestUserPojo).where[id = 1L or id = 2L].resultList
		assertEquals(2, result.size)
		assertTrue(result.filter[email == "me@salvatoreromeo.com"].size == 1)
		assertTrue(result.filter[email == "me2@salvatoreromeo.com"].size == 1)
	}

	@Concurrent
	@Test
	def void testDBWhereQueryOrOnSameField2() {
		val result = db.find(TestUserPojo).where[name = "romeo" or name = "salvatore"].resultList
		assertEquals(3, result.size)
	}

	@Concurrent
	@Test
	def void testDBWhereQueryOrOnDifferentField() {
		val result = db.find(TestUserPojo).where[id = 1L or name = "romeo"].resultList
		assertEquals(2, result.size)
		assertTrue(result.filter[email == "me@salvatoreromeo.com"].size == 1)
		assertTrue(result.filter[email == "me2@salvatoreromeo.com"].size == 1)
	}

	@Concurrent
	@Test
	def void testDBWhereQueryAnd() {
		val result = db.find(TestUserPojo).where[id = 1L and name = "romeo"].resultList
		assertEquals(1, result.size)
		assertTrue(result.filter[email == "me@salvatoreromeo.com"].size == 1)
	}

	@Test
	def void testSort() {
		insertIntoDB(new TestUserPojo => [id = 4L name = "fausta"])
		val result = db.find(TestUserPojo).where[name = "romeo" or name = "salvatore" or name = "fausta"].orderBy[name].
			resultList
		assertEquals(4, result.size)
		assertEquals("fausta", result.get(0).name)
		assertEquals("salvatore", result.get(3).name)

		db.transaction.begin
		db.remove(db.find(TestUserPojo).where[name = "fausta"].singleResult)
		db.transaction.commit
	}

	@Test
	def void testSortAsc() {
		insertIntoDB(new TestUserPojo => [id = 4L name = "fausta"])
		val result = db.find(TestUserPojo).where[name = "romeo" or name = "salvatore" or name = "fausta"].orderBy[name
			asc].resultList
		assertEquals(4, result.size)
		assertEquals("fausta", result.get(0).name)
		assertEquals("salvatore", result.get(3).name)

		db.transaction.begin
		db.remove(db.find(TestUserPojo).where[name = "fausta"].singleResult)
		db.transaction.commit
	}

	@Test
	def void testSortDesc() {
		insertIntoDB(new TestUserPojo => [id = 4L name = "fausta"])
		val result = db.find(TestUserPojo).where[name = "romeo" or name = "salvatore" or name = "fausta"].orderBy[name
			desc].resultList
		assertEquals(4, result.size)
		assertEquals("fausta", result.get(3).name)
		assertEquals("salvatore", result.get(0).name)

		db.transaction.begin
		db.remove(db.find(TestUserPojo).where[name = "fausta"].singleResult)
		db.transaction.commit
	}

	@Concurrent
	@Test
	def void testLike() {
		val result = db.find(TestUserPojo).where[email like("%me%")].resultList
		assertEquals(3, result.size)
	}

	@Concurrent
	@Test
	def void testLikeWithSort() {
		val result = db.find(TestUserPojo).where[email like("%me%")].orderBy[name desc].resultList
		assertEquals(3, result.size)
		assertEquals("salvatore", result.get(0).name)
	}

	@Concurrent
	@Test
	def void testDoubleLike() {
		val result = db.find(TestUserPojo).where[email like("%me%") and name like("%ro%")].orderBy[name desc].resultList
		assertEquals(2, result.size)
	}

	@Concurrent
	@Test
	def void testDoubleLikeAndEquals() {
		val result = db.find(TestUserPojo).where[email like("%me%") and name like("%ro%") and id = 1L].orderBy[name desc].
			resultList
		assertEquals(1, result.size)
	}

	@Test
	def void testPagination() {
		val result = db.find(TestUserPojo).where[email like("%me%")].orderBy[name desc].resultList[page = 1]
		assertEquals(3, result.size)
	}

	@Test
	def void testPagination2() {
		val result = db.find(TestUserPojo).where[email like("%me%")].orderBy[name desc].resultList[page = 1 size = 2]
		assertEquals(2, result.size)
	}

	@Test
	def void testPagination3() {
		val result = db.find(TestUserPojo).where[email like("%me%")].orderBy[name desc].resultList[page = 2 size = 2]
		assertEquals(1, result.size)
	}

	@Test
	def void testPagination4() {
		val result = db.find(TestUserPojo).resultList[page = 2 size = 2]
		assertEquals(1, result.size)
	}

	@Test
	def void concurrentTest() {
		val tests = TestDBExtension.methods.filter[isAnnotationPresent(Test) && isAnnotationPresent(Concurrent)]
		val es = Executors.newCachedThreadPool
		for (p : 1 .. 1000) {
			val rn = Math.round(((Math.random() * (tests.size - 1)))).intValue
			val test = tests.get(rn)
			es.execute(
				[ |
					println('''starting test «p»: «test.name»''')
					val t = new TestDBExtension()
					try {
						test.invoke(t)
					} catch (Exception e) {
						throw e
					}
					println('''just executed test «p»: «test.name»''')
				])
		}
		es.shutdown()
	}

	@Test(timeout=10000)
	def void performanceTest() {
		val tests = TestDBExtension.methods.filter[isAnnotationPresent(Test) && isAnnotationPresent(Concurrent)]
		for (i : 1 .. 1000) {
			val rn = Math.round(((Math.random() * (tests.size - 1)))).intValue
			val test = tests.get(rn)
			test.invoke(new TestDBExtension)
		}
	}

	def insertSomeData() {
		val tdb = emf.createEntityManager
		tdb.transaction.begin
		val px = new TestUserPojo => [id = 1L email = "me@salvatoreromeo.com" name = "romeo"]
		val py = new TestUserPojo => [id = 2L email = "me2@salvatoreromeo.com" name = "romeo"]
		val pz = new TestUserPojo => [id = 3L email = "me3@salvatoreromeo.com" name = "salvatore"]
		tdb.merge(px)
		tdb.merge(py)
		tdb.merge(pz)
		tdb.transaction.commit
	}

	def insertIntoDB(Object... o) {
		val tdb = emf.createEntityManager
		tdb.transaction.begin
		o.forEach[tdb.merge(it)]
		tdb.transaction.commit
	}

	def clear(Class<?>... cs) {
		val tdb = emf.createEntityManager
		tdb.transaction.begin
		cs.forEach[tdb.find(it).resultList.forEach[tdb.remove(it)]]
		tdb.transaction.commit
	}

	@Concurrent
	@Test
	def void testGreaterThan() {
		val a = 1
		val b = 2
		assertTrue(b > a)
		assertFalse(a > b)
		val al = new Long(a)
		val bl = new Long(b)
		assertTrue(bl > al)
		assertFalse(al > bl)

		val result = db.find(TestUserPojo).where[id > 0].resultList
		assertEquals(3, result.size)
		assertTrue(result.filter[email == "me@salvatoreromeo.com"].size == 1)
		assertTrue(result.filter[email == "me2@salvatoreromeo.com"].size == 1)
		val result2 = db.find(TestUserPojo).where[id > 2L].resultList
		assertEquals(1, result2.size)
		val result3 = db.find(TestUserPojo).where[id > 1L].resultList
		assertEquals(2, result3.size)
		assertTrue(result3.filter[id == 1L].size == 0)
		val result4 = db.find(TestUserPojo).where[id > 2].resultList
		assertEquals(1, result4.size)

	}

	@Concurrent
	@Test
	def void testGreaterEqualsThan() {
		val a = 1
		val b = 2
		val c = 2
		assertTrue(b >= a)
		assertFalse(a >= b)
		val al = new Long(a)
		val bl = new Long(b)
		assertTrue(bl >= al)
		assertFalse(al >= bl)
		assertTrue(b >= c)
		assertTrue(c >= b)

		val result = db.find(TestUserPojo).where[id >= 0].resultList
		assertEquals(3, result.size)
		assertTrue(result.filter[email == "me@salvatoreromeo.com"].size == 1)
		assertTrue(result.filter[email == "me2@salvatoreromeo.com"].size == 1)
		val result2 = db.find(TestUserPojo).where[id >= 2L].resultList
		assertEquals(2, result2.size)
		assertTrue(result2.filter[id == 1L].size == 0)
		val result3 = db.find(TestUserPojo).where[id >= 1L].resultList
		assertEquals(3, result3.size)
		assertTrue(result3.filter[id == 1L].size == 1)
		val result4 = db.find(TestUserPojo).where[id >= 2].resultList
		assertEquals(2, result4.size)
	}

	@Concurrent
	@Test
	def void testLessThan() {
		val a = 1
		val b = 2
		assertTrue(a < b)
		assertFalse(b < a)
		val al = new Long(a)
		val bl = new Long(b)
		assertTrue(al < bl)
		assertFalse(bl < al)

		val result = db.find(TestUserPojo).where[id < 4].resultList
		assertEquals(3, result.size)
		assertTrue(result.filter[email == "me@salvatoreromeo.com"].size == 1)
		assertTrue(result.filter[email == "me2@salvatoreromeo.com"].size == 1)
		val result2 = db.find(TestUserPojo).where[id < 3L].resultList
		assertEquals(2, result2.size)
		assertTrue(result2.filter[id == 3L].size == 0)
		val result3 = db.find(TestUserPojo).where[id < 1L].resultList
		assertEquals(0, result3.size)
		val result4 = db.find(TestUserPojo).where[id < 3].resultList
		assertEquals(2, result4.size)
	}

	@Concurrent
	@Test
	def void testLessEqualsThan() {
		val a = 1
		val b = 2
		val c = 2
		assertTrue(a <= b)
		assertFalse(b <= a)
		val al = new Long(a)
		val bl = new Long(b)
		assertTrue(al <= bl)
		assertFalse(bl <= al)
		assertTrue(b <= c)
		assertTrue(c <= b)

		val result = db.find(TestUserPojo).where[id <= 4].resultList
		assertEquals(3, result.size)
		assertTrue(result.filter[email == "me@salvatoreromeo.com"].size == 1)
		assertTrue(result.filter[email == "me2@salvatoreromeo.com"].size == 1)
		val result2 = db.find(TestUserPojo).where[id <= 3L].resultList
		assertEquals(3, result2.size)
		assertTrue(result2.filter[id == 3L].size == 1)
		val result3 = db.find(TestUserPojo).where[id <= 1L].resultList
		assertEquals(1, result3.size)
		val result4 = db.find(TestUserPojo).where[id <= 3].resultList
		assertEquals(3, result4.size)

		val result5 = db.find(TestUserPojo).where[id <= 3L and name = "salvatore"].resultList
		assertEquals(1, result5.size)

		val result6 = db.find(TestUserPojo).where[id <= 1L or name = "salvatore"].resultList
		assertEquals(2, result6.size)
	}

	@Test
	def void testNestedObjects() {
		val np = new TestUserPojo => [id = 6L name = "nested"]
		val mp = new TestUserPojo2 => [id = 5L name2 = "fausta" pojo = np email2 = "f@x.co"]
		insertIntoDB(np, mp)

		val result = db.find(TestUserPojo2).where[pojo.name = "nested"].resultList
		assertEquals(1, result.size)
		assertTrue(result.filter[email2 == "f@x.co"].size == 1)

		db.transaction.begin
		db.remove(db.find(TestUserPojo2).where[name2 = "fausta"].singleResult)
		db.remove(db.find(TestUserPojo).where[name = "nested"].singleResult)
		db.transaction.commit
	}

	@Test
	def void testDateOperators() {

		val df = new SimpleDateFormat("yyyy-MM-dd")

		val tp = new TestUserPojo3 => [id = 101L d1 = df.parse("2014-06-10"); d2 = df.parse("2014-07-10")]
		val tp2 = new TestUserPojo3 => [id = 102L d1 = df.parse("2014-06-12"); d2 = df.parse("2014-07-04")]
		val tp3 = new TestUserPojo3 => [id = 103L d1 = df.parse("2014-06-16"); d2 = df.parse("2014-07-02")]

		insertIntoDB(tp, tp2, tp3)

		val result5 = db.find(TestUserPojo3).where[d1 >= df.parse("2014-05-01")].resultList
		assertEquals(3, result5.size)

		val result6 = db.find(TestUserPojo3).where[d1 >= df.parse("2014-05-01") and d2 <= df.parse("2014-07-03")].
			resultList
		assertEquals(1, result6.size)

	}
}

@Entity class TestUserPojo {

	@Id @Property Long id
	@Property String name
	@Property String email

}

@Entity class TestUserPojo2 {

	@Id @Property Long id
	@Property String name2
	@Property String email2
	@Property TestUserPojo pojo

}

@Entity class TestUserPojo3 {

	@Id @Property Long id
	@Temporal(TemporalType.TIMESTAMP)
	@Property Date d1
	@Temporal(TemporalType.TIMESTAMP)
	@Property Date d2

}

@Retention(RetentionPolicy.RUNTIME)
annotation Concurrent {
}
