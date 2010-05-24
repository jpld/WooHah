[WooHah](http://github.com/jpld/WooHah/)
=============
a ruby script to help one stay current with the Mac OS X builds of the [Clang Static Analyzer](http://clang-analyzer.llvm.org/). it will fetch the latest analyzer build and install into a user-specified local directory, allowing one to have the latest analysis but not disturbing the system version of the Clang compiler.

to use, one need only modify two variables in the source file, update ``CHECKER_INSTALL_LOCATION`` to point to the directory the checker builds are installed into and ``CHECKER_SYMLINK_LOCATION`` to point to a persistant active build location, it shoud likely be a subdirectory of ``CHECKER_INSTALL_LOCATION``.