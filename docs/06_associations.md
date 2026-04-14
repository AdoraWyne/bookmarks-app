# Rails — Associations

### Lesson Objectives

_After this lesson, you will be able to:_

- Understand one-to-many and many-to-many relationships
- Create a join table with `references`
- Use `belongs_to`, `has_many`, and `has_many :through`
- Query associations in both directions
- Include associations in JSON responses
- Know the difference between columns and associations

---

### The Problem

Bookmarks are a flat list. But you want to organize them — a bookmark for "React Docs" might be tagged with "frontend" and "javascript". And the tag "javascript" might be on many different bookmarks.

One bookmark → many tags. One tag → many bookmarks. That's a **many-to-many** relationship.

---

### Many-to-Many Needs a Join Table

In a database, you can't directly connect two tables for many-to-many. You need a table in the middle:

```
bookmarks          bookmark_tags          tags
---------          -------------          ----
id                 id                     id
title              bookmark_id            name
url                tag_id
```

The `bookmark_tags` table holds pairs: "bookmark 1 has tag 3", "bookmark 1 has tag 5", "bookmark 2 has tag 3". Each row is one connection between a bookmark and a tag.

---

### Creating the Models

#### Tag model

```bash
bin/rails generate model Tag name:string
```

This creates both the migration and the model file in one command. The migration:

```ruby
class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name

      t.timestamps
    end
  end
end
```

The model at `app/models/tag.rb`:

```ruby
class Tag < ApplicationRecord
end
```

#### Join table

```bash
bin/rails generate model BookmarkTag bookmark:references tag:references
```

The `references` type is new. It creates a foreign key column that points to another table:

```ruby
class CreateBookmarkTags < ActiveRecord::Migration[8.1]
  def change
    create_table :bookmark_tags do |t|
      t.references :bookmark, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
  end
end
```

Let's break down the new parts:

```ruby
t.references :bookmark, null: false, foreign_key: true
```

- `t.references :bookmark` → creates a `bookmark_id` column
- `null: false` → the column can't be empty (every join record must point to a bookmark)
- `foreign_key: true` → the database enforces that the ID must match an actual bookmark that exists

Same for `t.references :tag` — creates a `tag_id` column.

Run both migrations:

```bash
bin/rails db:migrate
```

---

### Wiring Up the Relationships

The database tables exist, but the models don't know about each other yet. Three files need to be updated.

#### BookmarkTag (the join model)

The generator already added this because we used `references`:

```ruby
class BookmarkTag < ApplicationRecord
  belongs_to :bookmark
  belongs_to :tag
end
```

`belongs_to` means: this record **must** point to one bookmark and one tag. The `bookmark_id` and `tag_id` columns hold those references.

#### Tag

```ruby
class Tag < ApplicationRecord
  has_many :bookmark_tags
  has_many :bookmarks, through: :bookmark_tags

  validates :name, presence: true, uniqueness: true
end
```

#### Bookmark

```ruby
class Bookmark < ApplicationRecord
  validates :title, presence: true
  validates :url, presence: true,
                   format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" },
                   uniqueness: true

  has_many :bookmark_tags
  has_many :tags, through: :bookmark_tags
end
```

#### Reading `has_many :through`

```ruby
has_many :bookmark_tags
has_many :tags, through: :bookmark_tags
```

Line 1: "A bookmark has many bookmark_tags" (the join records).
Line 2: "A bookmark has many tags, by going **through** the bookmark_tags table."

You need both lines. The first establishes the connection to the join table. The second uses that connection to reach the tags.

#### Why Rails does it this way

Each association declaration teaches Rails how to build a SQL query. When you call `bookmark.tags`, Rails knows to:

1. Look at the `bookmark_tags` table for rows where `bookmark_id` matches
2. Take those `tag_id` values
3. Fetch the matching tags

You can see this in the SQL Rails logs:

```sql
SELECT "tags".* FROM "tags"
INNER JOIN "bookmark_tags" ON "tags"."id" = "bookmark_tags"."tag_id"
WHERE "bookmark_tags"."bookmark_id" = 1
```

---

### Using Associations in the Console

#### Adding tags to a bookmark

```ruby
b = Bookmark.first
t = Tag.create(name: "search-engine")
b.tags << t           # adds the tag to this bookmark
b.tags                 # returns all tags for this bookmark
```

`b.tags << t` creates a row in `bookmark_tags` with `bookmark_id: 1, tag_id: 1`.

You can also create and associate in one step:

```ruby
b.tags.create(name: "google")
b.tags.create(name: "daily-use")
```

#### Going the other direction

Associations work both ways:

```ruby
t = Tag.find_by(name: "daily-use")
t.bookmarks           # returns all bookmarks with this tag
```

This works because both models have `has_many :through`.

---

### Columns vs Associations

This is an important mental model:

```ruby
b.title          # column → data stored directly on the bookmarks table
b.tags           # association → Rails queries the tags table through bookmark_tags
b.bookmark_tags  # association → Rails queries the bookmark_tags table
```

To see a record's columns:

```ruby
b.attributes       # all columns and their values as a hash
b.attribute_names  # just the column names as an array
# => ["id", "title", "url", "created_at", "updated_at"]
```

`tags` and `bookmark_tags` won't appear in `attributes` — they're not columns. They're methods that Rails generates from `has_many`, and each one runs a separate database query.

Think of it like React: `b.title` is like reading a prop — the data is right there. `b.tags` is like calling `fetch` — Rails goes to another table to get it.

---

### Including Associations in JSON

By default, `render json:` only serializes a record's own columns:

```ruby
render json: bookmark
# => {"id": 1, "title": "...", "url": "...", "created_at": "...", "updated_at": "..."}
```

To include associations, use `include:`:

```ruby
render json: bookmark, include: :tags
# => {"id": 1, "title": "...", ..., "tags": [{"id": 1, "name": "search-engine"}, ...]}
```

You can include multiple associations:

```ruby
render json: bookmark, include: [:tags, :bookmark_tags]
```

Rails doesn't include associations by default because each one means another database query. You explicitly opt in to the extra data.

#### Updated controller

```ruby
def index
  bookmarks = Bookmark.all
  render json: bookmarks, include: :tags
end

def show
  bookmark = Bookmark.find(params[:id])
  render json: bookmark, include: :tags
end
```

---

### The Three Association Types So Far

| Declaration                | Means                                                    | Example                 |
| -------------------------- | -------------------------------------------------------- | ----------------------- |
| `belongs_to :bookmark`     | "I have a `bookmark_id` column pointing to one bookmark" | BookmarkTag → Bookmark  |
| `has_many :bookmark_tags`  | "Another table has rows pointing to me"                  | Bookmark → BookmarkTags |
| `has_many :tags, through:` | "I can reach tags by going through the join table"       | Bookmark → Tags         |

#### belongs_to vs has_many

The rule is simple: **whoever has the foreign key column uses `belongs_to`**. The `bookmark_tags` table has `bookmark_id` and `tag_id`, so `BookmarkTag` belongs to both.

---

### Essential Knowledge

1. **Many-to-many needs a join table.** You can't directly connect two tables. The join table sits in the middle and holds pairs of IDs.

2. **`has_many :through` needs two lines.** First `has_many :join_records`, then `has_many :targets, through: :join_records`. Both are required.

3. **`references` in a migration creates a foreign key column.** `t.references :bookmark` creates `bookmark_id` with an index and optional database-level enforcement.

4. **Associations are methods, not columns.** They don't show up in `attributes`. Each one is a separate database query.

5. **`include:` opts into extra data.** Default JSON only has columns. You must explicitly ask for associations to be included.

6. **Associations work both directions.** If both models have `has_many :through`, you can go from bookmark → tags and from tag → bookmarks.

7. **`belongs_to` goes on the model with the foreign key.** If the table has a `bookmark_id` column, that model uses `belongs_to :bookmark`.

---

### What's Next

We have bookmarks with tags, but there's some repeated code in the controller — the strong parameters line appears in both `create` and `update`. Next up is **Refactoring the Controller** — extracting shared code, handling errors gracefully, and adding the ability to tag bookmarks through the API.
