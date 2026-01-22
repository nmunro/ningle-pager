(defpackage pager
  (:use :cl)
  (:export #:make-pager
           #:with-pager))

(in-package pager)


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

(defmacro with-pager (((items-var count-var pager-var) producer-fn page-form limit-form &key (window 2)) &body body)
  (let ((req-page     (gensym "REQ-PAGE"))
        (limitg       (gensym "LIMIT"))
        (windowg      (gensym "WINDOW"))
        (offsetg      (gensym "OFFSET"))
        (tmp-items    (gensym "ITEMS"))
        (tmp-count    (gensym "COUNT"))
        (tmp-pager    (gensym "PAGER"))
        (final-page   (gensym "FINAL-PAGE"))
        (final-offset (gensym "FINAL-OFFSET")))
    `(let* ((,req-page (max 1 (or ,page-form 1)))
            (,limitg   (max 1 (or ,limit-form 1)))
            (,windowg  (max 0 ,window))
            (,offsetg  (* (1- ,req-page) ,limitg)))
       (multiple-value-bind (,tmp-items ,tmp-count)
           (funcall ,producer-fn ,limitg ,offsetg)
         (let* ((,tmp-pager (make-pager ,tmp-count ,req-page ,limitg :window ,windowg))
                (,final-page (getf ,tmp-pager :page)))
           (if (= ,final-page ,req-page)
               (let ((,items-var ,tmp-items)
                     (,count-var ,tmp-count)
                     (,pager-var ,tmp-pager))
                 ,@body)
               (let ((,final-offset (* (1- ,final-page) ,limitg)))
                 (multiple-value-bind (,items-var ,count-var)
                     (funcall ,producer-fn ,limitg ,final-offset)
                   (let ((,pager-var (make-pager ,count-var ,final-page ,limitg :window ,windowg)))
                     ,@body)))))))))
