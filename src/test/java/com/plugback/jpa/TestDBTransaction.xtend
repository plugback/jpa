package com.plugback.jpa

import org.junit.Test

import static org.junit.Assert.*

import static extension com.plugback.jpa.DBX.*

class TestDBTransaction extends DBTest {

	@Test
	def testSuccessTransaction() {
		val db = emf.createEntityManager
		db.transaction [
			db.merge(new TestUserPojo => [id = 201L])
		]

		val db2 = emf.createEntityManager
		val found = db2.find(TestUserPojo, 201L)
		assertTrue(found != null)
		val found2 = db2.find(TestUserPojo, 301L)
		assertFalse(found2 != null)

	}

	@Test
	def testErrorTransaction() {
		val db = emf.createEntityManager
		val checkSuccessNotCalled = new StringBuilder("")
		db.transaction [
			db.merge(new TestUserPojo => [id = 202L])
			throw new IllegalStateException
		].error[rollback].success[checkSuccessNotCalled.append("should not execute")]

		val db2 = emf.createEntityManager
		val found = db2.find(TestUserPojo, 202L)
		assertTrue(found == null)

		assertTrue(checkSuccessNotCalled.toString == "")
	}

	@Test
	def testTransactionCommitted() {
		val db = emf.createEntityManager
		val checkSuccessCalled = new StringBuilder("")
		val checkErrorNotCalled = new StringBuilder("")
		db.transaction [
			db.merge(new TestUserPojo => [id = 203L])
		].error[rollback checkErrorNotCalled.append("should not execute")].success[
			checkSuccessCalled.append("should execute")]

		val db2 = emf.createEntityManager
		val found = db2.find(TestUserPojo, 203L)
		assertTrue(found != null)

		assertTrue(checkSuccessCalled.toString == "should execute")
		assertTrue(checkErrorNotCalled.toString == "")
	}

}
