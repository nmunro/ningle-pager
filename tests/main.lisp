(defpackage mito-pager/tests/main
  (:use :cl
        :mito-pager
        :rove))
(in-package :mito-pager/tests/main)

;; NOTE: To run this test file, execute `(asdf:test-system :mito-pager)` in your Lisp.

(deftest test-with-pager-basic
  (testing "with-pager basic usage with page 1"
    (let ((fetch-called nil)
          (count-called nil))
      (with-pager ((items pager)
                   :fetch-fn (lambda (limit offset)
                               (setf fetch-called (list limit offset))
                               '(item1 item2 item3))
                   :count-fn (lambda ()
                               (setf count-called t)
                               10)
                   :page 1
                   :limit 3)
        ;; Verify fetch-fn was called with correct args
        (ok (equal fetch-called '(3 0)) "fetch-fn called with limit=3, offset=0")
        ;; Verify count-fn was called
        (ok count-called "count-fn was called")
        ;; Verify items binding
        (ok (equal items '(item1 item2 item3)) "items bound correctly")
        ;; Verify pager metadata
        (ok (= (getf pager :page) 1) "current page is 1")
        (ok (= (getf pager :count) 10) "total count is 10")
        (ok (= (getf pager :limit) 3) "limit is 3")
        (ok (= (getf pager :page-count) 4) "page count is 4 (10/3 rounded up)")
        (ok (= (getf pager :offset) 0) "offset is 0")))))

(deftest test-with-pager-page-2
  (testing "with-pager with page 2"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset)
                             (ok (= limit 5) "limit is 5")
                             (ok (= offset 5) "offset is 5 (page 2)")
                             '(item6 item7 item8 item9 item10))
                 :count-fn (lambda () 20)
                 :page 2
                 :limit 5)
      (ok (= (getf pager :page) 2) "current page is 2")
      (ok (= (getf pager :offset) 5) "offset is 5")
      (ok (= (getf pager :start-index) 6) "start index is 6")
      (ok (= (getf pager :end-index) 10) "end index is 10"))))

(deftest test-with-pager-last-page
  (testing "with-pager with last page (partial results)"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset)
                             (ok (= limit 10) "limit is 10")
                             (ok (= offset 20) "offset is 20 (page 3)")
                             '(item21 item22))
                 :count-fn (lambda () 22)
                 :page 3
                 :limit 10)
      (ok (= (getf pager :page) 3) "current page is 3")
      (ok (= (getf pager :page-count) 3) "total pages is 3")
      (ok (= (getf pager :start-index) 21) "start index is 21")
      (ok (= (getf pager :end-index) 22) "end index is 22")
      (ok (null (getf pager :next-page)) "no next page")
      (ok (= (getf pager :prev-page) 2) "previous page is 2"))))

(deftest test-with-pager-boundary-correction
  (testing "with-pager corrects out-of-bounds page to last page"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset)
                             ;; Should be called with offset for last page
                             (ok (= offset 20) "offset corrected to last page (20)")
                             '(item21))
                 :count-fn (lambda () 21)
                 :page 999  ; Request page way out of bounds
                 :limit 10)
      ;; Should correct to page 3 (last page)
      (ok (= (getf pager :page) 3) "page corrected to 3 (last page)")
      (ok (= (getf pager :page-count) 3) "total pages is 3"))))

(deftest test-with-pager-empty-results
  (testing "with-pager with zero count"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset)
                             (ok (= limit 10) "limit is 10")
                             (ok (= offset 0) "offset is 0")
                             '())
                 :count-fn (lambda () 0)
                 :page 1
                 :limit 10)
      (ok (null items) "items is empty")
      (ok (= (getf pager :count) 0) "count is 0")
      (ok (= (getf pager :page) 1) "page is 1")
      (ok (= (getf pager :page-count) 1) "page count is 1 (minimum)")
      (ok (= (getf pager :start-index) 0) "start index is 0 for empty results")
      (ok (= (getf pager :end-index) 0) "end index is 0 for empty results"))))

(deftest test-with-pager-input-validation
  (testing "with-pager validates and corrects negative/zero page"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset)
                             (ok (= offset 0) "offset is 0 (corrected from page 0)")
                             '(item1))
                 :count-fn (lambda () 5)
                 :page 0  ; Invalid page
                 :limit 5)
      (ok (= (getf pager :page) 1) "page corrected to 1")))

  (testing "with-pager validates and corrects negative/zero limit"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset)
                             (ok (= limit 1) "limit corrected to 1")
                             '(item1))
                 :count-fn (lambda () 5)
                 :page 1
                 :limit 0)  ; Invalid limit
      (ok (= (getf pager :limit) 1) "limit corrected to 1"))))

(deftest test-with-pager-nil-values
  (testing "with-pager handles nil page and limit"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset)
                             (ok (= limit 1) "nil limit defaults to 1")
                             (ok (= offset 0) "nil page defaults to 1 (offset 0)")
                             '(item1))
                 :count-fn (lambda () 5)
                 :page nil
                 :limit nil)
      (ok (= (getf pager :page) 1) "nil page defaults to 1")
      (ok (= (getf pager :limit) 1) "nil limit defaults to 1"))))

(deftest test-with-pager-window
  (testing "with-pager default window of 2"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset) '(item1))
                 :count-fn (lambda () 100)
                 :page 5
                 :limit 10)
      (ok (equal (getf pager :pages) '(3 4 5 6 7)) "window of 2 around page 5")))

  (testing "with-pager custom window"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset) '(item1))
                 :count-fn (lambda () 100)
                 :page 5
                 :limit 10
                 :window 1)
      (ok (equal (getf pager :pages) '(4 5 6)) "window of 1 around page 5"))))

(deftest test-with-pager-gaps
  (testing "with-pager shows start/end gaps correctly"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset) '(item1))
                 :count-fn (lambda () 100)
                 :page 50
                 :limit 1
                 :window 2)
      (ok (getf pager :show-start-gap) "shows start gap when far from beginning")
      (ok (getf pager :show-end-gap) "shows end gap when far from end")))

  (testing "with-pager no gaps at beginning"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset) '(item1))
                 :count-fn (lambda () 100)
                 :page 2
                 :limit 10
                 :window 2)
      (ok (not (getf pager :show-start-gap)) "no start gap near beginning")))

  (testing "with-pager no gaps at end"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset) '(item1))
                 :count-fn (lambda () 100)
                 :page 9
                 :limit 10
                 :window 2)
      (ok (not (getf pager :show-end-gap)) "no end gap near end"))))

(deftest test-with-pager-prev-next
  (testing "with-pager prev/next on first page"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset) '(item1))
                 :count-fn (lambda () 30)
                 :page 1
                 :limit 10)
      (ok (null (getf pager :prev-page)) "no previous page on page 1")
      (ok (= (getf pager :next-page) 2) "next page is 2")))

  (testing "with-pager prev/next on middle page"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset) '(item1))
                 :count-fn (lambda () 30)
                 :page 2
                 :limit 10)
      (ok (= (getf pager :prev-page) 1) "previous page is 1")
      (ok (= (getf pager :next-page) 3) "next page is 3")))

  (testing "with-pager prev/next on last page"
    (with-pager ((items pager)
                 :fetch-fn (lambda (limit offset) '(item1))
                 :count-fn (lambda () 30)
                 :page 3
                 :limit 10)
      (ok (= (getf pager :prev-page) 2) "previous page is 2")
      (ok (null (getf pager :next-page)) "no next page on last page"))))

(deftest test-with-pager-single-call
  (testing "fetch-fn and count-fn called exactly once"
    (let ((fetch-count 0)
          (count-count 0))
      (with-pager ((items pager)
                   :fetch-fn (lambda (limit offset)
                               (incf fetch-count)
                               '(item1 item2))
                   :count-fn (lambda ()
                               (incf count-count)
                               10)
                   :page 1
                   :limit 5)
        (ok (= fetch-count 1) "fetch-fn called exactly once")
        (ok (= count-count 1) "count-fn called exactly once")))))
