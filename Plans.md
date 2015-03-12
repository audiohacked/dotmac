_what's being worked on now, future plans..._

# Introduction #

This document details what's currently being worked on, and (possible) future plans.


# Work in progress #

### The _stable_ release ###

Currently there's (still) some issues with iDisk sync on Leopard in a mixed environment (offline _and_ online iDisk).
The .htdigest/BerkeleyDB combination cannot suffice our needs here; we'll move to some more sophisticated (database) backend.

### Work in progress (in random order) ###

  * Build a pluggable auth system, supporting various (dbi) backends. Sqlite will be the default install option, mySQL optional. It should be fairly simple to add other (dbi) backends.
  * Public folder access.
  * More sophisticated idiskAdmin.

# Future plans #

### Future plans (in random order) ###

  * Full iLife support.
  * dotmac web interface.