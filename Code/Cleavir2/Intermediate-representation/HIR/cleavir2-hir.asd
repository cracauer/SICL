(cl:in-package #:asdf-user)

(defsystem :cleavir2-hir
  :depends-on (:cleavir2-ir)
  :serial t
  :components
  ((:file "data")
   (:file "general-purpose-instructions")
   (:file "box-related-instructions")
   (:file "fixnum-related-instructions")
   (:file "simple-float-related-instructions")
   (:file "cons-related-instructions")
   (:file "standard-object-related-instructions")
   (:file "array-related-instructions")
   (:file "multiple-value-related-instructions")
   (:file "environment-related-instructions")
   (:file "argument-parsing-related-instructions")))
