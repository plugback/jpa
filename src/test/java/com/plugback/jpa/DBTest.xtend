package com.plugback.jpa

import java.io.File
import javax.persistence.EntityManager
import javax.persistence.EntityManagerFactory
import javax.persistence.Persistence
import org.junit.AfterClass
import org.junit.BeforeClass

class DBTest {

	static EntityManagerFactory emf

	@BeforeClass
	def static void initDB() {
		val persistencePath = path("META-INF/persistence.xml.test")
		new File(persistencePath).renameTo(new File(persistencePath.substring(0, persistencePath.length - 5)))
		emf = Persistence.createEntityManagerFactory("in-memory")

	}

	static def emf() {
		return emf
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

}
