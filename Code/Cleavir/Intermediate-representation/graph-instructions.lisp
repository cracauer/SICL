(in-package #:cleavir-ir)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instructions core to the understanding of graph traversal.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction ENTER-INSTRUCTION.
;;;
;;; This instruction encapsulates all the implementation-specific
;;; machinery involved in verifying the argument count and parsing the
;;; arguments.  It has a single successor.

(defclass enter-instruction (instruction one-successor-mixin)
  ((%lambda-list :initarg :lambda-list :accessor lambda-list)
   ;; The number of closure cells this function has.
   ;; Used internally, but shouldn't matter to code generation.
   (%closure-size :initarg :closure-size :accessor closure-size
                  :initform 0 :type (integer 0))))

(defgeneric static-environment (instruction))
(defmethod static-environment ((instruction enter-instruction))
  (first (outputs instruction)))

(defgeneric parameters (instruction))
(defmethod parameters ((instruction enter-instruction))
  (rest (outputs instruction)))

(defun make-enter-instruction
    (lambda-list &key (successor nil successor-p) origin)
  (let* ((outputs (loop for item in lambda-list
                        append (cond ((member item lambda-list-keywords) '())
                                     ((consp item)
                                      (if (= (length item) 3)
                                          (cdr item)
                                          item))
                                     (t (list item))))))
    (make-instance 'enter-instruction
      :lambda-list lambda-list
      ;; We add an additional output that will hold the static
      ;; environment.
      :outputs (cons (new-temporary) outputs)
      :successors (if successor-p (list successor) '())
      :origin origin)))

(defmethod clone-initargs append ((instruction enter-instruction))
  (list :lambda-list (lambda-list instruction)
        :closure-size (closure-size instruction)))

;;; Maintain consistency of lambda list with outputs.
(defmethod substitute-output :after (new old (instruction enter-instruction))
  (setf (lambda-list instruction)
        (subst new old (lambda-list instruction) :test #'eq)))

(defmethod (setf outputs) :before (new-outputs (instruction enter-instruction))
  (let ((old-lambda-outputs (rest (outputs instruction)))
        (new-lambda-outputs (rest new-outputs)))
    ;; FIXME: Not sure what to do if the new and old outputs are different lengths.
    ;; For now we're silent.
    (setf (lambda-list instruction)
          (sublis (mapcar #'cons old-lambda-outputs new-lambda-outputs)
                  (lambda-list instruction)
                  :test #'eq))))

(defgeneric enter-instruction-p (instruction)
  (:method ((instruction t)) nil)
  (:method ((instruction enter-instruction)) t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction ENCLOSE-INSTRUCTION.

(defclass enclose-instruction (instruction one-successor-mixin
                               allocation-mixin)
  ((%code :initarg :code :accessor code)))  

(defun make-enclose-instruction (output successor code)
  (make-instance 'enclose-instruction
    :outputs (list output)
    :successors (list successor)
    :code code))

(defmethod clone-initargs append ((instruction enclose-instruction))
  (list :code (code instruction)))

(defgeneric enclose-instruction-p (instruction)
  (:method ((instruction t)) nil)
  (:method ((instruction enclose-instruction)) t))
