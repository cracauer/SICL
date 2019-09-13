(cl:in-package #:asdf-user)

(defsystem #:cleavir2-value-hoisting-test
  :depends-on (#:cleavir2-ast
               #:cleavir2-cst-to-ast
               #:cleavir2-ast-to-hir
               #:cleavir2-value-hoisting)

  :serial t
  :components
  ((:file "packages")
   (:file "client")
   (:file "hir-from-form")
   (:file "make-load-form-using-client")
   (:file "test")))
