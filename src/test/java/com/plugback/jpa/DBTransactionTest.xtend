package com.plugback.jpa

import javax.persistence.EntityManager
import org.junit.Rule
import org.junit.Test

import static org.junit.Assert.*

import static extension com.plugback.jpa.DBX.*

class DBTransactionTest {

	@Rule
	public TestDB testDb = new TestDB(TestUserPojo)

	def EntityManager db() {
		return testDb.entityManager
	}

	@Test
	def testSuccessTransaction() {
		db.transaction [
			db.merge(new TestUserPojo => [id = 201L])
		]

		val db2 = testDb.entityManagerFactory.createEntityManager
		val found = db2.find(TestUserPojo, 201L)
		assertTrue(found != null)
		val found2 = db2.find(TestUserPojo, 301L)
		assertFalse(found2 != null)

	}

	@Test
	def testErrorTransaction() {
		val checkSuccessNotCalled = new StringBuilder("")
		db.transaction [
			db.merge(new TestUserPojo => [id = 202L])
			throw new IllegalStateException
		].error[rollback].success[checkSuccessNotCalled.append("should not execute")]

		val db2 = testDb.entityManagerFactory.createEntityManager
		val found = db2.find(TestUserPojo, 202L)
		assertTrue(found == null)

		assertTrue(checkSuccessNotCalled.toString == "")
	}

	@Test
	def testTransactionCommitted() {
		val checkSuccessCalled = new StringBuilder("")
		val checkErrorNotCalled = new StringBuilder("")
		db.transaction [
			db.merge(new TestUserPojo => [id = 203L])
		].error[rollback checkErrorNotCalled.append("should not execute")].success[
			checkSuccessCalled.append("should execute")]

		val db2 = testDb.entityManagerFactory.createEntityManager
		val found = db2.find(TestUserPojo, 203L)
		assertTrue(found != null)

		assertTrue(checkSuccessCalled.toString == "should execute")
		assertTrue(checkErrorNotCalled.toString == "")
	}

}
