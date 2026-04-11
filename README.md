# Rails — Project Setup & Overview

### About

Building a personal bookmarks manager — you save links, organise them with tags, and can share collections publicly.

---

### Goals:

**Phase 1 — Foundation** (understand how Rails works)

1. Project structure & MVC mental model
2. Routing — how URLs map to code
3. Migrations — creating your database tables
4. Models & ActiveRecord — talking to the database
5. Controllers & Views — making pages work

**Phase 2 — Real Features** (build the actual app)

6. Forms & params — creating/editing bookmarks
7. Validations — making sure data is correct
8. Associations — connecting bookmarks to tags
9. Partials & layouts — reusable view pieces

**Phase 3 — Production Thinking** (what I care about)

10. Authentication & authorisation
11. Callbacks — auto-fetching page titles
12. Scopes & queries — filtering/searching
13. Background jobs
14. Testing with RSpec

Each concept builds on the last.

---

### Create the Project

If you already have an empty project folder:

```bash
cd bookmarks_app
rails new . --database=sqlite3
```

The `--database=sqlite3` flag tells Rails to use SQLite as the database. SQLite stores your entire database in a single file — no database server to install, no passwords to configure. It's perfect for learning.

**NOTE** The Rails code you write (models, queries, migrations) is identical regardless of which database you use. This is because ActiveRecord — Rails' database layer — abstracts the database behind a common interface. So everything you learn here transfers directly to PostgreSQL in production.

If Rails asks whether to overwrite any existing files (like a README), say `Y` to accept.

### Start the Server

```bash
bin/rails server
```

**NOTE** `bin/rails server` can be shortened to `bin/rails s`. You'll see both forms around. They do the same thing.
