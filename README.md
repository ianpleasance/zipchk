# zipchk
A script to recursively find and verify archives of a variety of types, including; zip, rar, bzip, lha, etc.

This is a fairly crude script that gradually grew to support more archive types, it runs on Linux and Cygwin-enabled Windows boxes.

It could use some serious improvement which I will do at some point ...

Recurse through a directory tree validating all archive files for archive consistency.
For archives with par sets containing archive files, just verify the par set (unless -d is specified).
By default, verbosely list whats being done, or if -q is specified then just display errors.

For more usage instructions, a list of linux/cygwin packages to install, and a to-do list - see the script header.



