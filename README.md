# Pager v0.0.3

Small Common Lisp pagination helper for computing page ranges and metadata.

## Features

- Clamp inputs safely (count, page, limit, window).
- Compute page offsets, start/end indices, and prev/next pages.
- Generate page ranges with gap flags for UI rendering.
- Macro helper to fetch paged data with auto-corrected page bounds.
- Templates that can be overridden with [Djula](https://github.com/mmontone/djula).

## Install

Add to your local project via ASDF/Quicklisp and load the system:

```lisp
(ql:quickload :pager)
```

## Configuration

### Djula template note

If you are using Djula, add `pager` to your Djula search paths so the pager partial can be resolved.

```lisp
(djula:add-template-directory
    (asdf:system-relative-pathname :pager "src/templates/"))
```

## Usage

### Quick Start: `paginate-dao`

The simplest way to paginate Mito models:

```lisp
;; Simple pagination
(multiple-value-bind (posts pager)
    (mito-pager:paginate-dao 'post page :limit 10)
  (render-template "posts.html" :posts posts :pager pager))

;; With ordering
(mito-pager:paginate-dao 'post page
  :limit 10
  :order-by '(:desc :created-at))

;; With filtering
(mito-pager:paginate-dao 'post page
  :limit 20
  :where '(:= :published t)
  :order-by '(:desc :published-at))
```

**Complete controller example:**

```lisp
(setf (ningle:route app "/posts" :method :get)
  (lambda (params)
    (let ((page (parse-integer (or (gethash "page" params) "1"))))
      (multiple-value-bind (posts pager)
          (mito-pager:paginate-dao 'post page :limit 10 :order-by '(:desc :created-at))
        (render-template "posts.html"
                        :posts posts
                        :pager pager)))))
```

For complex queries with joins, use `with-pager` (see below).

---

### Low-Level API

### `make-pager`

A low level function to perform the pagination math and construct a pager object.

```lisp
(mito-pager:make-pager 123 5 10 :window 2)
;; =>
;; (:count 123
;;  :page 5
;;  :limit 10
;;  :page-count 13
;;  :offset 40
;;  :start-index 41
;;  :end-index 50
;;  :prev-page 4
;;  :next-page 6
;;  :pages (3 4 5 6 7)
;;  :show-start-gap t
;;  :show-end-gap t)
```

Key fields:

- `:count` total items.
- `:page` current page (clamped to valid range).
- `:limit` items per page (min 1).
- `:page-count` total pages (min 1).
- `:offset` zero-based start offset.
- `:start-index` one-based start index (0 when count is 0).
- `:end-index` one-based end index.
- `:prev-page` or `nil` if on the first page.
- `:next-page` or `nil` if on the last page.
- `:pages` list of pages centered on current page within `:window`.
- `:show-start-gap` whether to show an ellipsis between page 1 and `:pages`.
- `:show-end-gap` whether to show an ellipsis between `:pages` and last page.

### `with-pager`

A macro for easy pagination with automatic validation and boundary handling.

Use `with-pager` with separate fetch and count functions. The library handles all the complexity:
- Input validation (page >= 1, limit >= 1)
- Count caching (count-fn called exactly once)
- Boundary checking (if page exceeds total, corrects to last page)
- Offset calculation

```lisp
(mito-pager:with-pager ((items pager)
                   :fetch-fn (lambda (limit offset)
                               (fetch-items limit offset))
                   :count-fn (lambda ()
                               (fetch-count))
                   requested-page
                   requested-limit
                   :window 2)
  (render-page items pager))
```

**Parameters:**
- `fetch-fn`: Function that accepts `(limit offset)` and returns a list of items
- `count-fn`: Function that returns the total count (called once, result cached)
- `page`: Requested page number (1-indexed)
- `limit`: Items per page
- `window`: (optional, default 2) Number of pages to show before/after current

**Example with Ningle/Mito:**

```lisp
(setf (ningle:route app "/posts" :method :get)
  (lambda (params)
    (let ((page (parse-integer (or (gethash "page" params) "1")))
          (limit (parse-integer (or (gethash "limit" params) "10"))))
      (mito-pager:with-pager ((posts pager)
                         :fetch-fn (lambda (limit offset)
                                     (mito:select-dao 'post
                                       (sxql:order-by (:desc :created-at))
                                       (sxql:limit limit)
                                       (sxql:offset offset)))
                         :count-fn (lambda ()
                                     (mito:count-dao 'post))
                         page
                         limit)
        (render-template "posts.html"
                        :posts posts
                        :pager pager)))))

Finally, add the included partial to your templates:

```html
{% include "mito-pager/partials/pager.html" %}
```

## Tests

Run tests with:

```lisp
(asdf:test-system :mito-pager)
```

## License

BSD-3-Clause
