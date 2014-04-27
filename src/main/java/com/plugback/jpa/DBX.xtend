package com.plugback.jpa

import java.util.List
import javassist.util.proxy.MethodHandler
import javassist.util.proxy.ProxyFactory
import javax.persistence.EntityManager
import javax.persistence.TypedQuery

/**
 * 
 * To use this class add <br><br>
 *		<code>import static extension com.plugback.jpa.DBX.*</code> to your class.
 * <br><br>
 * Use the <code>find</code> method below to retrieve all 
 * stored entities of a specified class from your db:
 * <br>
 * <br>
 * <code>var myEntities = db.find(MyEntity).resultList</code>
 * <br><br>
 * The find method can be followed by <code>where</code> or <code>orderBy</code> to filter the results.
 * <br>
 * Pagination is supported using the syntax below:
 * <br><br>
 * <code>db.find(MyEntity).where[name = "romeo"].orderBy[name].resultList[page = 1 size = 2]</code>
 * @author Salvatore A. Romeo
 */
class DBX<T> {

	val private static queryBooleanOperator = new ThreadLocal<List<String>>
	val private static paramsAndValues = new ThreadLocal<List<Pair<String, Object>>>
	val private static sortOrder = new ThreadLocal<String>
	val private static sortOn = new ThreadLocal<String>
	val private static whereQuery = new ThreadLocal<String>
	val private static currentDBExecution = new ThreadLocal<DBX<?>>

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

	/**
	 * Use the <code>find</code> method below to retrieve all 
	 * stored entities of a specified class from your db:
	 * <br>
	 * <br>
	 * <code>var myEntities = db.find(MyEntity).resultList</code>
	 * <br><br>
	 * The find method can be followed by where or orderBy to filter the results.
	 * <br>
	 * Pagination is supported using the syntax below:
	 * <br><br>
	 * <code>db.find(MyEntity).where[name = "romeo"].orderBy[name].resultList[page = 1 size = 2]</code>
	 */
	def static <X> find(EntityManager db, Class<X> c) {
		val dbe = new DBX<X>(c, db)
		whereQuery.remove
		paramsAndValues.remove
		queryBooleanOperator.remove
		sortOn.remove
		sortOrder.remove
		currentDBExecution.remove
		currentDBExecution.set(dbe)
		val q = db.createQuery('''select x from «c.simpleName» x''', c)
		dbe.setQuery(q)
		return dbe
	}

	/**
	 * You can use the <code>findAll</code> method below to retrieve all 
	 * stored entities of a specified class from your db:
	 * <br>
	 * <br>
	 * <code>var myEntities = db.findAll(MyEntity)</code>
	 */
	def static <T> findAll(EntityManager db, Class<T> c) {
		return find(db, c).resultList as List<T>
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

	/**
	 * 
	 * The <code>orderBy</code> method allows you to specify how to order the results from 
	 * the database:
	 * <br><br>
	 * <code>db.find(MyEntity).where[name = "romeo"].orderBy[name].resultList</code><br>
	 * <code>db.find(MyEntity).where[name = "romeo"].orderBy[name asc].resultList</code><br>
	 * <code>db.find(MyEntity).where[name = "romeo"].orderBy[name desc].resultList</code><br>
	 * <br><br>
	 * Immediately after using the method <code>where</code> you can take the results or order it using the above syntax.
	 * <br><br>
	 * In addition to the class fields, you can add the <code>asc</code> or <code>desc</code> keywords to specify the sort order.
	 * <br>
	 */
	def static <T> orderBy(DBX<T> dbe, (T)=>void sortByClause) {
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

	/**
	 * 
	 * The <code>where</code> method allows to filter the results from the DB 
	 * in a type safe manner:
	 * <br>
	 * <br>
	 * <code>db.find(MyEntity).where[email = "email@somewhere.ops"].resultList</code>
	 * <br><br>
	 * The method above allows you to filter the entities in the DB based on a class fields, in a completely type-safe way.
	 * <br><br><code>and or</code> boolean operators are supported:
	 * <br>
	 * <code>db.find(MyEntity).where[id = 1L or id = 2L].resultList</code><br>
	 * 
	 * <code>db.find(MyEntity).where[id = 1L and name = "romeo"].resultList</code><br>
	 * <br>
	 * The <code>like</code> operator is supported too:<br>
	 * 
	 * <code>db.find(MyEntity).where[email like("%me%")].resultList</code><br>
	 * <code>db.find(MyEntity).where[email like("%me%") and name like("%ro%")].resultList</code><br>
	 * 
	 */
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

	/**
	 * Pagination is supported using the syntax below:
	 * <br><br>
	 * <code>db.find(MyEntity).where[name = "romeo"].resultList[page = 1 size = 50]</code>
	 * 
	 * <br>
	 * When using square brackets, default values for <code>page</code> and <code>size</code> are 1 and 10 respectively, 
	 * so you can specify only the page with size 10 or the size only for the first page.
	 *
	 */
	def resultList((Pagination)=>void p) {
		val pagination = new Pagination
		pagination.page = 1
		pagination.size = 10
		p.apply(pagination)
		val offset = (pagination.page - 1) * pagination.size
		return _query.setMaxResults(pagination.size).setFirstResult(offset).resultList
	}

	def static <T> setPageSize(DBX<T> dbe, int pageSize) {
		val pr = new PageResult(dbe._query.setMaxResults(pageSize))
		pr
	}

}

class Pagination {
	@Property int page
	@Property int size
}

@Data
class PageResult<T> {
	TypedQuery<T> q

	def getPage(int page) {
		val offset = (page - 1) * q.maxResults
		q.setFirstResult(offset).resultList
	}
}
