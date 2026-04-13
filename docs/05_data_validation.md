# Rails — Validations

### Lesson Objectives

_After this lesson, you will be able to:_

- Add validations to a model
- Understand why validations live in the model, not the controller
- Use `presence`, `format`, and `uniqueness` validations
- Check if a record was saved and read its errors
- Understand how validation errors flow from model → controller → client

---

### Why Validations?

Without validations, anything goes:

```ruby
Bookmark.create(title: "", url: "")  # saves successfully — empty bookmark
Bookmark.create(title: "Bad", url: "not-a-url")  # saves — broken URL
```

Validations are rules that check data **before** it gets saved to the database. If any rule fails, the record is rejected.

#### Why they live in the model

Validations go in the model, not the controller. This is a deliberate design choice — data can be created from multiple places (controller, console, background jobs, seeds), but the model is the one place all of them go through. Put the rules there and they apply everywhere.

```
Controller  ──→
Console     ──→  Model (validations here)  ──→  Database
Background Job ──→
```

If validations were in the controller, you'd have to duplicate them in every place that creates data. That's how bugs happen.

---

### Adding Validations

Open `app/models/bookmark.rb`:

```ruby
class Bookmark < ApplicationRecord
  validates :title, presence: true
  validates :url, presence: true,
                   format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" },
                   uniqueness: true
end
```

Let's break each one down.

#### presence

```ruby
validates :title, presence: true
```

The field cannot be blank. No `nil`, no empty string `""`. The most common validation you'll use.

#### format

```ruby
validates :url, format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" }
```

The value must match a regex pattern. Let's read the regex:

- `\A` → start of string (like `^` but safer in Ruby)
- `https?` → "http" followed by an optional "s"
- `:\/\/` → the literal "://"

So it matches URLs starting with `http://` or `https://`.

`message:` overrides the default error message. Without it, Rails would say "Url is invalid" — which isn't helpful. Custom messages tell the user exactly what's wrong.

#### uniqueness

```ruby
validates :url, uniqueness: true
```

No two bookmarks can have the same URL. Rails checks the database before saving.

**NOTE** `uniqueness` validation has a race condition — two requests could check at the same time, both find no duplicate, and both save. In production, you'd also add a **database-level unique index** to be safe. We'll cover this when we revisit migrations.

---

### How to Check Validation Results

In the console, `Bookmark.create` always returns an object — but it might not be saved:

```ruby
b = Bookmark.create(title: "", url: "")

b.persisted?
# => false (not saved to the database)

b.errors.full_messages
# => ["Title can't be blank", "Url can't be blank"]
```

#### `persisted?`

Returns `true` if the record exists in the database, `false` if it doesn't. Quick way to check if a save succeeded.

#### `errors.full_messages`

Returns an array of human-readable error strings. Rails auto-generates these from the validation rules.

#### `errors` as a hash

```ruby
b.errors
# => { title: ["can't be blank"], url: ["can't be blank"] }
```

The hash format is what the controller sends back as JSON — each field maps to an array of error messages. A field can have multiple errors.

---

### How Errors Flow to the Client

Here's the full path a validation error takes:

**1. Client sends bad data:**

```bash
curl -X POST http://localhost:3000/bookmarks \
  -H "Content-Type: application/json" \
  -d '{"bookmark": {"title": "", "url": ""}}'
```

**2. Controller tries to save:**

```ruby
def create
  bookmark = Bookmark.new(params.require(:bookmark).permit(:title, :url))

  if bookmark.save          # ← validations run here, returns false
    render json: bookmark, status: :created
  else
    render json: { errors: bookmark.errors }, status: :unprocessable_entity
  end
end
```

**3. Model validates and rejects:**

`bookmark.save` calls the validations. They fail. `save` returns `false`. The errors are stored on the `bookmark` object.

**4. Client receives the errors:**

```json
{
  "errors": {
    "title": ["can't be blank"],
    "url": ["can't be blank"]
  }
}
```

With a `422 Unprocessable Entity` status.

If you were building a React frontend, you'd read this response and display the errors next to each form field:

```jsx
// React side
const response = await fetch('/bookmarks', { method: 'POST', ... })
const data = await response.json()

if (!response.ok) {
  // data.errors.title => ["can't be blank"]
  // data.errors.url => ["can't be blank"]
  setErrors(data.errors)
}
```

---

### When Validations Run

Validations run when you call any method that saves to the database:

- `bookmark.save` → returns `true` or `false`
- `bookmark.save!` → returns `true` or **raises an exception**
- `bookmark.update(...)` → returns `true` or `false`
- `Bookmark.create(...)` → returns the object (check `persisted?`)

They do **not** run on:

- `Bookmark.new(...)` → just builds in memory, no validation
- `bookmark.update_column(...)` → skips validations (escape hatch, use rarely)

---

### Multiple Validations on One Field

You can stack validations on a single field:

```ruby
validates :url, presence: true,
                format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" },
                uniqueness: true
```

Rails checks them in order. If `presence` fails, it won't bother checking `format` or `uniqueness`.

You can also split them across multiple lines — same result:

```ruby
validates :url, presence: true
validates :url, format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" }
validates :url, uniqueness: true
```

Both styles are valid. Combining them into one line is more common when the validations are all on the same field.

---

### Essential Knowledge

1. **Validations go in the model.** Not the controller. The model is the gatekeeper for all data, no matter where it comes from.

2. **`save` returns a boolean.** Use `if bookmark.save` in controllers to handle success and failure differently.

3. **`errors.full_messages` for humans, `errors` for machines.** Use `full_messages` in the console for debugging. Send `errors` as JSON for the frontend to parse.

4. **`uniqueness` needs a database backup.** The Rails validation alone has a race condition. For production, add a unique index in a migration too.

5. **Custom error messages matter.** "Url is invalid" is confusing. "Url must start with http:// or https://" is actionable. Always think about who's reading the error.

6. **Validations don't run on `.new`.** They only run when you try to save. `Bookmark.new(title: "")` won't raise any errors — `bookmark.save` will.

---

### What's Next

We have a working API with validations. But right now all bookmarks are just a flat list. Next up is **Associations** — connecting bookmarks to tags using `has_many`, `belongs_to`, and `has_many :through`. This is where the data model gets interesting.
