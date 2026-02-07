(defpackage mito-pager
  (:use :cl)
  (:export #:make-pager
           #:with-pager
           #:paginate-dao))

(in-package mito-pager)


(defun make-pager (count page limit &key (window 2))
  (let* ((limit (max 1 limit))                         ;; clamp limit to min of 1
         (count (max 0 (or count 0)))                  ;; normalize nil to 0 then clamp count to a min of 0
         (window (max 0 window))                       ;; clamp window to min of 0
         (page-count (max 1 (ceiling count limit)))    ;; total pages implied by COUNT and LIMIT (min 1)
         (current-page (min (max 1 (or page 1)) page-count))  ;; requested page clamped into [1..page-count]
         (offset (* (1- current-page) limit))
         (range-start (max 1 (- current-page window)))
         (range-end (min page-count (+ current-page window))))
    (list :count count
          :page current-page
          :limit limit
          :page-count page-count
          :offset offset
          :start-index (if (> count 0) (1+ offset) 0)
          :end-index (min count (+ offset limit))
          :prev-page (and (> current-page 1) (1- current-page))
          :next-page (and (< current-page page-count) (1+ current-page))
          :pages (loop :for idx :from range-start :to range-end :collect idx)
          :show-start-gap (> range-start 2)
          :show-end-gap (< range-end (1- page-count)))))

(defmacro with-pager (((items-var pager-var)
                      &key fetch-fn page limit (window 2))
                      &body body)
  "Pagination macro where fetch function returns both items and count.

  FETCH-FN: (lambda (limit offset) ...) -> (values items count)
           Function that fetches a page of items AND returns total count.
           Must return (values items-list total-count).
           Called once or twice (if page correction needed).

  PAGE: The requested page number (1-indexed)
  LIMIT: The number of items per page
  WINDOW: (optional, default 2) Number of pages to show before/after current page

  Example:
    (with-pager ((reports pager)
                 :fetch-fn (lambda (limit offset) (my-db:fetch-reports :limit limit :offset offset))
                 :page page
                 :limit 10)
      (render-template :reports reports :pager pager))

  BODY is executed with ITEMS-VAR bound to the fetched items and PAGER-VAR
  bound to a property list containing pagination metadata."
  (let ((req-page     (gensym "REQ-PAGE"))
        (limitg       (gensym "LIMIT"))
        (windowg      (gensym "WINDOW"))
        (total-count  (gensym "TOTAL-COUNT"))
        (tmp-pager    (gensym "TMP-PAGER"))
        (final-page   (gensym "FINAL-PAGE"))
        (final-offset (gensym "FINAL-OFFSET"))
        (fetch-result (gensym "FETCH-RESULT")))
    `(let* ((,req-page (max 1 (or ,page 1)))
            (,limitg   (max 1 (or ,limit 1)))
            (,windowg  (max 0 ,window)))
       ;; First call fetch-fn to get initial count
       (multiple-value-bind (,fetch-result ,total-count)
           (funcall ,fetch-fn ,limitg (* (1- ,req-page) ,limitg))
         ;; Create pager and check if page needs correction
         (let* ((,tmp-pager (make-pager ,total-count ,req-page ,limitg :window ,windowg))
                (,final-page (getf ,tmp-pager :page))
                (,final-offset (getf ,tmp-pager :offset)))
           ;; If page was corrected, re-fetch with correct offset
           (multiple-value-bind (,items-var final-count)
               (if (= ,final-page ,req-page)
                   (values ,fetch-result ,total-count)
                   (funcall ,fetch-fn ,limitg ,final-offset))
             (declare (ignore final-count))
             (let ((,pager-var ,tmp-pager))
               ,@body)))))))

(defmacro paginate-dao (model-class page &key (limit 50) (window 2) order-by where)
  "Convenience macro for paginating Mito DAOs with automatic count and fetch.

  This is a high-level wrapper around WITH-PAGER for the common case of
  paginating a single Mito DAO without complex joins or custom logic.

  PARAMETERS:
    MODEL-CLASS: The Mito model class to paginate (quoted symbol, e.g., 'post)
    PAGE: The requested page number (1-indexed)
    LIMIT: (optional, default 50) Number of items per page
    WINDOW: (optional, default 2) Number of pages to show before/after current
    ORDER-BY: (optional) SXQL order-by clause(s)
              Single: '(:desc :created-at)
              Multiple: '((:desc :created-at) (:asc :title))
    WHERE: (optional) SXQL where clause, e.g., '(:= :published t)

  RETURNS: Two values via VALUES:
    1. ITEMS - List of model instances for the current page
    2. PAGER - Property list with pagination metadata

  EXAMPLES:

    Simple pagination:
      (paginate-dao 'post page :limit 10)

    With ordering:
      (paginate-dao 'post page
        :limit 10
        :order-by '(:desc :created-at))

    With filtering:
      (paginate-dao 'post page
        :limit 10
        :where '(:= :published t)
        :order-by '(:desc :created-at))

    In a controller:
      (defun index (params)
        (multiple-value-bind (posts pager)
            (paginate-dao 'post (parse-integer (gethash \"page\" params))
              :limit 20
              :where '(:= :published t)
              :order-by '(:desc :published-at))
          (render-template \"posts.html\" :posts posts :pager pager)))

  For complex queries with joins or subqueries, use WITH-PAGER directly."
  (let ((limit-var (gensym "LIMIT"))
        (offset-var (gensym "OFFSET")))
    `(with-pager ((items pager)
                  :fetch-fn (lambda (,limit-var ,offset-var)
                              (mito:select-dao ,model-class
                                ,@(when where
                                    `((sxql:where ,where)))
                                ,@(when order-by
                                    (if (and (listp order-by)
                                             (every #'listp order-by))
                                        ;; Multiple order-by clauses: ((:desc :created-at) (:asc :title))
                                        (mapcar (lambda (clause)
                                                  `(sxql:order-by ,clause))
                                                order-by)
                                        ;; Single order-by clause: (:desc :created-at)
                                        `((sxql:order-by ,order-by))))
                                (sxql:limit ,limit-var)
                                (sxql:offset ,offset-var)))
                  :count-fn (lambda ()
                              (mito:count-dao ,model-class
                                ,@(when where
                                    `(:where ,where))))
                  :page ,page
                  :limit ,limit
                  :window ,window)
       (values items pager))))
