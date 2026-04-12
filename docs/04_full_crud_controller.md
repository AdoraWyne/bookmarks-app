# Rails — Full CRUD Controller

### Lesson Objectives

_After this lesson, you will be able to:_

- Build all 5 CRUD actions in a controller (index, show, create, update, destroy)
- Understand strong parameters and why they exist
- Use the correct HTTP status codes for each action
- Test API endpoints with `curl`
- Understand CSRF protection and when to skip it

---

### The Full Controller

```ruby
class BookmarksController < ApplicationController
  def index
    bookmarks = Bookmark.all
    render json: bookmarks
  end

  def show
    bookmark = Bookmark.find(params[:id])
    render json: bookmark
  end

  def create
    bookmark = Bookmark.new(params.require(:bookmark).permit(:title, :url))

    if bookmark.save
      render json: bookmark, status: :created
    else
      render json: { errors: bookmark.errors }, status: :unprocessable_entity
    end
  end

  def update
    bookmark = Bookmark.find(params[:id])

    if bookmark.update(params.require(:bookmark).permit(:title, :url))
      render json: bookmark
    else
      render json: { errors: bookmark.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    bookmark = Bookmark.find(params[:id])
    bookmark.destroy
    head :no_content
  end
end
```

---

### Strong Parameters

This is the most important new concept in this lesson:

```ruby
params.require(:bookmark).permit(:title, :url)
```

It does two things:

`.require(:bookmark)` → the params **must** have a `bookmark` key at the top level. If someone sends `{"title": "..."}` without the wrapper, Rails rejects the request.

`.permit(:title, :url)` → only allow `title` and `url` through. Everything else gets silently ignored.

#### Why this exists

Without strong parameters, someone could send any field and modify any column. Imagine:

```json
{ "bookmark": { "title": "Hack", "admin": true } }
```

With `.permit(:title, :url)`, the `admin` field is silently dropped. Only `title` and `url` can be set.

This was a real vulnerability in early Rails — a GitHub hack in 2012 exploited exactly this. Strong parameters were added to fix it.

#### The JSON structure

Because of `.require(:bookmark)`, your request body must wrap the data inside a `bookmark` key:

```json
{
  "bookmark": {
    "title": "Stack Overflow",
    "url": "https://stackoverflow.com"
  }
}
```

Not just:

```json
{
  "title": "Stack Overflow",
  "url": "https://stackoverflow.com"
}
```

---

### Bookmark.new vs Bookmark.create

These look similar but behave differently:

```ruby
# Two steps — build in memory, then save
bookmark = Bookmark.new(title: "Google", url: "https://google.com")
bookmark.save  # returns true or false

# One step — build and save immediately
bookmark = Bookmark.create(title: "Google", url: "https://google.com")
```

We use `Bookmark.new` + `bookmark.save` in the controller because we need to check whether the save succeeded before deciding what to respond with. `Bookmark.create` just does both in one shot — great for the console, but in a controller you usually want the two-step version.

---

### HTTP Status Codes

Each action returns a different status code that tells the client what happened:

| Action    | Status           | Code          | Why                            |
| --------- | ---------------- | ------------- | ------------------------------ |
| `index`   | `200 OK`         | Default       | Just returning data            |
| `show`    | `200 OK`         | Default       | Just returning data            |
| `create`  | `201 Created`    | `:created`    | A new resource was made        |
| `update`  | `200 OK`         | Default       | Existing resource was modified |
| `destroy` | `204 No Content` | `:no_content` | Deleted, nothing to send back  |

`render json:` returns `200 OK` by default, so you only need to specify the status when it's something different.

`head :no_content` is a special response — it sends just the status code with no body. Makes sense for `destroy` because there's nothing left to send back.

Rails lets you use symbols (`:created`) or numbers (`201`). They're the same. Symbols are more readable.

---

### CRUD with curl

Since we don't have a frontend, we use `curl` to test our API. Think of `curl` as a bare-bones browser that can send any HTTP method.

#### Create a bookmark

```bash
curl -X POST http://localhost:3000/bookmarks \
  -H "Content-Type: application/json" \
  -d '{"bookmark": {"title": "Stack Overflow", "url": "https://stackoverflow.com"}}'
```

- `-X POST` → the HTTP method
- `-H "Content-Type: application/json"` → tells Rails "I'm sending JSON"
- `-d '{ ... }'` → the request body

#### Read all bookmarks

```bash
curl http://localhost:3000/bookmarks
```

No `-X` needed — `curl` defaults to GET.

#### Read one bookmark

```bash
curl http://localhost:3000/bookmarks/1
```

#### Update a bookmark

```bash
curl -X PATCH http://localhost:3000/bookmarks/1 \
  -H "Content-Type: application/json" \
  -d '{"bookmark": {"title": "Google Search"}}'
```

**NOTE** PATCH only sends the fields you want to change. You don't need to include every field — the rest stay unchanged. Same concept as `setState(prev => ({ ...prev, title: "new" }))` in React.

#### Delete a bookmark

```bash
curl -X DELETE http://localhost:3000/bookmarks/1
```

---

### CSRF Protection

When we first tried the `curl` POST, it failed with a big HTML error page. That was CSRF protection.

**CSRF (Cross-Site Request Forgery)** is an attack where a malicious website tricks your browser into making requests to another site. Rails prevents this by requiring a special token on every non-GET request.

For HTML forms served by Rails, this is handled automatically — Rails embeds the token in the form. But for an API that receives JSON from `curl` or a React frontend, this token mechanism doesn't work.

The fix for now:

```ruby
class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token
end
```

This disables CSRF checks for all controllers. This is fine for learning and for API-only apps. In production with a real frontend, you'd handle security through CORS configuration and token-based authentication instead. We'll cover this in the authentication lesson.

---

### Essential Knowledge

1. **Strong parameters are security.** Always use `.require` and `.permit` to control which fields can be set. Never pass `params` directly to a model.

2. **`new` + `save` vs `create`.** Use the two-step version in controllers so you can check success/failure. Use `.create` in the console for convenience.

3. **Status codes matter.** They tell the client what happened. A frontend developer relying on your API will check these codes to decide what to show the user.

4. **PATCH for partial updates.** You only send the fields that changed. Rails handles merging them with the existing record.

5. **`head :no_content` for destroy.** No body needed — the resource is gone.

6. **Watch for typos in `params`.** Writing `param[:id]` instead of `params[:id]` will give you a confusing error. Rails won't tell you "you misspelled params" — it'll just blow up. Read the error carefully.

---

### What's Next

We can create, read, update, and delete bookmarks, but there's no validation — we could create a bookmark with no title or an empty URL. Next up is **Validations** — making sure data is correct before it gets saved to the database.
