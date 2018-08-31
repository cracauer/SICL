(cl:in-package #:sicl-new-boot-phase-3)

(defclass environment (sicl-minimal-extrinsic-environment:environment)
  ())

(defclass header (closer-mop:funcallable-standard-object)
  ((%class :initarg :class)
   (%rack :initarg :rack))
  (:metaclass closer-mop:funcallable-standard-class))

(defun activate-class-finalization (boot)
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e2 sicl-new-boot:e2)) boot
    (setf (sicl-genv:special-variable
           'sicl-clos::*standard-direct-slot-definition* e2 t)
          (sicl-genv:find-class 'sicl-clos:standard-direct-slot-definition e1))
    (setf (sicl-genv:special-variable
           'sicl-clos::*standard-effective-slot-definition* e2 t)
          (sicl-genv:find-class 'sicl-clos:standard-effective-slot-definition e1))
    (sicl-genv:fmakunbound 'sicl-clos:direct-slot-definition-class e2)
    (import-functions-from-host
     '(find reverse last remove-duplicates reduce
       mapcar union find-if-not eql count)
     e2)
    (load-file "CLOS/slot-definition-class-support.lisp" e2)
    (load-file "CLOS/slot-definition-class-defgenerics.lisp" e2)
    (load-file "CLOS/slot-definition-class-defmethods.lisp" e2)
    (load-file "CLOS/class-finalization-defgenerics.lisp" e2)
    (load-file "CLOS/class-finalization-support.lisp" e2)
    (load-file "CLOS/class-finalization-defmethods.lisp" e2)))

(defun finalize-all-classes (boot)
  (format *trace-output* "Finalizing all classes.~%")
  (let* ((e2 (sicl-new-boot:e2 boot))
         (finalization-function
           (sicl-genv:fdefinition 'sicl-clos:finalize-inheritance e2)))
    (do-all-symbols (var)
      (let ((class (sicl-genv:find-class var e2)))
        (unless (null class)
          (funcall finalization-function class)))))
  (format *trace-output* "Done finalizing all classes.~%"))

(defun activate-allocate-instance (boot)
  (with-accessors ((e2 sicl-new-boot:e2)) boot
    (setf (sicl-genv:fdefinition 'sicl-clos::allocate-general-instance e2)
          (lambda (class size)
            (make-instance 'header
              :class class
              :rack (let ((a (make-array size)))
                      (loop for i from 0 below size
                            do (setf (aref a i) (+ i 1000)))
                      a))))
    (setf (sicl-genv:fdefinition 'sicl-clos::general-instance-access e2)
          (lambda (object location)
            (aref (slot-value object '%rack) location)))
    (setf (sicl-genv:fdefinition '(setf sicl-clos::general-instance-access) e2)
          (lambda (value object location)
            (setf (aref (slot-value object '%rack) location) value)))
    (import-functions-from-host
     '((setf sicl-genv:constant-variable) sort assoc list* every
       mapc 1+ 1- subseq butlast position identity nthcdr equal
       remove-if-not)
     e2)
    (load-file "CLOS/class-unique-number-offset-defconstant.lisp" e2)
    (load-file "CLOS/allocate-instance-defgenerics.lisp" e2)
    (load-file "CLOS/allocate-instance-support.lisp" e2)
    (load-file "CLOS/allocate-instance-defmethods.lisp" e2)))

(defun satiate-all-functions (e1 e2 e3)
  (format *trace-output* "Satiating all functions.~%")
  (do-all-symbols (var)
    (when (and (sicl-genv:fboundp var e3)
               (eq (class-of (sicl-genv:fdefinition var e3))
                   (sicl-genv:find-class 'standard-generic-function e1)))
      (funcall (sicl-genv:fdefinition
                'sicl-clos::compute-and-set-specializer-profile e2)
               (sicl-genv:fdefinition var e3)
               (sicl-genv:find-class 't e2))
      (funcall (sicl-genv:fdefinition 'sicl-clos::satiate-generic-function e2)
               (sicl-genv:fdefinition var e3)))
    (when (and (sicl-genv:fboundp `(setf ,var) e3)
               (eq (class-of (sicl-genv:fdefinition `(setf ,var) e3))
                   (sicl-genv:find-class 'standard-generic-function e1)))
      (funcall (sicl-genv:fdefinition
                'sicl-clos::compute-and-set-specializer-profile e2)
               (sicl-genv:fdefinition `(setf ,var) e3)
               (sicl-genv:find-class 't e2))
      (funcall (sicl-genv:fdefinition 'sicl-clos::satiate-generic-function e2)
               (sicl-genv:fdefinition `(setf ,var) e3))))
  (format *trace-output* "Done satiating all functions.~%"))

(defun activate-generic-function-invocation (boot)
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)) boot
    (sicl-minimal-extrinsic-environment:import-package-from-host
     'sicl-conditions e2)
    (load-file "Conditions/assert-defmacro.lisp" e2)
    (load-file "CLOS/discriminating-automaton.lisp" e2)
    (load-file-protected "CLOS/discriminating-tagbody.lisp" e2)
    (setf (sicl-genv:fdefinition 'sicl-clos::general-instance-p e2)
          (lambda (object)
            (typep object 'standard-object)))
    (setf (sicl-genv:fdefinition 'typep e2)
          (lambda (object type-specifier)
            (sicl-genv:typep object type-specifier e2)))
    (load-file "CLOS/classp-defgeneric.lisp" e2)
    (load-file "CLOS/classp-defmethods.lisp" e2)
    (setf (sicl-genv:fdefinition 'class-of e2)
          #'class-of)
    (setf (sicl-genv:fdefinition 'find-class e2)
          (lambda (name)
            (sicl-genv:find-class name e1)))
    (setf (sicl-genv:fdefinition 'sicl-clos:set-funcallable-instance-function e2)
          #'closer-mop:set-funcallable-instance-function)
    (load-file-protected "CLOS/list-utilities.lisp" e2)
    (load-file "CLOS/compute-applicable-methods-support.lisp" e2)
    (load-file "CLOS/compute-applicable-methods-defgenerics.lisp" e2)
    (load-file "CLOS/compute-applicable-methods-defmethods.lisp" e2)
    (load-file "CLOS/compute-effective-method-defgenerics.lisp" e2)
    (load-file "CLOS/compute-effective-method-support.lisp" e2)
    (load-file "CLOS/compute-effective-method-support-b.lisp" e2)
    (define-error-function
        'sicl-clos::method-combination-compute-effective-method e2)
    (load-file "CLOS/method-combination-compute-effective-method-support.lisp" e2)
    (load-file "CLOS/method-combination-compute-effective-method-defuns.lisp" e2)
    (load-file "CLOS/compute-effective-method-defmethods.lisp" e2)
    (load-file "CLOS/no-applicable-method-defgenerics.lisp" e2)
    (load-file "CLOS/no-applicable-method.lisp" e2)
    (import-functions-from-host '(zerop nth intersection make-list) e2)
    (load-file "CLOS/compute-discriminating-function-defgenerics.lisp" e2)
    (load-file "CLOS/compute-discriminating-function-support.lisp" e2)
    (load-file "CLOS/compute-discriminating-function-support-b.lisp" e2)
    (load-file "CLOS/compute-discriminating-function-defmethods.lisp" e2)
    (load-file-protected "CLOS/satiation.lisp" e2)
    (import-functions-from-host '(format print-object) e2)
    (load-file "New-boot/Phase-3/define-methods-on-print-object.lisp" e2)
    (load-file "New-boot/Phase-3/compute-and-set-specialier-profile.lisp" e2)
    (load-file "CLOS/standard-instance-access.lisp" e2)))

;;; The specializers of the generic functions in E3 are the classes of
;;; the instances in E3, so they are the classes in E2.
(defun define-make-specializer (e2 e3)
  (setf (sicl-genv:fdefinition 'sicl-clos::make-specializer e3)
        (lambda (specializer environment)
          (declare (ignore environment))
          (cond ((symbolp specializer)
                 (sicl-genv:find-class specializer e2))
                (t
                 specializer)))))

(defun define-add-method-in-e3 (boot)
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)) boot
    (let* ((name 'sicl-clos:generic-function-methods)
           (getter (sicl-genv:fdefinition name e2))
           (setter (sicl-genv:fdefinition `(setf ,name) e2)))
      (setf (sicl-genv:fdefinition 'add-method e3)
            (lambda (generic-function method)
              (funcall setter
                       (cons method (funcall getter generic-function))
                       generic-function))))))

(defun activate-defmethod-in-e3 (boot)
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)) boot
    (load-file "CLOS/make-method-lambda-support.lisp" e3)
    (load-file "CLOS/make-method-lambda-defuns.lisp" e3)
    (define-make-specializer e2 e3)
    (define-add-method-in-e3 boot)))

(defun boot-phase-3 (boot)
  (format *trace-output* "Start of phase 3~%")
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)) boot
    (change-class e3 'environment)
    (activate-class-finalization boot)
    (finalize-all-classes boot)
    (activate-allocate-instance boot)
    (activate-generic-function-invocation boot)
    (activate-defmethod-in-e3 boot)
    (satiate-all-functions e1 e2 e3)))
