package com.plugback.jpa

import javax.persistence.EntityManager
import javax.persistence.EntityManagerFactory
import javax.persistence.Persistence
import org.junit.rules.ExternalResource

import static extension com.plugback.jpa.DBX.*

class TestDB extends ExternalResource {

	val EntityManagerFactory _entityManagerFactory

	EntityManager _entityManager

	val Class<?>[] entitiesForCleanup

	new(Class<?>... entitiesForCleanup) {
		this.entitiesForCleanup = entitiesForCleanup

		_entityManagerFactory = Persistence.createEntityManagerFactory(
			"in-memory",
			newHashMap(
				"eclipselink.persistencexml" -> "META-INF/persistence-test.xml"
			)
		)
		_entityManager = _entityManagerFactory.createEntityManager
	}

	def EntityManager getEntityManager() {
		return _entityManager
	}

	def EntityManagerFactory entityManagerFactory() {
		return _entityManagerFactory
	}

	def insertIntoDB(Object... o) {
		_entityManager.transaction [
			o.forEach[_entityManager.merge(it)]
		]
	}

	def clear() {
		_entityManager.transaction [
			entitiesForCleanup.forEach[_entityManager.find(it).resultList.forEach[_entityManager.remove(it)]]
		]
	}

	override protected before() throws Throwable {
		clear()
	}

	override protected after() {
		clear()
		_entityManager.close
	}

}
