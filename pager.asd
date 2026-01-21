(defsystem "pager"
  :version "0.0.1"
  :author "nmunro"
  :license "BSD3-Clause"
  :description ""
  :depends-on ()
  :components ((:module "src"
                :components
                ((:file "main"))))
  :in-order-to ((test-op (test-op "pager/tests"))))

(defsystem "pager/tests"
  :author "nmunro"
  :license "BSD3-Clause"
  :depends-on ("pager"
               :rove)
  :components ((:module "tests"
                :components
                ((:file "main"))))
  :description "Test system for pager"
  :perform (test-op (op c) (symbol-call :rove :run c)))
