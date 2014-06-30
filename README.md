#Plugback JPA - Type safe JPA queries using Xtend
Plugback JPA is a module that allows you to extend the Java Persistence API to query your DB using an sql-like concise and typesafe syntax.

===

##What do you need
To use Plugback JPA you need to add this maven dependency:

```xml
<dependency>
    <groupId>com.plugback</groupId>
    <artifactId>jpa</artifactId>
    <version>2.0.0</version>
</dependency>
```

You also need:
<ul>
	<li>the Xtend library (of course :-) )</li>
	<li>to add the import
		<code>import static extension com.plugback.jpa.DBX.*</code> to your class.
	</li>
	<li>a JPA <code>EntityManager</code></li>
</ul>


##Main features
Below we discuss the main features of Plugback JPA. It is assumed you have a <code>db</code> object
of type <code>EntityManager</code> and that you are persisting the JPA class <code>MyEntity</code>:

```xtend
@Entity
class MyEntity {

	@Id
	@Property Long id
	@Property String name
	@Property String email

}
```   

Note that <code>@Property</code> refers to the Plugback Active <code>@Property</code> annotation, and not the Xtend built-in <code>@Property</code>. See the <b>Important Notes</b> section below for more details. 

Plugback Active is included automatically when importing the libreary using maven.

Ok, let's start with the features:

###FindAll

You can use the syntax below to retrieve all stored entities of a specified class from your db:

```xtend
var myEntities = db.find(MyEntity).resultList
```

The <code>findAll</code> method is a shortcut method to get all objects of a particular class:<br>
```xtend
var myEntities = db.findAll(MyEntity)
```
where <code>myEntities</code> will be a collection having generic type <code>MyEntity</code>.


###Where

One of the most powerful methods of Plugback JPA is the <code>where</code> method. Let's see an example:
   
```xtend
db.find(MyEntity).where[email = "email@somewhere.ops"].resultList
```
    

The method above allows you to filter the entities in the DB based on a class fields, in a completely type-safe way.
<code>and or</code> boolean operators are supported:

```xtend
db.find(MyEntity).where[id = 1L or id = 2L].resultList
db.find(MyEntity).where[id = 1L and name = "romeo"].resultList
```

The <code>like</code> operator is supported too:
```xtend
db.find(MyEntity).where[email like("%me%")].resultList
db.find(MyEntity).where[email like("%me%") and name like("%ro%")].resultList
```

Since version 2.0.0 you can use operators other than "=" into where clauses. For example take a look at the code below:

```xtend
db.find(MyEntity).where[id >= 1L].resultList
db.find(MyEntity).where[id >= 1 and id < 5].resultList
```

And since version 2.0.0 nested object are supported too, so you can write something like this:

```xtend
...where [address.street = "my street"] 
```

###OrderBy
Plugback JPA allows you to specify how to order the results from the database:
```xtend
db.find(MyEntity).where[name = "romeo"].orderBy[name].resultList
db.find(MyEntity).where[name = "romeo"].orderBy[name asc].resultList
db.find(MyEntity).where[name = "romeo"].orderBy[name desc].resultList
```
Immediately after using the method <code>where</code> you can take the results or order it using the above syntax.
In addition to the class fields, you can add the <code>asc</code> or <code>desc</code> keywords to specify the sort order.

Nested objects are supported in the orderBy clause too.
            
###Pagination
The Plugback JPA module supports pagination of results. Simply specify the page you want and its size after the resultList command:

```xtend
db.find(MyEntity).where[name = "romeo"].orderBy[name].resultList[page = 1 size = 50]
```

When using square brackets, default values for <code>page</code> and <code>size</code> are 1 and 10 respectively, so you can specify only the <code>page</code> with <code>size</code> 10 or the size only for the first page.

Alternatively, the <code>setPageSize</code> method can be used immediately after the <code>where</code> method or after the <code>orderBy</code> method. <code>setPageSize</code> allows you to specify the page size and <code>getPage</code> is used to specify which page is required.

##Transactions
If you were used to @Transactional annotation in Guice or something similar in Spring, forget about it. Plugback JPA gives you a clear and coincise syntax for managing transactions. 

Let's take a look:

```xtend
db.transaction [
			db.merge(new TestUserPojo => [id = 201L])
		]
```

Everything inside square brackets will be part of the transaction.

There is the possibility to fine control what should happen in case of errors, like rolling back:

```xtend
db.transaction [
			db.merge(new TestUserPojo => [id = 202L])
			throw new IllegalStateException
		].error[rollback]
```

But you can add any other instruction inside the error square brackets.

You can also define some code to be executed only if the transaction was successful:

```xtend
db.transaction [
			db.merge(new TestUserPojo => [id = 202L])
			throw new IllegalStateException
		].success[println("everything is fine")].error[rollback println("ops")]

```
            
##Important notes
The <code>where</code> method works only with POJOs, so you can not use classes in which the fields are named with the <code>_</code> prefix. Unfortunately the <code>@Data</code> and <code>@Property</code> built in Xtend active annotations do not create standard POJOs, and are not supported at this time. <br>

Alternatively you can use the <code>@Property</code> active annotation form the <b>Plugback Active</b> module.<br><br>

            
##Backed up by tests
Plugback JPA has been heavily tested to validate the functionality. There is also a test to check the performance: about 10K tests executed each query with an average of 4 ms (2 ms variance). <br>

The tests can be run on your machine using the classes <code>TestDBExtension</code> and <code>TestDBTransaction</code>, which also show several use cases of Plugback JPA.
            
