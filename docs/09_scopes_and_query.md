# Rails — Scopes & Queries

### Lesson Objectives

_After this lesson, you will be able to:_

- Query records with `where`, `LIKE`, and `joins`
- Understand how `joins` works at the SQL level
- Define reusable scopes in a model
- Chain scopes together
- Connect scopes to API query parameters
- Understand lazy loading and why it matters for performance

---

### Querying in the Console

Rails gives you Ruby methods that translate to SQL. Let's look at three types of queries.

#### Exact match with `where`

```ruby
Bookmark.where(title: "GitHub")
```

SQL:

```sql
SELECT "bookmarks".* FROM "bookmarks" WHERE "bookmarks"."title" = 'GitHub'
```

#### Partial match with LIKE

```ruby
Bookmark.where("title LIKE ?", "%React%")
```

SQL:

```sql
SELECT "bookmarks".* FROM "bookmarks" WHERE (title LIKE '%React%')
```

The `%` means "anything before or after." So `%React%` matches any title containing "React."

The `?` is a placeholder — Rails safely inserts the value for you. Never put user input directly in the string like `"title LIKE '#{params[:search]}'"` — that's a SQL injection vulnerability.

#### Querying across tables with `joins`

```ruby
Bookmark.joins(:tags).where(tags: { name: "daily-use" })
```

SQL:

```sql
SELECT "bookmarks".* FROM "bookmarks"
INNER JOIN "bookmark_tags" ON "bookmark_tags"."bookmark_id" = "bookmarks"."id"
INNER JOIN "tags" ON "tags"."id" = "bookmark_tags"."tag_id"
WHERE "tags"."name" = 'daily-use'
```

You wrote one line of Ruby. Rails built a query that joins three tables — because your `has_many :tags, through: :bookmark_tags` declaration taught Rails how to connect them.

---

### How Joins Work

The database doesn't make two separate trips. It temporarily merges the tables into one combined view:

```
bookmark.id | bookmark.title | tag.id | tag.name
-----------------------------------------------
1           | Google Search  | 3      | daily-use      ← matches
6           | React Docs     | 3      | daily-use      ← matches
1           | Google Search  | 1      | search-engine
1           | Google Search  | 2      | google
6           | React Docs     | 4      | frontend
```

`WHERE tags.name = 'daily-use'` filters this combined view and returns the matching bookmarks. One operation, not two.

Think of it like a spreadsheet — instead of looking up IDs in sheet A, then going to sheet B to find rows, you merge the sheets together and filter the combined sheet.

#### Why not query the join table directly?

You could:

```ruby
BookmarkTag.where(tag_id: 3)
```

But you'd only get join records — pairs of IDs like `{ bookmark_id: 1, tag_id: 3 }`. You'd need a second query to get the actual bookmarks:

```ruby
# Two queries
ids = BookmarkTag.where(tag_id: 3).pluck(:bookmark_id)
Bookmark.where(id: ids)

# One query — joins does both at once
Bookmark.joins(:tags).where(tags: { name: "daily-use" })
```

Fewer queries = faster app. This is the kind of thing that separates junior from mid-level thinking — not just "does it work?" but "how many times am I hitting the database?"

---

### Scopes — Named Reusable Queries

The queries above work, but you don't want to write them out every time. Scopes let you define them once in the model and reuse them by name.

Open `app/models/bookmark.rb`:

```ruby
class Bookmark < ApplicationRecord
  validates :title, presence: true
  validates :url, presence: true,
                   format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" },
                   uniqueness: true

  has_many :bookmark_tags
  has_many :tags, through: :bookmark_tags

  scope :search, ->(query) { where("title LIKE ?", "%#{query}%") }
  scope :tagged, ->(name) { joins(:tags).where(tags: { name: name }) }
end
```

#### Reading a scope

```ruby
scope :search, ->(query) { where("title LIKE ?", "%#{query}%") }
```

- `:search` → the name you'll call it by
- `->(query)` → takes one argument (a lambda / anonymous function)
- `{ where(...) }` → the query it runs

Now in the console:

```ruby
Bookmark.search("react")    # same as Bookmark.where("title LIKE ?", "%react%")
Bookmark.tagged("daily-use") # same as Bookmark.joins(:tags).where(tags: { name: "daily-use" })
```

Same results, but now they're readable, reusable, and chainable.

---

### Connecting Scopes to the API

Users should be able to filter with query parameters:

```
GET /bookmarks?search=react
GET /bookmarks?tag=daily-use
GET /bookmarks?tag=daily-use&search=google
```

Update the `index` action:

```ruby
def index
  bookmarks = Bookmark.all
  bookmarks = bookmarks.search(params[:search]) if params[:search].present?
  bookmarks = bookmarks.tagged(params[:tag]) if params[:tag].present?
  render json: bookmarks, include: :tags
end
```

Each line conditionally adds a filter. `params[:search].present?` checks if the query parameter exists and isn't blank.

Which lines run depends on the URL:

- `/bookmarks` → just `Bookmark.all`, no filters
- `/bookmarks?search=react` → `Bookmark.all` + `.search("react")`
- `/bookmarks?tag=daily-use` → `Bookmark.all` + `.tagged("daily-use")`
- `/bookmarks?tag=daily-use&search=google` → `Bookmark.all` + `.search("google")` + `.tagged("daily-use")`

---

### Lazy Loading — Why This Works Efficiently

This is an important concept. When Rails runs the `index` action, it does NOT hit the database on every line:

```ruby
# Step 1: builds a query object (NO database hit yet)
bookmarks = Bookmark.all

# Step 2: adds a filter to the query (still NO database hit)
bookmarks = bookmarks.search("react") if params[:search].present?

# Step 3: adds another filter (still NO database hit)
bookmarks = bookmarks.tagged("daily-use") if params[:tag].present?

# Step 4: NOW Rails hits the database — because it needs actual data to render
render json: bookmarks, include: :tags
```

Each scope returns a **query object** — a set of instructions describing what to fetch, not the actual data. Rails collects all the conditions and waits until the last possible moment (when `render` needs real data) to hit the database.

It's like building a shopping list vs going to the shop. Steps 1-3 are writing items on the list. Step 4 is actually going shopping.

#### Why this matters

If both filters are present, Rails combines everything into **one** SQL query:

```sql
SELECT "bookmarks".* FROM "bookmarks"
INNER JOIN "bookmark_tags" ON ...
INNER JOIN "tags" ON ...
WHERE (title LIKE '%google%')
AND "tags"."name" = 'daily-use'
```

Not three separate queries — one. Rails waits until the last moment, collects all the conditions, and makes a single efficient trip to the database.

#### Proving it in the console

```ruby
query = Bookmark.all; nil
# No SQL logged — the ; nil prevents the console from displaying
# the result, so Rails never needs to fetch the data
```

Without `; nil`, the console tries to display the result, which forces Rails to execute the query. The query object sits idle until something actually needs the data.

---

### Essential Knowledge

1. **`where` for filtering, `joins` for crossing tables.** `where` filters within one table. `joins` combines tables so you can filter across relationships.

2. **Never interpolate user input into SQL strings.** Use `?` placeholders: `where("title LIKE ?", "%#{query}%")`. Direct interpolation like `"title LIKE '#{query}'"` is a SQL injection vulnerability.

3. **Scopes are named queries.** Define them once in the model, use them everywhere. They're readable, reusable, and chainable.

4. **Scopes return query objects, not data.** This enables chaining and lazy loading. The database is only hit when the data is actually needed.

5. **Lazy loading = fewer database trips.** Rails collects all conditions and makes one efficient query instead of many. Pay attention to your SQL logs to verify this.

6. **`params[:key].present?`** checks if a parameter exists and isn't blank. It's safer than just `if params[:key]` because it also catches empty strings.

7. **Read your SQL logs.** Every query Rails makes is logged in the console and server output. Understanding the SQL helps you spot performance problems early — a mid-level skill worth developing.

---

### What's Next

We have filtering and search, but there's a performance issue hiding in plain sight. When you load all bookmarks with their tags, Rails might make a separate query for each bookmark's tags. Next up is **Callbacks & Performance** — auto-fetching page titles when saving a URL, and fixing the N+1 query problem.
