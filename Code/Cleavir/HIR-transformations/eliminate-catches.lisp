(in-package #:cleavir-hir-transformations)

;;;; Eliminates CATCH-INSTRUCTIONS with unused continuations.
;;;; Because they have multiple successors, this is not suitable
;;;; for inclusion in the general remove-useless-instructions.

(defun eliminate-catches (initial-instruction)
  (let ((death nil))
    (cleavir-ir:map-instructions-arbitrary-order
     (lambda (instruction)
       (when (cleavir-ir:catch-instruction-p instruction)
         (let ((cont (first (cleavir-ir:outputs instruction))))
           (when (null (cleavir-ir:using-instructions cont))
             (push instruction death)))))
     initial-instruction)
    (dolist (catch death)
      (cleavir-ir:bypass-instruction (first (cleavir-ir:successors catch)) catch))
    death))
