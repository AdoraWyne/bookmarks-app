# Rails — Refactoring the Controller

### Lesson Objectives

_After this lesson, you will be able to:_

- Extract repeated code into private methods
- Use `before_action` to run code before specific actions
- Use `rescue_from` to handle errors in one place
- Understand the difference between `find` and `find_by`
- Know why controller helper methods should be private

---

### The Problem: Repeated Code

Before refactoring, the controller had two things repeated across multiple actions:

**Finding a bookmark by ID** — in `show`, `update`, and `destroy`:

```ruby
bookmark = Bookmark.find(params[:id])
```

**Strong parameters** — in `create` and `update`:

```ruby
params.require(:bookmark).permit(:title, :url)
```

Repeated code is a problem because when you change it in one place, you have to remember to change it everywhere. That's how bugs happen.

---

### Private Methods

Extract the repeated code into methods at the bottom of the class, under the `private` keyword:

```ruby
private

def bookmark_params
  params.require(:bookmark).permit(:title, :url)
end

def set_bookmark
  @bookmark = Bookmark.find(params[:id])
end
```

#### What `private` does

Methods below `private` can only be called from **inside** the class:

```ruby
# From inside the class — works fine
def create
  bookmark = Bookmark.new(bookmark_params)  # ✅
end

# From outside — blocked
controller = BookmarksController.new
controller.bookmark_params  # ❌ NoMethodError
```

#### Why this matters in Rails

Rails treats **public methods** in a controller as potential actions that routes can hit. Making helper methods `private` ensures nobody can accidentally route to `/bookmarks/bookmark_params` as a URL. If it's not an action, make it private.

---

### before_action

Instead of calling `set_bookmark` manually in `show`, `update`, and `destroy`, Rails can call it automatically:

```ruby
class BookmarksController < ApplicationController
  before_action :set_bookmark, only: [:show, :update, :destroy]

  # ...
end
```

`before_action` means: "Before running these actions, call `set_bookmark` first." By the time `show` runs, `@bookmark` is already set.

`only:` limits which actions trigger it. Without `only:`, it would run before **every** action — including `index` and `create`, which don't need it.

#### The `@` variable

Notice `set_bookmark` uses `@bookmark` (with `@`), not `bookmark`. The `@` makes it an **instance variable** — it's available across methods in the same request. A regular variable like `bookmark` would only exist inside the method that created it.

```ruby
# set_bookmark sets it
def set_bookmark
  @bookmark = Bookmark.find(params[:id])  # @bookmark is now available everywhere
end

# show can use it
def show
  render json: @bookmark, include: :tags  # same @bookmark from set_bookmark
end
```

This is how `before_action` passes data to the action — through instance variables.

---

### rescue_from — Handling Errors in One Place

When you visit `/bookmarks/9999`, `Bookmark.find(9999)` raises `ActiveRecord::RecordNotFound`. Without handling it, Rails shows an ugly error page.

You might think to add `if/else` in every action:

```ruby
def show
  if @bookmark
    render json: @bookmark
  else
    render json: { error: "Bookmark not found" }, status: :not_found
  end
end
```

But this doesn't work — `find` raises an exception **before** `show` even runs. And even if it did work, you'd need the same `if/else` in `update` and `destroy`.

The Rails way is `rescue_from`:

```ruby
class BookmarksController < ApplicationController
  before_action :set_bookmark, only: [:show, :update, :destroy]
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  # ...

  private

  def not_found
    render json: { error: "Bookmark not found" }, status: :not_found
  end
end
```

`rescue_from` says: "If `ActiveRecord::RecordNotFound` is raised **anywhere** in this controller, catch it and call `not_found` instead of blowing up."

One line handles `show`, `update`, and `destroy`. No `if/else` needed in any action.

---

### find vs find_by

These look similar but behave very differently:

```ruby
Bookmark.find(9999)
# => raises ActiveRecord::RecordNotFound (exception — crashes if not caught)

Bookmark.find_by(id: 9999)
# => returns nil (no exception — you check the result yourself)
```

| Method    | Not found behavior  | Use when                                 |
| --------- | ------------------- | ---------------------------------------- |
| `find`    | Raises an exception | You expect the record to exist           |
| `find_by` | Returns `nil`       | You want to check and handle it yourself |

We use `find` with `rescue_from` because it's cleaner — the error handling is in one place instead of scattered across every action.

---

### The Full Refactored Controller

```ruby
class BookmarksController < ApplicationController
  before_action :set_bookmark, only: [:show, :update, :destroy]
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    bookmarks = Bookmark.all
    render json: bookmarks, include: :tags
  end

  def show
    render json: @bookmark, include: :tags
  end

  def create
    bookmark = Bookmark.new(bookmark_params)

    if bookmark.save
      render json: bookmark, include: :tags, status: :created
    else
      render json: { errors: bookmark.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @bookmark.update(bookmark_params)
      render json: @bookmark, include: :tags
    else
      render json: { errors: @bookmark.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @bookmark.destroy
    head :no_content
  end

  private

  def not_found
    render json: { error: "Bookmark not found" }, status: :not_found
  end

  def set_bookmark
    @bookmark = Bookmark.find(params[:id])
  end

  def bookmark_params
    params.require(:bookmark).permit(:title, :url)
  end
end
```

Compare this to the version before refactoring — every action is shorter and focused on its job. The shared concerns (finding a bookmark, permitting params, handling not-found) are each handled in one place.

---

### Essential Knowledge

1. **If it's not an action, make it `private`.** Public methods in a controller can be routed to. Private methods can't.

2. **`before_action` runs code before specific actions.** Always use `only:` to limit which actions it applies to. Running unnecessary code before every action is wasteful.

3. **`@` variables are shared across methods in one request.** `before_action` sets them, actions use them. Regular variables die when their method ends.

4. **`rescue_from` catches exceptions in one place.** Instead of `if/else` in every action, handle the error once. This is especially useful for common exceptions like `RecordNotFound`.

5. **`find` raises, `find_by` returns nil.** Choose based on whether you want exception-based or nil-based error handling. With `rescue_from`, use `find`.

6. **Refactoring isn't about being clever.** It's about making each piece of code responsible for one thing. When something changes, you only change it in one place.

---

### What's Next

The controller is clean, but we can only tag bookmarks from the console. Next we'll add the ability to **tag bookmarks through the API** and build out the tags controller — so clients can create tags and assign them to bookmarks via HTTP requests.
