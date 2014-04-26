package com.plugback.jpa

import java.util.List
import javassist.util.proxy.MethodHandler
import javassist.util.proxy.ProxyFactory
import javax.persistence.EntityManager
import javax.persistence.TypedQuery

class DBExtension<T> {

	val private static queryBooleanOperator = new ThreadLocal<List<String>>
	val private static paramsAndValues = new ThreadLocal<List<Pair<String, Object>>>
	val private static sortOrder = new ThreadLocal<String>
	val private static sortOn = new ThreadLocal<String>
	val private static whereQuery = new ThreadLocal<String>
	val private static currentDBExecution = new ThreadLocal<DBExtension<?>>

	val EntityManager em
	val Class<T> c
	TypedQuery<T> _query

	def static query() {
		return currentDBExecution.get._query
	}

	protected new(Class<T> c, EntityManager em) {
		this.em = em
		this.c = c
	}

	def static <X> find(EntityManager db, Class<X> c) {
		val dbe = new DBExtension<X>(c, db)
		whereQuery.remove
		paramsAndValues.remove
		queryBooleanOperator.remove
		sortOn.remove
		sortOrder.remove
		currentDBExecution.remove
		currentDBExecution.set(dbe)
		return dbe
	}

	def static <T> findAll(EntityManager db, Class<T> c) {
		return db.createQuery('''select x from «c.simpleName» x''', c).resultList as List<T>
	}

	def static void and() {
		queryBooleanOperator.get.add("and")
	}

	def static void or() {
		queryBooleanOperator.get.add("or")
	}

	def static void asc() {
		sortOrder.set("ASC")
	}

	def static void desc() {
		sortOrder.set("DESC")
	}

	def static void like(String s) {
		val last = paramsAndValues.get.last
		paramsAndValues.get.remove(paramsAndValues.get.size - 1)
		val newLast = last.key -> '''LIKE «s»'''.toString as Object
		paramsAndValues.get.add(newLast)
	}

	def static <T> orderBy(DBExtension<T> dbe, (T)=>void sortByClause) {
		val MethodHandler operation = [ selfObject, thisMethod, proceed, args |
			val property = thisMethod.name.substring(3).toFirstLower
			sortOn.set(property)
			return null
		]
		val factory = new ProxyFactory
		factory.setSuperclass(currentDBExecution.get.c)
		val x = factory.create(<Class<?>>newArrayOfSize(0), newArrayOfSize(0), operation) as T
		sortByClause.apply(x)
		val query = '''«whereQuery.get» ORDER BY x.«sortOn.get»«IF sortOrder.get != null» «sortOrder.get»«ENDIF»'''
		val tq = dbe.em.createQuery(query, dbe.c)
		paramsAndValues.get.forEach [ p, index |
			if (p.value instanceof String && (p.value as String).startsWith("LIKE "))
				tq.setParameter('''p«index»''', (p.value as String).replace("LIKE ", ""))
			else
				tq.setParameter('''p«index»''', p.value)
		]
		dbe.setQuery(tq)
		dbe
	}

	def where((T)=>void whereClause) {

		queryBooleanOperator.set(newArrayList)

		val setParamsAndValues = <Pair<String, Object>>newArrayList()
		paramsAndValues.set(setParamsAndValues)

		val MethodHandler operation = [ selfObject, thisMethod, proceed, args |
			val property = thisMethod.name.substring(3).toFirstLower
			if (thisMethod.name.startsWith("set")) {
				setParamsAndValues.add(property -> args.get(0))
			} else if (thisMethod.name.startsWith("get")) {
				setParamsAndValues.add(property -> null)
			}
			return null
		]

		val factory = new ProxyFactory
		factory.setSuperclass(c)
		val x = factory.create(<Class<?>>newArrayOfSize(0), newArrayOfSize(0), operation) as T
		whereClause.apply(x)

		val wheres = <String>newArrayList()
		setParamsAndValues.forEach [ p, index |
			if (p.value instanceof String && (p.value as String).startsWith("LIKE "))
				wheres.add('''x.«p.key» LIKE :p«index»''')
			else
				wheres.add('''x.«p.key» = :p«index»''')
		]

		val completeWhereCluase = new StringBuilder
		completeWhereCluase.append(wheres.head)
		if (wheres.size > 0) {
			val ops = queryBooleanOperator.get
			ops.forEach[op, index|completeWhereCluase.append(''' «op» «wheres.get(index + 1)»''')]

		}

		val query = '''select x from «c.simpleName» x where «completeWhereCluase.toString»'''
		val tq = em.createQuery(query, c)
		setParamsAndValues.forEach [ p, index |
			if (p.value instanceof String && (p.value as String).startsWith("LIKE "))
				tq.setParameter('''p«index»''', (p.value as String).replace("LIKE ", ""))
			else
				tq.setParameter('''p«index»''', p.value)
		]

		whereQuery.set(query)
		setQuery(tq)
		return this
	}

	def void setQuery(TypedQuery<T> query) {
		this._query = query
	}

	def singleResult() {
		return _query.singleResult
	}

	def resultList() {
		return _query.resultList
	}

	def static <T> setPageSize(DBExtension<T> dbe, int pageSize) {
		val pr = new PageResult(dbe._query.setMaxResults(pageSize))
		pr
	}

}

@Data
class PageResult<T> {
	TypedQuery<T> q

	def getPage(int page) {
		val offset = (page - 1) * q.maxResults
		q.setFirstResult(offset).resultList
	}
}
