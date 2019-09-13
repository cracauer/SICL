(cl:in-package #:cleavir-hir-transformations)

;;;; In this file we define functions for building and traversing a
;;;; FUNCTION DAG.  Such a DAG defines the nesting of functions in a
;;;; program.  A node (other than the root) of the DAG contains a slot
;;;; holding an ENCLOSE-INSTRUCTION.  Each node contains a list of
;;;; CHILDREN that are also DAG nodes.  The children of a node N
;;;; (other than the root) containing some ENCLOSE-INSTRUCTION E are
;;;; nodes that contain the ENCLOSE-INSTRUCTIONs owned by the CODE of
;;;; (i.e., the ENTER-INSTRUCTION associated with) E.  The children of
;;;; the root node are nodes containing the ENCLOSE-INSTRUCTIONs owned
;;;; by the ENTER-INSTRUCTION INITIAL-INSTRUCTION.  In addition to a
;;;; list of children, the root node also contains an EQ hash table
;;;; that maps ENTER-INSTRUCTIONs to DAG nodes such that the DAG node
;;;; is either the root, or it contains the ENCLOSE-INSTRUCTION that
;;;; the ENTER-INSTRUCTION is associated with.

(defgeneric enter-instruction (node))

(defclass dag-node ()
  ((%children :initform '() :accessor children)))

(defclass function-dag (dag-node)
  ((%initial-instruction :initarg :initial-instruction
                         :reader initial-instruction)
   (%dag-nodes :initarg :dag-nodes :reader dag-nodes)))

(defmethod enter-instruction ((node function-dag))
  (initial-instruction node))

(defclass interior-node (dag-node)
  ((%parents :initarg :parents :accessor parents)
   (%enclose-instruction :initarg :enclose-instruction
                         :reader enclose-instruction)))

(defmethod enter-instruction ((node interior-node))
  (cleavir-ir:code (enclose-instruction node)))

(defun build-function-dag (initial-instruction)
  (let* (;; Create an EQ hash table that maps ENTER-INSTRUCTIONs to
         ;; DAG nodes such that the DAG node is either the root, or
         ;; it contains the ENCLOSE-INSTRUCTION that the
         ;; ENTER-INSTRUCTION is associated with.
         (table (make-hash-table :test #'eq))
         ;; Create the root of the DAG that is ultimately going to be
         ;; returned as the value of this function.
         (root (make-instance 'function-dag
                 :dag-nodes table
                 :initial-instruction initial-instruction)))
    ;; Enter the root into the table.
    (setf (gethash initial-instruction table) (list root))
    (cleavir-ir:map-instructions-with-owner
     (lambda (instruction owner)
       (when (typep instruction 'cleavir-ir:enclose-instruction)
         (let* ((parents (gethash owner table))
                (node (make-instance 'interior-node
                        :parents parents
                        :enclose-instruction instruction)))
           (loop for parent in parents
                 do (push node (children parent)))
           (push node (gethash (cleavir-ir:code instruction) table nil)))))
     initial-instruction)
    root))
