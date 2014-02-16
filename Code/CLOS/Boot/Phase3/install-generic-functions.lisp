(cl:in-package #:sicl-clos)

(defparameter *installable-generic-functions*
  '(;; These are used by the :AFTER method on INITIALIZE-INSTANCE
    ;; specialized for STANDARD-CLASS.
    class-direct-subclasses
    (setf c-direct-subclasses)
    class-direct-superclasses
    (setf c-direct-superclasses)
    class-direct-slots
    (setf c-direct-slots)
    class-direct-default-initargs
    (setf c-direct-default-initargs)
    (setf c-precedence-list)
    direct-slots
    (setf c-slots)
    direct-default-initargs
    (setf c-default-initargs)
    (setf c-finalized-p)
    ;; These are used by the :AFTER method on INITIALIZE-INSTANCE,
    ;; specialized for STANDARD-GENERIC-FUNCTION.
    (setf gf-documentation)
    (setf gf-declarations)
    (setf gf-method-class)
    (setf specializer-profile)
    (setf gf-lambda-list)
    (setf gf-argument-precedence-order)
    (setf discriminating-function)
    ;; These are used by ADD-DIRECT-METHOD which is called by
    ;; ADD-METHOD, which is called indirectly by the :AFTER method on
    ;; INITIALIZE-INSTANCE, specialized to STANDARD-CLASS in order to
    ;; install readers and writers for slots. 
    specializer-direct-methods
    (setf s-direct-methods)
    ;; These are used directly by ADD-METHOD in order to add a method
    ;; to the methods of a generic function.
    gf-methods
    (setf gf-methods)
    ;; These are used directly by ADD-METHOD in order to store a back
    ;; pointer from the method to its generic function and to check
    ;; that the method is not currently on a generic function.
    method-generic-function
    (setf m-generic-function)
    ;; These are used by the :AFTER method on INITIALIZE-INSTANCE,
    ;; specialized for STANDARD-METHOD
    (setf method-documentation)
    ;; Generic functions for initialization
    initialize-instance
    reinitialize-instance
    shared-initialize
    initialize-built-in-instance
    add-direct-method
    ;;
    slot-definition-type
    slot-definition-initform
    (setf s-location)
    slot-definition-readers
    slot-definition-writers
    ))

(loop for name in *installable-generic-functions*
      do (setf (fdefinition name)
	       (find-bridge-generic-function name))
	 (delete-bridge-generic-function name))
