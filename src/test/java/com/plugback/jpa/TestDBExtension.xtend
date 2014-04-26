package com.plugback.jpa

import com.plugback.active.properties.Property
import java.io.File
import java.lang.annotation.Retention
import java.lang.annotation.RetentionPolicy
import java.util.concurrent.Executors
import javax.persistence.Entity
import javax.persistence.EntityManager
import javax.persistence.EntityManagerFactory
import javax.persistence.Id
import javax.persistence.Persistence
import org.databene.contiperf.PerfTest
import org.databene.contiperf.Required
import org.databene.contiperf.junit.ContiPerfRule
import org.eclipse.persistence.jpa.JpaQuery
import org.junit.After
import org.junit.AfterClass
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test

import static org.junit.Assert.*

import static extension com.plugback.jpa.DBExtension.*

class TestDBExtension {

	static EntityManagerFactory emf

	@BeforeClass
	def static void initDB() {
		val persistencePath = path("META-INF/persistence.xml.test")
		new File(persistencePath).renameTo(new File(persistencePath.substring(0, persistencePath.length - 5)))
		emf = Persistence.createEntityManagerFactory("in-memory")
		new TestDBExtension().insertSomeData
	}

	val EntityManager _db

	new() {
		_db = emf.createEntityManager
	}

	def EntityManager db() {
		return _db
	}

	def static path(String path) {
		val p = TestDBExtension.classLoader.getResource(path)
		p.file
	}

	@AfterClass
	def static void restorePersistence() {
		val persistencePath = path("META-INF/persistence.xml")
		new File(persistencePath).renameTo(new File(persistencePath + ".test"))
	}

	@Before
	def void inserData() {
	}

	@After
	def void clearDB() {
		//clear(TestUserPojo)
	}

	@Test
	def void findAll() {
		val result = db.findAll(TestUserPojo)
		assertEquals(3, result.size)
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
						println(DBExtension.query.unwrap(JpaQuery).getDatabaseQuery().getSQLString())
						throw e
					}
					println('''just executed test «p»: «test.name»''')
				])
		}
		es.shutdown()
	}

	@Rule public val rule = new ContiPerfRule

	@PerfTest(invocations=10000, threads=4)
	@Required(average=10)
	@Test
	def void performanceTest() {
		val tests = TestDBExtension.methods.filter[isAnnotationPresent(Test) && isAnnotationPresent(Concurrent)]
		val rn = Math.round(((Math.random() * (tests.size - 1)))).intValue
		val test = tests.get(rn)
		test.invoke(new TestDBExtension)
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

	def insertIntoDB(Object o) {
		val tdb = emf.createEntityManager
		tdb.transaction.begin
		tdb.merge(o)
		tdb.transaction.commit
	}

	def clear(Class<?>... cs) {
		val tdb = emf.createEntityManager
		tdb.transaction.begin
		cs.forEach[tdb.findAll(it).forEach[tdb.remove(it)]]
		tdb.transaction.commit
	}

}

@Entity
class TestUserPojo {

	@Id
	@Property Long id
	@Property String name
	@Property String email

}

@Retention(RetentionPolicy.RUNTIME)
annotation Concurrent {
}
