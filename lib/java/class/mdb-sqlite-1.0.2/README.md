Modified version and recompiled

 * Modify mdb-sqlite jar package to amend the following issue :
   	Unable to load native library: java.lang.NullPointerException
   Solved it by applying this fix https://code.google.com/p/mdb-sqlite/issues/detail?id=11
 * modification of the java mdb-sqlite package to handle TIMESTAMP format
   which fixed many problems.
 * removed deprecieted sqlitejdbc library and replace with newer version