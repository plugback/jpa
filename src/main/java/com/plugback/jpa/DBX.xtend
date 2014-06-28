package com.plugback.jpa

import com.plugback.jpa.clause.OrderBy
import com.plugback.jpa.clause.OrderByProcessor
import com.plugback.jpa.clause.Where
import com.plugback.jpa.clause.WhereProcessor
import com.plugback.jpa.proxy.Calls
import com.plugback.jpa.proxy.JavassistProxyCreator
import java.util.Date
import javax.persistence.EntityManager
import javax.persistence.EntityTransaction

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

	val private static currentDBExecution = new ThreadLocal<DBX<?>>

	val EntityManager em
	val Class<T> c
	val T whereProxy
	val T orderByProxy

	protected new(Class<T> c, EntityManager em) {
		this.em = em
		this.c = c
		val proxyFactory = new JavassistProxyCreator
		this.whereProxy = proxyFactory.createProxy(c, Where)
		this.orderByProxy = proxyFactory.createProxy(c, OrderBy)
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
		currentDBExecution.remove
		currentDBExecution.set(dbe)
		return dbe
	}

	def static <X> findAll(EntityManager db, Class<X> c) {
		return find(db, c).resultList
	}

	def static void and() {
		(currentDBExecution.get.whereProxy as Where).and
	}

	def static void or() {
		(currentDBExecution.get.whereProxy as Where).or
	}

	def static void like(String s) {
		(currentDBExecution.get.whereProxy as Where).like(s)
	}

	def static void asc() {
		(currentDBExecution.get.orderByProxy as OrderBy).asc
	}

	def static void desc() {
		(currentDBExecution.get.orderByProxy as OrderBy).desc
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
	def orderBy((T)=>void sortByClause) {
		sortByClause.apply(orderByProxy)
		return this
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
		whereClause.apply(whereProxy)
		return this
	}

	def singleResult() {
		return createQuery.singleResult
	}

	def resultList() {
		return createQuery.resultList
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
		return createQuery.setMaxResults(pagination.size).setFirstResult(offset).resultList
	}

	////////////////////////////////////////////////
	//          transaction section              //
	//////////////////////////////////////////////
	/**
	 * Encapsulate some logic within a transaction
	 */
	def static transaction(EntityManager db, (EntityTransaction)=>void t) {
		val transaction = db.transaction
		transaction.begin
		try {
			t.apply(transaction)
			transaction.commit
		} catch (Exception e) {
			return new TransactionSession(true, transaction)
		}
		return new TransactionSession(false, transaction)
	}

	/**
	 * what to do if the transaction goes bad
	 */
	def static error(TransactionSession s, (EntityTransaction)=>void onError) {
		if (s.error) {
			onError.apply(s.transaction)
		}
		return s
	}

	/**
	 * what to do if the transaction was committed successfully
	 */
	def static success(TransactionSession s, (EntityTransaction)=>void onSuccess) {
		if (!s.error) {
			onSuccess.apply(s.transaction)
		}
		return s
	}

	private def createQuery() {
		val query = new StringBuilder('''select x from «c.simpleName» x''')

		val wheresParameters = <Pair<String, Object>>newArrayList
		new WhereProcessor(wheresParameters).process(query, whereProxy as Calls)
		new OrderByProcessor().process(query, orderByProxy as Calls)

		val q = em.createQuery(query.toString, c)
		wheresParameters.forEach [ p, index |
			q.setParameter('''p«index»''', p.value)
		]
		currentDBExecution.remove
		return q
	}

	def static void store((Where)=>void operation) {
		try {
			if (currentDBExecution.get != null) {
				operation.apply((currentDBExecution.get.whereProxy as Where))
			}
		} catch (Exception e) { /*ignore*/
		}
	}

	////////////////////////////////////////////////
	//          operator >                       //
	//////////////////////////////////////////////
	def static <N extends Number & Comparable<?>> boolean operator_greaterThan(N left, N right) {
		store[greaterThan(right)]
		switch (left) {
			Double:
				switch (right) {
					Double: DoubleExtensions.operator_greaterThan(left as Double, right as Double)
					Float: DoubleExtensions.operator_greaterThan(left  as Double, right as Float)
					Long: DoubleExtensions.operator_greaterThan(left  as Double, right as Long)
					Integer: DoubleExtensions.operator_greaterThan(left  as Double, right as Integer)
					Short: DoubleExtensions.operator_greaterThan(left  as Double, right as Short)
					Byte: DoubleExtensions.operator_greaterThan(left  as Double, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Long:
				switch (right) {
					Double: LongExtensions.operator_greaterThan(left as Long, right as Double)
					Float: LongExtensions.operator_greaterThan(left  as Long, right as Float)
					Long: LongExtensions.operator_greaterThan(left  as Long, right as Long)
					Integer: LongExtensions.operator_greaterThan(left  as Long, right as Integer)
					Short: LongExtensions.operator_greaterThan(left  as Long, right as Short)
					Byte: LongExtensions.operator_greaterThan(left  as Long, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Integer:
				switch (right) {
					Double: IntegerExtensions.operator_greaterThan(left as Integer, right as Double)
					Float: IntegerExtensions.operator_greaterThan(left  as Integer, right as Float)
					Long: IntegerExtensions.operator_greaterThan(left  as Integer, right as Long)
					Integer: IntegerExtensions.operator_greaterThan(left  as Integer, right as Integer)
					Short: IntegerExtensions.operator_greaterThan(left  as Integer, right as Short)
					Byte: IntegerExtensions.operator_greaterThan(left  as Integer, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Float:
				switch (right) {
					Double: FloatExtensions.operator_greaterThan(left as Float, right as Double)
					Float: FloatExtensions.operator_greaterThan(left  as Float, right as Float)
					Long: FloatExtensions.operator_greaterThan(left  as Float, right as Long)
					Integer: FloatExtensions.operator_greaterThan(left  as Float, right as Integer)
					Short: FloatExtensions.operator_greaterThan(left  as Float, right as Short)
					Byte: FloatExtensions.operator_greaterThan(left  as Float, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			default:
				throw new IllegalArgumentException("Type not supported")
		}
	}

	def static operator_greaterThan(double left, double right) {
		store[greaterThan(right)]
		return DoubleExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(double left, float right) {
		store[greaterThan(right)]
		return DoubleExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(double left, long right) {
		store[greaterThan(right)]
		return DoubleExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(double left, int right) {
		store[greaterThan(right)]
		return DoubleExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(double left, short right) {
		store[greaterThan(right)]
		return DoubleExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(double left, byte right) {
		store[greaterThan(right)]
		return DoubleExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(float left, double right) {
		store[greaterThan(right)]
		return DoubleExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(float left, float right) {
		store[greaterThan(right)]
		return FloatExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(float left, long right) {
		store[greaterThan(right)]
		return FloatExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(float left, int right) {
		store[greaterThan(right)]
		return FloatExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(float left, short right) {
		store[greaterThan(right)]
		return FloatExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(float left, byte right) {
		store[greaterThan(right)]
		return FloatExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(long left, double right) {
		store[greaterThan(right)]
		return LongExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(long left, float right) {
		store[greaterThan(right)]
		return LongExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(long left, long right) {
		store[greaterThan(right)]
		return LongExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(long left, int right) {
		store[greaterThan(right)]
		return LongExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(long left, short right) {
		store[greaterThan(right)]
		return LongExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(long left, byte right) {
		store[greaterThan(right)]
		return LongExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(int left, double right) {
		store[greaterThan(right)]
		return IntegerExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(int left, float right) {
		store[greaterThan(right)]
		return IntegerExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(int left, long right) {
		store[greaterThan(right)]
		return IntegerExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(int left, int right) {
		store[greaterThan(right)]
		return IntegerExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(int left, short right) {
		store[greaterThan(right)]
		return IntegerExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(int left, byte right) {
		store[greaterThan(right)]
		return IntegerExtensions.operator_greaterThan(left, right)
	}

	def static operator_greaterThan(Date left, Date right) {
		store[greaterThan(right)]
		if (left == null)
			return 0
		return ComparableExtensions.operator_greaterThan(left, right)
	}

	////////////////////////////////////////////////
	//          operator >=                      //
	//////////////////////////////////////////////
	def static <N extends Number & Comparable<?>> boolean operator_greaterEqualsThan(N left, N right) {
		store[greaterEqualsThan(right)]
		switch (left) {
			Double:
				switch (right) {
					Double: DoubleExtensions.operator_greaterEqualsThan(left as Double, right as Double)
					Float: DoubleExtensions.operator_greaterEqualsThan(left  as Double, right as Float)
					Long: DoubleExtensions.operator_greaterEqualsThan(left  as Double, right as Long)
					Integer: DoubleExtensions.operator_greaterEqualsThan(left  as Double, right as Integer)
					Short: DoubleExtensions.operator_greaterEqualsThan(left  as Double, right as Short)
					Byte: DoubleExtensions.operator_greaterEqualsThan(left  as Double, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Long:
				switch (right) {
					Double: LongExtensions.operator_greaterEqualsThan(left as Long, right as Double)
					Float: LongExtensions.operator_greaterEqualsThan(left  as Long, right as Float)
					Long: LongExtensions.operator_greaterEqualsThan(left  as Long, right as Long)
					Integer: LongExtensions.operator_greaterEqualsThan(left  as Long, right as Integer)
					Short: LongExtensions.operator_greaterEqualsThan(left  as Long, right as Short)
					Byte: LongExtensions.operator_greaterEqualsThan(left  as Long, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Integer:
				switch (right) {
					Double: IntegerExtensions.operator_greaterEqualsThan(left as Integer, right as Double)
					Float: IntegerExtensions.operator_greaterEqualsThan(left  as Integer, right as Float)
					Long: IntegerExtensions.operator_greaterEqualsThan(left  as Integer, right as Long)
					Integer: IntegerExtensions.operator_greaterEqualsThan(left  as Integer, right as Integer)
					Short: IntegerExtensions.operator_greaterEqualsThan(left  as Integer, right as Short)
					Byte: IntegerExtensions.operator_greaterEqualsThan(left  as Integer, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Float:
				switch (right) {
					Double: FloatExtensions.operator_greaterEqualsThan(left as Float, right as Double)
					Float: FloatExtensions.operator_greaterEqualsThan(left  as Float, right as Float)
					Long: FloatExtensions.operator_greaterEqualsThan(left  as Float, right as Long)
					Integer: FloatExtensions.operator_greaterEqualsThan(left  as Float, right as Integer)
					Short: FloatExtensions.operator_greaterEqualsThan(left  as Float, right as Short)
					Byte: FloatExtensions.operator_greaterEqualsThan(left  as Float, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			default:
				throw new IllegalArgumentException("Type not supported")
		}
	}

	def static operator_greaterEqualsThan(double left, double right) {
		store[greaterEqualsThan(right)]
		return DoubleExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(double left, float right) {
		store[greaterEqualsThan(right)]
		return DoubleExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(double left, long right) {
		store[greaterEqualsThan(right)]
		return DoubleExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(double left, int right) {
		store[greaterEqualsThan(right)]
		return DoubleExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(double left, short right) {
		store[greaterEqualsThan(right)]
		return DoubleExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(double left, byte right) {
		store[greaterEqualsThan(right)]
		return DoubleExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(float left, double right) {
		store[greaterEqualsThan(right)]
		return DoubleExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(float left, float right) {
		store[greaterEqualsThan(right)]
		return FloatExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(float left, long right) {
		store[greaterEqualsThan(right)]
		return FloatExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(float left, int right) {
		store[greaterEqualsThan(right)]
		return FloatExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(float left, short right) {
		store[greaterEqualsThan(right)]
		return FloatExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(float left, byte right) {
		store[greaterEqualsThan(right)]
		return FloatExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(long left, double right) {
		store[greaterEqualsThan(right)]
		return LongExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(long left, float right) {
		store[greaterEqualsThan(right)]
		return LongExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(long left, long right) {
		store[greaterEqualsThan(right)]
		return LongExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(long left, int right) {
		store[greaterEqualsThan(right)]
		return LongExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(long left, short right) {
		store[greaterEqualsThan(right)]
		return LongExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(long left, byte right) {
		store[greaterEqualsThan(right)]
		return LongExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(int left, double right) {
		store[greaterEqualsThan(right)]
		return IntegerExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(int left, float right) {
		store[greaterEqualsThan(right)]
		return IntegerExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(int left, long right) {
		store[greaterEqualsThan(right)]
		return IntegerExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(int left, int right) {
		store[greaterEqualsThan(right)]
		return IntegerExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(int left, short right) {
		store[greaterEqualsThan(right)]
		return IntegerExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(int left, byte right) {
		store[greaterEqualsThan(right)]
		return IntegerExtensions.operator_greaterEqualsThan(left, right)
	}

	def static operator_greaterEqualsThan(Date left, Date right) {
		store[greaterEqualsThan(right)]
		if (left == null)
			return 0
		return ComparableExtensions.operator_greaterEqualsThan(left, right)
	}

	////////////////////////////////////////////////
	//          operator <                       //
	//////////////////////////////////////////////
	def static <N extends Number & Comparable<?>> boolean operator_lessThan(N left, N right) {
		store[lessThan(right)]
		switch (left) {
			Double:
				switch (right) {
					Double: DoubleExtensions.operator_lessThan(left as Double, right as Double)
					Float: DoubleExtensions.operator_lessThan(left  as Double, right as Float)
					Long: DoubleExtensions.operator_lessThan(left  as Double, right as Long)
					Integer: DoubleExtensions.operator_lessThan(left  as Double, right as Integer)
					Short: DoubleExtensions.operator_lessThan(left  as Double, right as Short)
					Byte: DoubleExtensions.operator_lessThan(left  as Double, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Long:
				switch (right) {
					Double: LongExtensions.operator_lessThan(left as Long, right as Double)
					Float: LongExtensions.operator_lessThan(left  as Long, right as Float)
					Long: LongExtensions.operator_lessThan(left  as Long, right as Long)
					Integer: LongExtensions.operator_lessThan(left  as Long, right as Integer)
					Short: LongExtensions.operator_lessThan(left  as Long, right as Short)
					Byte: LongExtensions.operator_lessThan(left  as Long, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Integer:
				switch (right) {
					Double: IntegerExtensions.operator_lessThan(left as Integer, right as Double)
					Float: IntegerExtensions.operator_lessThan(left  as Integer, right as Float)
					Long: IntegerExtensions.operator_lessThan(left  as Integer, right as Long)
					Integer: IntegerExtensions.operator_lessThan(left  as Integer, right as Integer)
					Short: IntegerExtensions.operator_lessThan(left  as Integer, right as Short)
					Byte: IntegerExtensions.operator_lessThan(left  as Integer, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Float:
				switch (right) {
					Double: FloatExtensions.operator_lessThan(left as Float, right as Double)
					Float: FloatExtensions.operator_lessThan(left  as Float, right as Float)
					Long: FloatExtensions.operator_lessThan(left  as Float, right as Long)
					Integer: FloatExtensions.operator_lessThan(left  as Float, right as Integer)
					Short: FloatExtensions.operator_lessThan(left  as Float, right as Short)
					Byte: FloatExtensions.operator_lessThan(left  as Float, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			default:
				throw new IllegalArgumentException("Type not supported")
		}
	}

	def static operator_lessThan(double left, double right) {
		store[lessThan(right)]
		return DoubleExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(double left, float right) {
		store[lessThan(right)]
		return DoubleExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(double left, long right) {
		store[lessThan(right)]
		return DoubleExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(double left, int right) {
		store[lessThan(right)]
		return DoubleExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(double left, short right) {
		store[lessThan(right)]
		return DoubleExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(double left, byte right) {
		store[lessThan(right)]
		return DoubleExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(float left, double right) {
		store[lessThan(right)]
		return DoubleExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(float left, float right) {
		store[lessThan(right)]
		return FloatExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(float left, long right) {
		store[lessThan(right)]
		return FloatExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(float left, int right) {
		store[lessThan(right)]
		return FloatExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(float left, short right) {
		store[lessThan(right)]
		return FloatExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(float left, byte right) {
		store[lessThan(right)]
		return FloatExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(long left, double right) {
		store[lessThan(right)]
		return LongExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(long left, float right) {
		store[lessThan(right)]
		return LongExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(long left, long right) {
		store[lessThan(right)]
		return LongExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(long left, int right) {
		store[lessThan(right)]
		return LongExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(long left, short right) {
		store[lessThan(right)]
		return LongExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(long left, byte right) {
		store[lessThan(right)]
		return LongExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(int left, double right) {
		store[lessThan(right)]
		return IntegerExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(int left, float right) {
		store[lessThan(right)]
		return IntegerExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(int left, long right) {
		store[lessThan(right)]
		return IntegerExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(int left, int right) {
		store[lessThan(right)]
		return IntegerExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(int left, short right) {
		store[lessThan(right)]
		return IntegerExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(int left, byte right) {
		store[lessThan(right)]
		return IntegerExtensions.operator_lessThan(left, right)
	}

	def static operator_lessThan(Date left, Date right) {
		store[lessThan(right)]
		if (left == null)
			return 0
		return ComparableExtensions.operator_lessThan(left, right)
	}

	////////////////////////////////////////////////
	//          operator <=                      //
	//////////////////////////////////////////////
	def static <N extends Number & Comparable<?>> boolean operator_lessEqualsThan(N left, N right) {
		store[lessEqualsThan(left)]
		switch (left) {
			Double:
				switch (right) {
					Double: DoubleExtensions.operator_lessEqualsThan(left as Double, right as Double)
					Float: DoubleExtensions.operator_lessEqualsThan(left  as Double, right as Float)
					Long: DoubleExtensions.operator_lessEqualsThan(left  as Double, right as Long)
					Integer: DoubleExtensions.operator_lessEqualsThan(left  as Double, right as Integer)
					Short: DoubleExtensions.operator_lessEqualsThan(left  as Double, right as Short)
					Byte: DoubleExtensions.operator_lessEqualsThan(left  as Double, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Long:
				switch (right) {
					Double: LongExtensions.operator_lessEqualsThan(left as Long, right as Double)
					Float: LongExtensions.operator_lessEqualsThan(left  as Long, right as Float)
					Long: LongExtensions.operator_lessEqualsThan(left  as Long, right as Long)
					Integer: LongExtensions.operator_lessEqualsThan(left  as Long, right as Integer)
					Short: LongExtensions.operator_lessEqualsThan(left  as Long, right as Short)
					Byte: LongExtensions.operator_lessEqualsThan(left  as Long, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Integer:
				switch (right) {
					Double: IntegerExtensions.operator_lessEqualsThan(left as Integer, right as Double)
					Float: IntegerExtensions.operator_lessEqualsThan(left  as Integer, right as Float)
					Long: IntegerExtensions.operator_lessEqualsThan(left  as Integer, right as Long)
					Integer: IntegerExtensions.operator_lessEqualsThan(left  as Integer, right as Integer)
					Short: IntegerExtensions.operator_lessEqualsThan(left  as Integer, right as Short)
					Byte: IntegerExtensions.operator_lessEqualsThan(left  as Integer, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			Float:
				switch (right) {
					Double: FloatExtensions.operator_lessEqualsThan(left as Float, right as Double)
					Float: FloatExtensions.operator_lessEqualsThan(left  as Float, right as Float)
					Long: FloatExtensions.operator_lessEqualsThan(left  as Float, right as Long)
					Integer: FloatExtensions.operator_lessEqualsThan(left  as Float, right as Integer)
					Short: FloatExtensions.operator_lessEqualsThan(left  as Float, right as Short)
					Byte: FloatExtensions.operator_lessEqualsThan(left  as Float, right as Byte)
					default: throw new IllegalArgumentException("Type not supported")
				}
			default:
				throw new IllegalArgumentException("Type not supported")
		}
	}

	def static operator_lessEqualsThan(double left, double right) {
		store[lessEqualsThan(right)]
		return DoubleExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(double left, float right) {
		store[lessEqualsThan(right)]
		return DoubleExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(double left, long right) {
		store[lessEqualsThan(right)]
		return DoubleExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(double left, int right) {
		store[lessEqualsThan(right)]
		return DoubleExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(double left, short right) {
		store[lessEqualsThan(right)]
		return DoubleExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(double left, byte right) {
		store[lessEqualsThan(right)]
		return DoubleExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(float left, double right) {
		store[lessEqualsThan(right)]
		return DoubleExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(float left, float right) {
		store[lessEqualsThan(right)]
		return FloatExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(float left, long right) {
		store[lessEqualsThan(right)]
		return FloatExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(float left, int right) {
		store[lessEqualsThan(right)]
		return FloatExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(float left, short right) {
		store[lessEqualsThan(right)]
		return FloatExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(float left, byte right) {
		store[lessEqualsThan(right)]
		return FloatExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(long left, double right) {
		store[lessEqualsThan(right)]
		return LongExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(long left, float right) {
		store[lessEqualsThan(right)]
		return LongExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(long left, long right) {
		store[lessEqualsThan(right)]
		return LongExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(long left, int right) {
		store[lessEqualsThan(right)]
		return LongExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(long left, short right) {
		store[lessEqualsThan(right)]
		return LongExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(long left, byte right) {
		store[lessEqualsThan(right)]
		return LongExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(int left, double right) {
		store[lessEqualsThan(right)]
		return IntegerExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(int left, float right) {
		store[lessEqualsThan(right)]
		return IntegerExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(int left, long right) {
		store[lessEqualsThan(right)]
		return IntegerExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(int left, int right) {
		store[lessEqualsThan(right)]
		return IntegerExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(int left, short right) {
		store[lessEqualsThan(right)]
		return IntegerExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(int left, byte right) {
		store[lessEqualsThan(right)]
		return IntegerExtensions.operator_lessEqualsThan(left, right)
	}

	def static operator_lessEqualsThan(Date left, Date right) {
		store[lessEqualsThan(right)]
		if (left == null)
			return 0
		return ComparableExtensions.operator_lessEqualsThan(left, right)
	}

}

@Data class TransactionSession {
	Boolean error
	EntityTransaction transaction
}

class Pagination {
	@Property int page
	@Property int size
}
