package com.plugback.jpa.clause

interface Where {

	def void and();

	def void or();

	def void like(String like);

	def void greaterThan(Object x);

	def void lessThan(Object x);

	def void greaterEqualsThan(Object x);

	def void lessEqualsThan(Object x);

	def void notEquals(Object x);
}
