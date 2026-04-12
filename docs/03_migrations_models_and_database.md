# Rails — Migrations, Models & the Database

### Lesson Objectives

_After this lesson, you will be able to:_

- Generate a migration to create a database table
- Understand the difference between a migration file and running a migration
- Read `schema.rb` and know what it represents
- Create a model and connect it to the database
- Use the Rails console to create and query records
- Connect the model to the controller so the API returns real data

---

### What is a Migration?

A migration is a set of instructions for changing your database structure. Adding a table, removing a column, renaming a field — all migrations.

The key idea: **migrations change the structure, not the data.**

- **Migration** = building a bookshelf (how many shelves, how wide)
- **Creating records** = putting books on the shelf

```ruby
# Migration = building the shelf
create_table :bookmarks do |t|
  t.string :title
  t.string :url
end

# Creating a record = putting a book on the shelf
Bookmark.create(title: "GitHub", url: "https://github.com")
```

You only need a new migration when you change the shape of the table — add a column, remove a column, rename something. Adding, editing, or deleting records is just data and doesn't require a migration.

---

### Generating a Migration

```bash
bin/rails generate migration CreateBookmarks title:string url:string
```

This does one thing: creates a file in `db/migrate/`. It does **not** touch the database.

#### How Rails reads the name

Rails parses the migration name to decide what boilerplate to generate:

| Migration name             | What Rails generates               |
| -------------------------- | ---------------------------------- |
| `CreateBookmarks`          | `create_table :bookmarks`          |
| `CreateUsers`              | `create_table :users`              |
| `AddEmailToUsers`          | `add_column :users, :email`        |
| `RemoveTitleFromBookmarks` | `remove_column :bookmarks, :title` |

`Create` + `Bookmarks` → Rails knows to generate a `create_table :bookmarks` migration.

If you use a name Rails doesn't recognize a pattern in (like `DoSomethingWeird`), it still creates the file, but the `change` method will be empty. You'd write the body yourself.

---

### The Migration File

```ruby
class CreateBookmarks < ActiveRecord::Migration[8.1]
  def change
    create_table :bookmarks do |t|
      t.string :title
      t.string :url

      t.timestamps
    end
  end
end
```

Line by line:

- `class CreateBookmarks < ActiveRecord::Migration[8.1]` → a migration class. `[8.1]` is the Rails version, so Rails knows which migration features are available.
- `def change` → the method Rails calls when you run the migration. Rails can also automatically **reverse** this method if you need to undo the migration.
- `create_table :bookmarks` → creates a table called `bookmarks` in the database.
- `t.string :title` → adds a `title` column with type `string`.
- `t.string :url` → adds a `url` column with type `string`.
- `t.timestamps` → adds `created_at` and `updated_at` columns. Rails auto-fills these whenever a record is created or updated. You almost always want these.

---

### Two Steps: Generate, Then Migrate

This is important. Creating a migration is two separate steps:

**Step 1 — Generate** → writes the instructions (the migration file)

```bash
bin/rails generate migration CreateBookmarks title:string url:string
```

**Step 2 — Migrate** → executes those instructions against the database

```bash
bin/rails db:migrate
```

Why two steps? It gives you a chance to **review and edit** the migration before applying it. Sometimes the generator gets you 80% there and you tweak the rest by hand.

---

### schema.rb — The Current Snapshot

After running `bin/rails db:migrate`, open `db/schema.rb`:

```ruby
ActiveRecord::Schema[8.1].define(version: 2026_04_12_120943) do
  create_table "bookmarks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
  end
end
```

Think of it this way:

- `db/migrate/` → the **history** of every change you've made (like Git commits)
- `db/schema.rb` → the **current snapshot** of your database (like the current state of your code)

`version: 2026_04_12_120943` is the timestamp of the last migration that was run. This is how Rails knows which migrations have already been applied. If you run `bin/rails db:migrate` again, nothing happens — it's already up to date.

**NOTE** Never edit `schema.rb` by hand. It's auto-generated. Always create a new migration to change the database.

---

### The Model

The migration created the table. Now Rails needs a model to talk to it.

```bash
touch app/models/bookmark.rb
```

```ruby
class Bookmark < ApplicationRecord
end
```

Two lines. That's it. Here's what's happening:

- `Bookmark` (singular, PascalCase) → the class name
- `< ApplicationRecord` → inherits from Rails' base model, which gives you all the database methods (`.all`, `.find`, `.create`, `.update`, `.destroy`, etc.)
- Rails automatically maps `Bookmark` → the `bookmarks` table

#### The Naming Convention

This is one of Rails' most important conventions:

| Thing     | Name                     | Why                             |
| --------- | ------------------------ | ------------------------------- |
| **Table** | `bookmarks` (plural)     | A table holds _many_ records    |
| **Model** | `Bookmark` (singular)    | A model represents _one_ record |
| **File**  | `bookmark.rb` (singular) | One file, one class             |

When you write `Bookmark.all`, you're saying "hey Bookmark class, go to the `bookmarks` table and get all records." Each record that comes back is a single `Bookmark`.

---

### The Rails Console

The console lets you interact with your app directly using Ruby. It's the fastest way to test things:

```bash
bin/rails console
```

#### Creating records

```ruby
Bookmark.create(title: "Google", url: "https://google.com")
```

Rails shows you the SQL it ran:

```sql
INSERT INTO "bookmarks" ("title", "url", "created_at", "updated_at") VALUES (...)
```

You wrote Ruby. ActiveRecord translated it to SQL. Notice that `created_at` and `updated_at` were filled in automatically.

#### Querying records

```ruby
Bookmark.all
# SELECT "bookmarks".* FROM "bookmarks"

Bookmark.find(1)
# SELECT "bookmarks".* FROM "bookmarks" WHERE "bookmarks"."id" = 1

Bookmark.column_names
# ["id", "title", "url", "created_at", "updated_at"]
```

**NOTE** Pay attention to the SQL that Rails logs. You never write SQL directly, but reading these logs helps you understand what's happening and spot performance issues as your app grows. This is a mid-level skill worth developing early.

---

### Connecting Model to Controller

Now the controller can return real data instead of placeholder messages.

#### index — list all bookmarks

```ruby
def index
  bookmarks = Bookmark.all
  render json: bookmarks
end
```

Visit `http://localhost:3000/bookmarks`:

```json
[
  {
    "id": 1,
    "title": "Google",
    "url": "https://google.com",
    "created_at": "2026-04-12T12:25:31.552Z",
    "updated_at": "2026-04-12T12:25:31.552Z"
  }
]
```

#### show — one bookmark by ID

```ruby
def show
  bookmark = Bookmark.find(params[:id])
  render json: bookmark
end
```

Visit `http://localhost:3000/bookmarks/1` → returns that specific bookmark.

#### The full MVC flow

1. Browser sends `GET /bookmarks`
2. Router maps it to `BookmarksController#index`
3. Controller calls `Bookmark.all` (talks to the model)
4. Model runs `SELECT * FROM bookmarks` (talks to the database)
5. Controller sends the result back as JSON

---

### Adding a Migration Later

If you want to add a new column to an existing table, you don't edit the old migration. You create a new one:

```bash
bin/rails generate migration AddDescriptionToBookmarks description:string
bin/rails db:migrate
```

Rails reads `Add` + `Description` + `To` + `Bookmarks` and generates:

```ruby
add_column :bookmarks, :description, :string
```

Each migration is a step in your database's history. This is how teams work together — everyone runs the migrations and ends up with the same database structure.

---

### Essential Knowledge

1. **Migrations change structure, not data.** Adding a column = migration. Adding a record = just Ruby code.

2. **Generate then migrate.** The file is just instructions. `bin/rails db:migrate` executes them.

3. **Never edit `schema.rb`.** It's auto-generated. Always create a new migration.

4. **Never edit old migrations that have been run.** If you need to change something, create a new migration. Old migrations are history.

5. **Singular model, plural table.** `Bookmark` → `bookmarks`. Rails maps these automatically.

6. **The console is your playground.** Use `bin/rails console` to test queries, create data, and explore your models before writing controller code.

7. **Read the SQL logs.** ActiveRecord shows you the SQL it generates. Getting comfortable reading these will help you debug and optimize later.

---

### What's Next

We have real data flowing from the database to the browser. But we can only create bookmarks from the console. Next up is **Controllers in depth** — wiring up `create`, `update`, and `destroy` so the API can handle full CRUD through HTTP requests.
