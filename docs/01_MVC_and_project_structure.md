# Rails — MVC & Project Structure

### Lesson Objectives

_After this lesson, you will be able to:_

- Explain what MVC is and why Rails uses it
- Identify the key folders in a Rails project
- Create a route, a controller, and an action
- Return JSON from a controller
- Follow Rails' error-driven development workflow

---

### What is MVC?

MVC stands for **Model, View, Controller**. It's a pattern for organising your code into three layers, each with a single job:

- **Model** → talks to the database. "Give me all bookmarks" or "Save this new bookmark."
- **View** → what the user sees. HTML templates, or in our case, JSON responses.
- **Controller** → the middleman. Receives the request, asks the model for data, then decides what to send back.

There's also a **Router** that sits in front of everything. It looks at the URL and HTTP method, then decides which controller and action should handle the request.

#### How a request flows through Rails

```
Browser hits GET /bookmarks
        ↓
   Router (config/routes.rb)
   "GET /bookmarks → BookmarksController#index"
        ↓
   Controller (app/controllers/bookmarks_controller.rb)
   "Run the index method"
        ↓
   Model (app/models/bookmark.rb)  ← we'll build this later
   "Fetch data from the database"
        ↓
   Response
   "Send JSON back to the browser"
```

#### React analogy

Think of it like this:

- **Router** → React Router deciding which component to render
- **Controller** → a page component that calls `fetch()` and decides what to show
- **Model** → the API / data layer your component talks to
- **View** → the JSX you return

The difference is Rails **enforces** this as a file structure. You can't put everything in one file. Each piece lives in a specific folder.

---

### Key Folders in a Rails Project

`rails new` generates a lot of files. Most don't matter yet. These are the ones you'll touch:

```
bookmarks_app/
├── app/
│   ├── controllers/    ← the C (handles requests, decides what to respond)
│   ├── models/         ← the M (talks to the database)
│   └── views/          ← the V (HTML templates — we're skipping this)
├── config/
│   └── routes.rb       ← the router (maps URLs → controller actions)
├── db/
│   ├── migrate/        ← database change history (appears after first migration)
│   └── schema.rb       ← current database structure (appears after first migration)
└── Gemfile             ← like package.json — lists your dependencies
```

**NOTE** The `db/migrate/` folder and `schema.rb` don't exist yet. They appear after you create your first migration. That's coming in a later lesson.

---

### Setting Up our First Route

Open `config/routes.rb`. By default it looks like this:

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # root "posts#index"
end
```

The only real route is the health check. The `root` line is commented out — it's a hint from Rails.

#### The health check route explained

```ruby
get "up" => "rails/health#show", as: :rails_health_check
```

- `get "up"` → responds to GET requests at `/up`
- `=> "rails/health#show"` → calls the `show` action in `Rails::HealthController`
- `as: :rails_health_check` → gives this route a name you can reference in code

You can visit `http://localhost:3000/up` to see it in action. Load balancers and monitoring tools use this to check if the app is alive.

#### Adding our root route

Add this line inside the `do...end` block:

```ruby
root "bookmarks#index"
```

Your full `routes.rb` should now look like:

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "bookmarks#index"
end
```

`root` is a special Rails route method. It maps `/` (the homepage) to a controller and action.

`"bookmarks#index"` means:

- `bookmarks` → look for `BookmarksController`
- `#index` → call the `index` method inside it

Save and visit `http://localhost:3000`. You'll get an error. That's expected.

---

### Error-Driven Development

This is a key Rails workflow. **You don't build everything upfront.** You define what you want (a route), then let Rails tell you what's missing. The errors are your guide:

**Error 1 — Missing Controller**

```
ActionDispatch::MissingController in BookmarksController#index
```

Rails says: "You told me to go to `BookmarksController`, but it doesn't exist."

**Fix** → create the controller.

**Error 2 — Missing Template**

```
BookmarksController#index is missing a template for request formats: text/html
```

Rails says: "The controller exists, but I don't know what to respond with."

**Fix** → tell the controller to render JSON instead of looking for an HTML template.

Each error is a breadcrumb pointing you to the next thing to build.

---

### Creating the Controller

Create the file:

```bash
touch app/controllers/bookmarks_controller.rb
```

Add this inside:

```ruby
class BookmarksController < ApplicationController
  def index
    render json: { message: "Welcome to Bookmarks App" }
  end
end
```

Let's break it down line by line:

- `class BookmarksController` → the name **must** match the route. Route said `bookmarks#index`, so Rails looks for `BookmarksController`. This is a Rails naming convention, not a coincidence.
- `< ApplicationController` → inherits from a base controller. This gives you built-in Rails behaviour like params parsing, session handling, CSRF protection, etc.
- `def index` → the action. The route said `bookmarks#index`, so Rails calls this method.
- `render json:` → tells Rails: "Don't look for a view template. Just send this hash as JSON."

Save and visit `http://localhost:3000`. You should see:

```json
{ "message": "Welcome to Bookmarks App" }
```

---

### Why We're Skipping Views

Since the goal is to learn Rails as a backend, we don't need HTML templates. Every controller action will return JSON using `render json:`. This keeps our focus on routes, controllers, models, and the database.

When you're ready to build a frontend later, you'll just create a React app and `fetch` from these JSON endpoints. The Rails code won't change at all.

If you created any view files earlier, clean them up:

```bash
rm -rf app/views/bookmarks
```

The `app/views/` folder itself stays — Rails uses `app/views/layouts/` for some internal things.

---

### Naming Conventions — Why Rails Is Opinionated

Rails cares about naming. A lot. Here's the pattern:

| Route target      | Controller file           | Controller class      | Action       |
| ----------------- | ------------------------- | --------------------- | ------------ |
| `bookmarks#index` | `bookmarks_controller.rb` | `BookmarksController` | `def index`  |
| `users#show`      | `users_controller.rb`     | `UsersController`     | `def show`   |
| `tags#create`     | `tags_controller.rb`      | `TagsController`      | `def create` |

The pattern is always:

- Route uses **snake_case plural** → `bookmarks`
- File name is **snake_case** → `bookmarks_controller.rb`
- Class name is **PascalCase** → `BookmarksController`
- Action is a **method name** → `def index`

**NOTE** If you name something wrong, Rails won't find it. There's no config to override this — you follow the convention or it breaks. This is what "convention over configuration" means. Rails makes decisions for you so you don't have to wire things up manually.

---

### Essential Knowledge

1. **The request flow is always the same**: Router → Controller → Model → Response. Every feature you build follows this pattern.

2. **Errors are your friend**. Don't try to build everything at once. Define the route, see the error, fix it, see the next error. This is the normal Rails workflow.

3. **Naming is not optional**. Rails uses naming conventions to automatically connect routes to controllers, controllers to models, and models to database tables. Fight the conventions and you'll fight Rails.

4. **`render json:` skips the view layer**. By default, Rails looks for an HTML template at `app/views/{controller}/{action}.html.erb`. Using `render json:` tells it to send JSON instead.

5. **`bin/rails s`** is the shorthand for `bin/rails server`. You'll see both. They do the same thing.

---

### What's Next

Right now we have a single route that returns a hardcoded message. Next, we'll learn **Routing** properly — RESTful routes, the 7 standard actions, and how to set up full CRUD endpoints for bookmarks.
