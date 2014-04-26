#Plugback JPA - Type safe JPA queries using Xtend
Plugback JPA is a module that allows you to extend the Java Persistence API to query your DB using an sql-like concise and typesafe syntax.

===

##What do you need
To use Plugback JPA you need:

<ul>
	<li>the Xtend library</li>
	<li>to add the import
		<code>import static extension com.plugback.jpa.DBExtension.*</code> to your class.
	You can find this class at https://github.com/plugback/jpa/blob/master/src/main/java/com/plugback/jpa/DBExtension.xtend
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

Ok, let's start with the features:

###FindAll

The <code>findAll</code> method allows you to get all objects of a particular class:<br>
```xtend
var = myEntities db.findAll (MyEntity)
```
where <code>myEntities</code> will be a collection having generic type <code>MyEntity</code>.


###Where

One of the most powerful methods of Plugback JPA is the <code>where</code> method. Let's see an example:
   
```xtend
db.find(MyEntity).where[email = "me@salvatoreromeo.com"].resultList
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

###OrderBy
Plugback JPA allows you to specify how to order the results from the database:
```xtend
db.find(MyEntity).where[name = "romeo"].orderBy[name].resultList
db.find(MyEntity).where[name = "romeo"].orderBy[name asc].resultList
db.find(MyEntity).where[name = "romeo"].orderBy[name desc].resultList
```
Immediately after using the method <code>where</code> you can take the results or order it using the above syntax.
In addition to the class fields, you can add the <code>asc</code> or <code>desc</code> keywords to specify the sort order.
            
###Pagination
The Plugback JPA module supports pagination of results:

```xtend
db.find(MyEntity).where[name = "romeo"].orderBy[name].setPageSize(10).getPage(1)
```

The <code>setPageSize</code> method can be used immediately after the <code>where</code> method or after the <code>orderBy</code> method. <code>setPageSize</code> allows you to specify the page size and <code>getPage</code> is used to specify which page is required.
            
##Important notes
The <code>where</code> method works only with POJOs, so you can not use classes in which the fields are named with the <code>_</code> prefix. Unfortunately the <code>@Data</code> and <code>@Property</code> built in Xtend active annotations do not create standard POJOs, and are not supported at this time. <br>

Alternatively you can use the <code>@Property</code> active annotation form the <b>Plugback Active</b> module.<br><br>

Moreover, the where method does not yet support nested query field, such as:

```xtend
...where [address.street = "my street"]  // not yet supported
```

Nested queries will be supported in the next version.
            
##Backed up by tests
Plugback JPA has been tested with 16 tests to validate the functionality. There is also a test to verify it's use in a server environment (concurrency) and a test to check the performance: about 10K tests executed each query with an average of 4 ms (2 ms variance). <br>

The tests can be run on your machine using the class <code>TestDBExtension</code>, which also shows several use cases of Plugback JPA.
            
