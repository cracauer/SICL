(cl:in-package #:cleavir-ir)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instructions for Common Lisp operators.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction TOP-LEVEL-ENTER-INSTRUCTION.
;;;
;;; This is a subclass of ENTER-INSTRUCTION used as the initial
;;; instruction of a flowchart that represents a LOAD FUNCTION.
;;;
;;; An initial form F to be evaluated is turned into a load function
;;; LF.  When LF is called with the values of the LOAD-TIME-VALUE
;;; forms (including non-immediate constants) of F, then the result is
;;; the values and the effects of evaluating F.
;;;
;;; The TOP-LEVEL-ENTER-INSTRUCTION supplies a slot containing the
;;; list of the LOAD-TIME-VALUE forms to be evaluated before being
;;; supplied as arguments.

(defclass top-level-enter-instruction (enter-instruction)
  ((%forms :initarg :forms :accessor forms)))

(defun make-top-level-enter-instruction (lambda-list forms &key origin)
  (let ((enter (make-enter-instruction lambda-list :origin origin)))
    (change-class enter 'top-level-enter-instruction
		  :forms forms)))

(defmethod clone-initargs append ((instruction top-level-enter-instruction))
  (list :forms (forms instruction)))

(defgeneric top-level-enter-instruction-p (instruction)
  (:method ((instruction t)) nil)
  (:method ((instruction top-level-enter-instruction)) t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction NOP-INSTRUCTION.

(defclass nop-instruction (instruction one-successor-mixin)
  ())

(defun make-nop-instruction (successors)
  (make-instance 'nop-instruction
    :successors successors))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction UNREACHABLE-INSTRUCTION.

(defclass unreachable-instruction (instruction no-successors-mixin)
  ())

(defun make-unreachable-instruction ()
  (make-instance 'unreachable-instruction))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction ASSIGNMENT-INSTRUCTION.

(defclass assignment-instruction (instruction one-successor-mixin)
  ())

(defun make-assignment-instruction
    (input output &optional (successor nil successor-p))
  (make-instance 'assignment-instruction
    :inputs (list input)
    :outputs (list output)
    :successors (if successor-p (list successor) '())))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction FUNCALL-INSTRUCTION.

(defclass funcall-instruction
    (instruction one-successor-mixin side-effect-mixin)
  ())

(defun make-funcall-instruction
    (inputs outputs &optional (successor nil successor-p))
  (make-instance 'funcall-instruction
    :inputs inputs
    :outputs outputs
    :successors (if successor-p (list successor) '())))

(defgeneric funcall-instruction-p (instruction)
  (:method ((instruction t)) nil)
  (:method ((instruction funcall-instruction)) t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction FUNCALL-NO-RETURN-INSTRUCTION.
;;;
;;; This is for calls that are known to never return normally,
;;; e.g. calls to ERROR. Having no successor simplifies analysis
;;; by making whatever leads here irrelevant to other code.
;;;
;;; It's a separate class because funcall having one-successor-mixin
;;; is pretty convenient.

(defclass funcall-no-return-instruction
    (instruction no-successors-mixin side-effect-mixin)
  ())

(defun make-funcall-no-return-instruction (inputs)
  (make-instance 'funcall-no-return-instruction
    :inputs inputs))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction TAILCALL-INSTRUCTION.

(defclass tailcall-instruction (instruction no-successors-mixin)
  ())

(defun make-tailcall-instruction (inputs)
  (make-instance 'tailcall-instruction
    :inputs inputs))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction RETURN-INSTRUCTION.

(defclass return-instruction
    (instruction no-successors-mixin side-effect-mixin)
  ())

(defun make-return-instruction (inputs)
  (make-instance 'return-instruction
    :inputs inputs))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction TYPEQ-INSTRUCTION.
;;;
;;; This instruction takes one input, namely a datum for which a type
;;; should be tested.  
;;;
;;; As a result of various transformations of the instruction graph,
;;; this instruction will either be eliminated (because we can
;;; determine statically the result of the test), or it will be
;;; replaced by a call to TYPEP.  When it is replaced by a call to
;;; TYPEP, we use the constant input as the second argument to TYPEP.

(defclass typeq-instruction (instruction two-successors-mixin)
  ((%value-type :initarg :value-type :reader value-type)))

(defun make-typeq-instruction (input successors value-type)
  (make-instance 'typeq-instruction
    :inputs (list input)
    :successors successors
    :value-type value-type))

(defmethod clone-initargs append ((instruction typeq-instruction))
  (list :value-type (value-type instruction)))

(defgeneric typeq-instruction-p (instruction)
  (:method ((instruction t)) nil)
  (:method ((instruction typeq-instruction)) t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction THE-INSTRUCTION.
;;;
;;; This instruction is similar to the TYPEQ-INSTRUCTION.  It is
;;; different in that it has only a single successor and no error
;;; branch.  Operationally, it has no effect.  But it informs the type
;;; inference machinery that the input is of a particular type. 

(defclass the-instruction (instruction one-successor-mixin)
  ((%value-type :initarg :value-type :reader value-type)))

(defun make-the-instruction (input successor value-type)
  (make-instance 'the-instruction
    :inputs (list input)
    :outputs '()
    :successors (list successor)
    :value-type value-type))

(defmethod clone-initargs append ((instruction the-instruction))
  (list :value-type (value-type instruction)))

(defgeneric the-instruction-p (instruction)
  (:method ((instruction t)) nil)
  (:method ((instruction the-instruction)) t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction DYNAMIC-ALLOCATION-INSTRUCTION.
;;;
;;; This instruction has no operational effect, like THE.
;;; It informs the escape analysis machinery that values in its
;;; input will not escape the function that owns the instruction.
;;; In other words, values input to this instruction
;;; can be allocated in the local function's stack frame.

(defclass dynamic-allocation-instruction
    (instruction one-successor-mixin)
  ())

(defun make-dynamic-allocation-instruction (input successor)
  (make-instance 'dynamic-allocation-instruction
    :inputs (list input)
    :outputs nil
    :successors (list successor)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction CATCH-INSTRUCTION.
;;;
;;; This instruction is used to mark a control point and stack frame
;;; as an exit point. It has no inputs, one output, and two successors.
;;; When reached normally, the instruction outputs a "continuation",
;;; pushes it onto the (implicit) dynamic environment in whatever
;;; client-defined way, and then proceeds to its first successor.
;;; If the continuation is used as input to an UNWIND-INSTRUCTION,
;;; control proceeds to the CATCH's second successor.
;;;
;;; The continuation can only be used, and cannot be used after the
;;; function containing the CATCH has returned or been unwound from.
;;; In Scheme terms, it is a one-shot escape continuation.
;;;
;;; This instruction can be used to implement the Common Lisp BLOCK
;;; and/or TAGBODY special operators, among other possible nonlocal
;;; exit constructors. A BLOCK would be compiled into a CATCH with
;;; the block body as first successor, and return point as second.
;;; Functions returning to the BLOCK would UNWIND to the CATCH, using
;;; a closed-over continuation.

(defclass catch-instruction (instruction two-successors-mixin)
  ())

(defun make-catch-instruction (output successors)
  (make-instance 'catch-instruction
    :outputs (list output)
    :successors successors))

(defgeneric catch-instruction-p (instruction)
  (:method ((instruction t)) nil)
  (:method ((instruction catch-instruction)) t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction UNWIND-INSTRUCTION.
;;;
;;; This instruction is used to indicate a lexical non-local transfer
;;; of control resulting from a GO or a RETURN-FROM form.
;;;
;;; The process of unwinding may involve dynamically determined side
;;; effects due to UNWIND-PROTECT.
;;;
;;; The instruction has one input, which is the continuation output by a
;;; CATCH-INSTRUCTION. See its comment for details.

(defclass unwind-instruction
    (instruction no-successors-mixin side-effect-mixin)
  (;; The destination of the UNWIND-INSTRUCTION is the
   ;; CATCH-INSTRUCTION to which it will eventually transfer control.
   ;; It is not a normal successor because the exit is non-local.
   (%destination :initarg :destination :accessor destination)))

(defun make-unwind-instruction (input destination)
  (make-instance 'unwind-instruction
    :inputs (list input)
    :destination destination))

(defmethod clone-initargs append ((instruction unwind-instruction))
  (list :destination (destination instruction)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction EQ-INSTRUCTION.

(defclass eq-instruction (instruction two-successors-mixin)
  ())

(defun make-eq-instruction (inputs successors)
  (make-instance 'eq-instruction
    :inputs inputs
    :successors successors))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction CONSP-INSTRUCTION.
;;;
;;; This instruction is used to test whether its input is a CONS cell.
;;; If that is the case, then the first output is chosen.  Otherwise,
;;; the second output is chosen.

(defclass consp-instruction (instruction two-successors-mixin)
  ())

(defun make-consp-instruction (input successors)
  (make-instance 'consp-instruction
    :inputs (list input)
    :successors successors))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction FIXNUMP-INSTRUCTION.
;;;
;;; This instruction is used to test whether its input is a FIXNUM.
;;; If that is the case, then the first output is chosen.  Otherwise,
;;; the second output is chosen.

(defclass fixnump-instruction (instruction two-successors-mixin)
  ())

(defun make-fixnump-instruction (input successors)
  (make-instance 'fixnump-instruction
    :inputs (list input)
    :successors successors))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction CHARACTERP-INSTRUCTION.
;;;
;;; This instruction is used to test whether its input is a CHARACTER.
;;; If that is the case, then the first output is chosen.  Otherwise,
;;; the second output is chosen.

(defclass characterp-instruction (instruction two-successors-mixin)
  ())

(defun make-characterp-instruction (input successors)
  (make-instance 'characterp-instruction
    :inputs (list input)
    :successors successors))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction SYMBOL-VALUE-INSTRUCTION.

(defclass symbol-value-instruction (instruction one-successor-mixin)
  ())

(defun make-symbol-value-instruction (input output successor)
  (make-instance 'symbol-value-instruction
    :inputs (list input)
    :outputs (list output)
    :successors (list successor)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction SET-SYMBOL-VALUE-INSTRUCTION.

(defclass set-symbol-value-instruction
    (instruction one-successor-mixin side-effect-mixin)
  ())

(defun make-set-symbol-value-instruction (symbol-input value-input successor)
  (make-instance 'set-symbol-value-instruction
    :inputs (list symbol-input value-input)
    :outputs '()
    :successors (list successor)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction FDEFINITION-INSTRUCTION.

(defclass fdefinition-instruction (instruction one-successor-mixin)
  ())

(defun make-fdefinition-instruction
    (input output &optional (successor nil successor-p))
  (make-instance 'fdefinition-instruction
    :inputs (list input)
    :outputs (list output)
    :successors (if successor-p (list successor) '())))

(defgeneric fdefinition-instruction-p (instruction)
  (:method ((instruction t)) nil)
  (:method ((instruction fdefinition-instruction)) t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction PHI-INSTRUCTION.
;;; 
;;; This is an instruction used in SSA form.  It has at least two
;;; inputs, a single output and a single successor.
;;;
;;; Let A be some PHI-INSTRUCTION with N inputs.  A can have one or
;;; more predecessors.  If A has a single predecessor B, then B is
;;; also a PHI-INSTRUCTION with N inputs.  If A has more than one
;;; predecessor, then it has N predecessors.

(defclass phi-instruction (instruction one-successor-mixin)
  ())

(defun make-phi-instruction (inputs output successor)
  (make-instance 'phi-instruction
    :inputs inputs
    :outputs (list output)
    :successors (list successor)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction USE-INSTRUCTION.
;;;
;;; This instruction is similar to the NOP-INSTRUCTION in that it does
;;; nothing.  The difference is that this instruction takes a single
;;; input, is a lexical variable.  The purpose is to create an
;;; artificial use for the input so that it will be kept alive until
;;; after this instruction is encountered.  An instance of this
;;; instruction class will typically be emitted when the DEBUG quality
;;; has a high value and a SCOPE-AST is encountered.

(defclass use-instruction (instruction one-successor-mixin)
  ())

(defun make-use-instruction (input successor)
  (make-instance 'use-instruction
    :inputs (list input)
    :outputs '()
    :successors (list successor)))
