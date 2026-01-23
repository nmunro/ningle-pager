# Pager v0.0.1

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

### `make-pager`

A low level function to perform the pagination math and construct a pager object.

```lisp
(pager:make-pager 123 5 10 :window 2)
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

A macro to help with pagination.

Use `with-pager` to fetch items and counts while handling out-of-range pages.
The producer function must accept `(limit offset)` and return two values:
items and total count.

```lisp
(pager:with-pager ((items total pager)
                   (lambda (limit offset)
                     (values (fetch-items limit offset)
                             (fetch-count)))
                   requested-page
                   requested-limit
                   :window 2)
  (render-page items pager))
```

Finally, add the included partial to your templates:

```html
{% include "pager/partials/pager.html" %}
```

## Tests

Run tests with:

```lisp
(asdf:test-system :pager)
```

## License

BSD-3-Clause
