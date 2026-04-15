# Rails — Callbacks & the N+1 Problem

### Lesson Objectives

_After this lesson, you will be able to:_

- Identify the N+1 query problem
- Fix N+1 with `includes` (eager loading)
- Understand when and why to use callbacks
- Use `before_save` and `after_save`
- Know the full lifecycle of a Rails record

---

### The N+1 Problem

Visit `http://localhost:3000/bookmarks` and check your server logs. With `Bookmark.all`, you'll see something like:

```
Bookmark Load (0.1ms)  SELECT "bookmarks".* FROM "bookmarks"
Tag Load (0.1ms)  SELECT "tags".* ... WHERE "bookmark_tags"."bookmark_id" = 1
Tag Load (0.1ms)  SELECT "tags".* ... WHERE "bookmark_tags"."bookmark_id" = 2
Tag Load (0.1ms)  SELECT "tags".* ... WHERE "bookmark_tags"."bookmark_id" = 4
Tag Load (0.1ms)  SELECT "tags".* ... WHERE "bookmark_tags"."bookmark_id" = 5
Tag Load (0.1ms)  SELECT "tags".* ... WHERE "bookmark_tags"."bookmark_id" = 6
```

That's 6 queries — 1 for bookmarks + 5 for their tags (one per bookmark). This is the **N+1 problem**: 1 query to get the list, then N queries to get each item's associations.

The culprit is `include: :tags` in the controller:

```ruby
render json: bookmarks, include: :tags
```

When Rails serializes each bookmark to JSON, it calls `.tags` on each one. Each call is a separate database query:

```
"Let me render bookmark 1... what are its tags?" → query
"Let me render bookmark 2... what are its tags?" → query
"Let me render bookmark 4... what are its tags?" → query
...
```

With 5 bookmarks, that's 6 queries. With 100, it'd be 101. With 10,000, it'd be 10,001. It doesn't scale.

#### Why this matters

This is one of the most common performance issues in Rails apps, and one of the first things senior developers look for in code reviews. Every database query takes time — network round trip, query parsing, result serialization. Multiplying that by N can make a fast endpoint slow.

---

### The Fix: Eager Loading with `includes`

```ruby
def index
  bookmarks = Bookmark.includes(:tags)
  bookmarks = bookmarks.search(params[:search]) if params[:search].present?
  bookmarks = bookmarks.tagged(params[:tag]) if params[:tag].present?
  render json: bookmarks, include: :tags
end
```

Changed `Bookmark.all` to `Bookmark.includes(:tags)`. Now check the logs:

```sql
-- Query 1: Get all bookmarks
SELECT "bookmarks".* FROM "bookmarks"

-- Query 2: Get all join records for those bookmarks (bulk)
SELECT "bookmark_tags".* FROM "bookmark_tags"
WHERE "bookmark_tags"."bookmark_id" IN (1, 2, 4, 5, 6)

-- Query 3: Get all tags for those join records (bulk)
SELECT "tags".* FROM "tags"
WHERE "tags"."id" IN (1, 2, 3, 4)
```

Always 3 queries, no matter how many bookmarks. Instead of asking one-by-one, Rails uses `IN (...)` to fetch all related records at once.

```ruby
# N+1 — one query per bookmark (scales badly)
Bookmark.all
# 1 + N queries

# Eager loading — bulk fetch (scales well)
Bookmark.includes(:tags)
# Always 3 queries
```

#### How `includes` knows what to do

`includes(:tags)` works because of the associations you defined:

```ruby
has_many :bookmark_tags
has_many :tags, through: :bookmark_tags
```

Rails reads this chain and knows: fetch bookmarks → fetch bookmark_tags → fetch tags. Three tables in the chain = 3 queries. If it were a direct `has_many :tags` without a join table, it would be 2 queries.

#### `includes` still means "all"

`includes(:tags)` starts with all bookmarks, just like `all`. It also pre-loads their tags. You can still chain filters:

```ruby
Bookmark.includes(:tags).search("react")
# "get bookmarks matching 'react', AND pre-load their tags"
```

---

### Callbacks

A callback is a method that Rails automatically runs at a specific point in a record's lifecycle. You don't call it — Rails does.

#### after_save — running code after a save

```ruby
class Bookmark < ApplicationRecord
  after_save :log_save

  private

  def log_save
    Rails.logger.info "Bookmark saved: #{title} (#{url})"
  end
end
```

In the console:

```ruby
Bookmark.create(title: "Test", url: "https://example.com")
```

The log output:

```
BEGIN TRANSACTION
  INSERT INTO "bookmarks" ...       ← save happens
  Bookmark saved: Test (https://...)  ← callback runs
COMMIT TRANSACTION                    ← transaction completes
```

The callback runs **inside** the transaction, after the save but before the commit. If the callback raises an error, the whole save rolls back.

#### before_save — modifying data before it's saved

```ruby
class Bookmark < ApplicationRecord
  # ... validations, associations, scopes

  before_save :set_default_description

  private

  def set_default_description
    if description.blank?
      self.description = "Bookmark for #{title}"
    end
  end
end
```

`before_save` runs **before** the record is written to the database — so any changes you make to attributes will be included in the INSERT or UPDATE.

In the console:

```ruby
# No description provided — callback sets a default
b = Bookmark.create(title: "MDN Web Docs", url: "https://developer.mozilla.org")
b.description
# => "Bookmark for MDN Web Docs"

# Description provided — callback skips it
b = Bookmark.create(title: "Ruby Lang", url: "https://ruby-lang.org", description: "Official Ruby site")
b.description
# => "Official Ruby site"
```

#### Why `self.description =` needs `self`

When **setting** an attribute inside a model method, you must use `self`:

```ruby
# This sets the attribute on the record
self.description = "something"

# This creates a local variable (does nothing useful)
description = "something"
```

When **reading**, you don't need `self`:

```ruby
# Both work for reading
description.blank?
self.description.blank?
```

---

### Adding the `description` Column

We added a new column with a migration:

```bash
bin/rails generate migration AddDescriptionToBookmarks description:string
bin/rails db:migrate
```

And updated `bookmark_params` to permit it:

```ruby
def bookmark_params
  params.require(:bookmark).permit(:title, :url, :description, tag_ids: [])
end
```

#### Permitting arrays vs single values

```ruby
permit(:title, :url, :description, tag_ids: [])
```

`:title`, `:url`, `:description` are all symbols — they expect a single value each.

`tag_ids: []` is also a symbol, but it needs extra information. The `[]` tells Rails to expect an **array**. Without it, Rails would reject `tag_ids: [1, 2, 3]`.

```ruby
# These are the same — tag_ids: [] is just modern Ruby hash syntax
permit(:title, :url, :description, tag_ids: [])
permit(:title, :url, :description, :tag_ids => [])
```

---

### The Full Callback Lifecycle

Rails has callbacks for every moment in a record's life:

| Callback            | When it runs                                      |
| ------------------- | ------------------------------------------------- |
| `before_validation` | Before validations check the data                 |
| `after_validation`  | After validations pass                            |
| `before_save`       | Before writing to the database (create or update) |
| `after_save`        | After writing to the database (create or update)  |
| `before_create`     | Before INSERT (new records only)                  |
| `after_create`      | After INSERT (new records only)                   |
| `before_update`     | Before UPDATE (existing records only)             |
| `after_update`      | After UPDATE (existing records only)              |
| `before_destroy`    | Before DELETE                                     |
| `after_destroy`     | After DELETE                                      |

#### save vs create vs update

`before_save` runs on **both** create and update. `before_create` only runs when a new record is being inserted. `before_update` only runs when an existing record is being modified.

We used `before_save` for the default description because we want it to apply whether you're creating a new bookmark or updating an existing one.

#### The full order for a new record

```
before_validation
after_validation
before_save
before_create
  → INSERT INTO database
after_create
after_save
```

#### The full order for updating a record

```
before_validation
after_validation
before_save
before_update
  → UPDATE database
after_update
after_save
```

---

### The Full Model

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

  before_save :set_default_description

  private

  def set_default_description
    if description.blank?
      self.description = "Bookmark for #{title}"
    end
  end
end
```

---

### Essential Knowledge

1. **N+1 is the most common Rails performance problem.** Look for it whenever you render a list with associations. If you see N separate queries in the logs, you probably need `includes`.

2. **`includes` = eager loading = bulk fetching.** It fetches all associated records in a few queries instead of one per record. Always use it when you know you'll need the associations.

3. **Read your server logs.** The number of queries and their execution time are logged on every request. Get in the habit of glancing at them — it's how you catch performance issues before they become problems.

4. **Callbacks run automatically at specific lifecycle points.** Use `before_save` to modify data before it's written. Use `after_save` for side effects like logging.

5. **`before_save` runs on both create and update.** Use `before_create` or `before_update` if you only want one or the other.

6. **`self` is required when setting attributes in a model.** Without it, Ruby creates a local variable instead of updating the record. Reading doesn't need `self`.

7. **Callbacks run inside the transaction.** If a callback raises an error, the save rolls back. This is a safety net but can also cause unexpected rollbacks if your callback code is fragile.

---

### What's Next

We have a solid app with bookmarks, tags, filtering, performance optimization, and callbacks. Next up is **Testing with RSpec** — writing model and request specs to verify everything works and stays working as we make changes.
