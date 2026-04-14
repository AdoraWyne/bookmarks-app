# Rails — Tagging Through the API

### Lesson Objectives

_After this lesson, you will be able to:_

- Create a second controller for a related resource
- Use `only:` to limit routes to what you need
- Permit array parameters in strong params
- Assign associations through the API using `tag_ids`
- Understand how `has_many :through` connects to strong parameters

---

### The Problem

We can create tags and assign them to bookmarks, but only from the console. The API should let clients:

1. Create and list tags
2. Add tags to a bookmark when creating or updating it

---

### Tags Controller

First, add the route. We only need `index` and `create` for tags — list them and make new ones:

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "bookmarks#index"
  resources :bookmarks, except: [:new, :edit]
  resources :tags, only: [:index, :create]
end
```

`only: [:index, :create]` is the opposite of `except:` — instead of removing routes you don't want, you list the ones you do want. Use whichever reads more clearly.

Run `bin/rails routes` to confirm only two tag routes exist.

Create the controller:

```bash
touch app/controllers/tags_controller.rb
```

```ruby
class TagsController < ApplicationController
  def index
    tags = Tag.all
    render json: tags
  end

  def create
    tag = Tag.new(params.require(:tag).permit(:name))

    if tag.save
      render json: tag, status: :created
    else
      render json: { errors: tag.errors }, status: :unprocessable_entity
    end
  end
end
```

This follows the exact same pattern as `BookmarksController` — nothing new here. The strong parameters just permit `:name` instead of `:title` and `:url`.

#### Testing it

Create a tag:

```bash
curl -X POST http://localhost:3000/tags \
  -H "Content-Type: application/json" \
  -d '{"tag": {"name": "frontend"}}'
```

List all tags by visiting `http://localhost:3000/tags` in the browser.

---

### Adding Tags to Bookmarks Through the API

This is where it gets interesting. Update `bookmark_params` to accept tag IDs:

```ruby
def bookmark_params
  params.require(:bookmark).permit(:title, :url, tag_ids: [])
end
```

`tag_ids: []` means "permit an array of tag IDs." The `[]` tells Rails this parameter is an array, not a single value. Without the `[]`, Rails would reject the array.

#### How this works — the full chain

This is worth understanding step by step:

**1. Strong params lets the data through:**

```ruby
permit(:title, :url, tag_ids: [])
# allows: { title: "React Docs", url: "https://react.dev", tag_ids: [4] }
```

**2. `has_many :through` provides the method:**

When you declared `has_many :tags, through: :bookmark_tags` in the Bookmark model, Rails automatically created a `tag_ids=` setter method on Bookmark. You didn't write it — Rails generated it from the association.

**3. Rails connects the dots:**

When `Bookmark.new(bookmark_params)` receives `tag_ids: [4]`, it calls the auto-generated `tag_ids=` method, which creates a row in the `bookmark_tags` join table:

```
bookmark_tags: { bookmark_id: 6, tag_id: 4 }
```

You didn't write any join table logic. You just:

- Permitted the param
- Declared the association
- Rails handled the rest

#### Creating a bookmark with tags

```bash
curl -X POST http://localhost:3000/bookmarks \
  -H "Content-Type: application/json" \
  -d '{"bookmark": {"title": "React Docs", "url": "https://react.dev", "tag_ids": [4]}}'
```

Response:

```json
{
  "id": 6,
  "title": "React Docs",
  "url": "https://react.dev",
  "tags": [{ "id": 4, "name": "frontend" }]
}
```

#### Updating a bookmark's tags

```bash
curl -X PATCH http://localhost:3000/bookmarks/6 \
  -H "Content-Type: application/json" \
  -d '{"bookmark": {"tag_ids": [3, 4]}}'
```

This updates only the tags — title and URL stay unchanged (PATCH sends only what changed).

---

### Replace, Not Append

`tag_ids` **replaces** all tags — it doesn't append to the existing ones.

If a bookmark has tags `[4]` and you send `tag_ids: [3, 4]`, it now has exactly `[3, 4]`.

If you send `tag_ids: [1]`, it drops all others and only keeps `[1]`.

If you send `tag_ids: []`, it removes all tags.

Same concept as setting state in React — you're providing the full new list, not pushing to it:

```jsx
// React — replaces the array, doesn't append
setTags([3, 4]);

// Not like this
setTags((prev) => [...prev, 4]);
```

---

### The Full Controller Files

#### routes.rb

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "bookmarks#index"
  resources :bookmarks, except: [:new, :edit]
  resources :tags, only: [:index, :create]
end
```

#### tags_controller.rb

```ruby
class TagsController < ApplicationController
  def index
    tags = Tag.all
    render json: tags
  end

  def create
    tag = Tag.new(params.require(:tag).permit(:name))

    if tag.save
      render json: tag, status: :created
    else
      render json: { errors: tag.errors }, status: :unprocessable_entity
    end
  end
end
```

#### bookmarks_controller.rb (updated bookmark_params only)

```ruby
private

def bookmark_params
  params.require(:bookmark).permit(:title, :url, tag_ids: [])
end
```

---

### Essential Knowledge

1. **`only:` and `except:` control which routes are generated.** Use whichever communicates your intent more clearly. For a small set, `only:` reads better. For "everything minus a few", use `except:`.

2. **Array params need `[]` in `permit`.** Writing `permit(:tag_ids)` would reject an array. Writing `permit(tag_ids: [])` tells Rails to expect an array.

3. **`has_many :through` auto-generates `tag_ids=`.** You don't write setter logic for associations. Rails creates the method from the association declaration, and strong params connects to it.

4. **`tag_ids` replaces, not appends.** Sending `tag_ids: [1, 2]` sets the tags to exactly `[1, 2]`, removing any previous tags. Sending `tag_ids: []` removes all tags.

5. **Same pattern, different resource.** The tags controller follows the exact same structure as bookmarks — route → controller → strong params → model. Once you know the pattern, adding new resources is fast.

---

### What's Next

We have a working API with bookmarks, tags, and the ability to associate them. But finding bookmarks is limited to "list all" or "find by ID." Next up is **Scopes & Queries** — filtering bookmarks by tag, searching by title, and writing custom queries.
