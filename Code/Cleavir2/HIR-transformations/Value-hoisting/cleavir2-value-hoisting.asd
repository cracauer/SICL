(cl:in-package #:asdf-user)

(defsystem :cleavir2-value-hoisting
  :depends-on (:acclimation
               :cleavir2-hir
               :cleavir2-hir-transformations)
  :serial t
  :components
  ((:file "packages")
   (:file "conditions")
   (:file "condition-reporters-english")
   (:file "generic-functions")
   (:file "hoist-values")
   (:file "make-load-form-using-client")
   (:file "constructor")
   (:file "similarity-keys")
   (:file "scan")
   (:file "hoist")))
