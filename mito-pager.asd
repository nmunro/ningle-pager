(defsystem "mito-pager"
  :version "1.0.0"
  :author "nmunro"
  :license "BSD3-Clause"
  :description ""
  :depends-on (:mito :sxql)
  :components ((:module "src"
                :components
                ((:file "main"))))
  :in-order-to ((test-op (test-op "mito-pager/tests"))))

(defsystem "mito-pager/tests"
  :author "nmunro"
  :license "BSD3-Clause"
  :depends-on ("mito-pager"
               :rove)
  :components ((:module "tests"
                :components
                ((:file "main"))))
  :description "Test system for pager"
  :perform (test-op (op c) (symbol-call :rove :run c)))
