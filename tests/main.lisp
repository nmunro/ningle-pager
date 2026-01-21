(defpackage pager/tests/main
  (:use :cl
        :pager
        :rove))
(in-package :pager/tests/main)

;; NOTE: To run this test file, execute `(asdf:test-system :pager)` in your Lisp.

(deftest test-target-1
  (testing "should (= 1 1) to be true"
  (format t "Testing~%")
    (ok (= 1 1))))
