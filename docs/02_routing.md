# Rails — Routing

### Lesson Objectives

_After this lesson, you will be able to:_

- Use `resources` to generate RESTful routes
- Read the output of `bin/rails routes`
- Understand the 7 standard RESTful actions and when to use each
- Exclude routes you don't need
- Access dynamic URL segments with `params`

---

### What is Routing in Rails?

Routing is the first thing that happens when a request hits your app. The router looks at the URL and HTTP method, then decides which controller and action should handle it.

Think of it like a receptionist. Someone walks in and says "I need to see all bookmarks." The receptionist (router) says "Go to the BookmarksController, talk to the index action."

The router lives in one file: `config/routes.rb`.

---

### Your First Route

We already set this up in the previous lesson:

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "bookmarks#index"
end
```

`root` is a special method that maps `/` (the homepage) to a controller action.

`"bookmarks#index"` means: go to `BookmarksController`, call the `index` method.

---

### Seeing Your Routes

You can see every route in your app at any time:

```bash
bin/rails routes
```

Each row has four columns:

```
name               HTTP method    URL pattern              controller#action
bookmark           GET            /bookmarks/:id           bookmarks#show
```

- **Name** → a helper you can use in code. `bookmark_path(1)` gives you `/bookmarks/1`.
- **HTTP method** → GET, POST, PATCH, PUT, DELETE.
- **URL pattern** → the URL structure. `:id` is a dynamic segment.
- **Controller#action** → which method Rails will call.

**NOTE** `bin/rails routes` is your best friend when debugging. If you're unsure whether a route exists or what URL it expects, run this command.

---

### RESTful Routes with `resources`

A bookmarks app needs full CRUD — create, read, update, delete. You could define each route manually:

```ruby
get "/bookmarks", to: "bookmarks#index"
get "/bookmarks/:id", to: "bookmarks#show"
post "/bookmarks", to: "bookmarks#create"
patch "/bookmarks/:id", to: "bookmarks#update"
delete "/bookmarks/:id", to: "bookmarks#destroy"
```

But Rails gives you a shortcut:

```ruby
resources :bookmarks
```

This single line generates **7 actions** across **8 routes**:

| Action    | HTTP Method | URL                   | Purpose                                           |
| --------- | ----------- | --------------------- | ------------------------------------------------- |
| `index`   | GET         | `/bookmarks`          | List all bookmarks                                |
| `show`    | GET         | `/bookmarks/:id`      | Show one bookmark                                 |
| `new`     | GET         | `/bookmarks/new`      | Show a form to create                             |
| `create`  | POST        | `/bookmarks`          | Save a new bookmark                               |
| `edit`    | GET         | `/bookmarks/:id/edit` | Show a form to edit                               |
| `update`  | PATCH       | `/bookmarks/:id`      | Update a bookmark                                 |
| `update`  | PUT         | `/bookmarks/:id`      | Update a bookmark (same action, alternate method) |
| `destroy` | DELETE      | `/bookmarks/:id`      | Delete a bookmark                                 |

#### Why Rails does it this way

REST is a convention for organising URLs around **resources** (nouns like bookmarks, users, tags) and **actions** (verbs like create, show, delete). Instead of inventing random URL patterns, every Rails developer uses the same structure. When you join a new Rails project, you already know where things are.

This is the same REST convention you use when designing API endpoints in any backend — Rails just automates the boilerplate.

---

### Excluding Routes You Don't Need

`new` and `edit` are for serving HTML forms. Since we're returning JSON (API-only), we don't need them:

```ruby
resources :bookmarks, except: [:new, :edit]
```

Run `bin/rails routes` to confirm they're gone.

You can also go the other way and only include specific routes:

```ruby
resources :bookmarks, only: [:index, :show, :create]
```

Use whichever reads more clearly for your situation.

---

### The Full routes.rb

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "bookmarks#index"
  resources :bookmarks, except: [:new, :edit]
end
```

---

### params — Accessing Dynamic URL Segments

When a route has `:id` in the pattern, Rails extracts the value and puts it in `params`:

```ruby
# Route: GET /bookmarks/:id
# URL visited: /bookmarks/42

def show
  render json: { message: "Showing bookmark #{params[:id]}" }
end

# params[:id] => "42"
```

#### React Router comparison

```ruby
# Rails
params[:id]  # => "42"
```

```jsx
// React Router
const { id } = useParams(); // => "42"
```

Same concept — the `:id` in the URL pattern becomes a key you can access. The value is always a **string** in both Rails and React Router.

**NOTE** `params` isn't just for URL segments. It also contains query parameters and form data. We'll see this when we build the `create` action. For now, just know that `params` is a hash containing everything the request sent you.

---

### The Controller So Far

```ruby
class BookmarksController < ApplicationController
  def index
    render json: { message: "All bookmarks will go here" }
  end

  def show
    render json: { message: "Showing bookmark #{params[:id]}" }
  end

  def create
    render json: { message: "Create a bookmark" }
  end

  def update
    render json: { message: "Update bookmark #{params[:id]}" }
  end

  def destroy
    render json: { message: "Delete bookmark #{params[:id]}" }
  end
end
```

Every action is stubbed out. They all return placeholder JSON for now. Once we create the database and model, these will fetch and save real data.

---

### Essential Knowledge

1. **`resources :bookmarks` is not magic** — it's a shortcut that generates the same routes you'd write by hand. Understanding what it expands to helps you debug routing issues.

2. **`bin/rails routes` is your debugging tool.** Run it whenever you're unsure about a URL, HTTP method, or controller action.

3. **REST is a convention, not a Rails invention.** The 7 actions (index, show, new, create, edit, update, destroy) are a pattern used across all web frameworks. Rails just makes it the default.

4. **`params` is a hash.** It contains URL segments (`:id`), query strings (`?page=2`), and request body data. You access values with `params[:key]`.

5. **`except` and `only` keep your routes clean.** Don't generate routes you won't use — it's confusing for other developers reading your code.

6. **Update gets two HTTP methods.** Both `PATCH` and `PUT` map to the `update` action. `PATCH` is for partial updates, `PUT` is for full replacements. In practice, Rails treats them the same and you'll almost always see `PATCH`.

---

### What's Next

We have routes and a controller, but every action returns a fake message. To return real data, we need a database table and a model. Next up is **Migrations** — how Rails creates and evolves your database schema.
