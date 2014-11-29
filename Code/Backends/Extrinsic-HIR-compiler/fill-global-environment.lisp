(cl:in-package #:sicl-extrinsic-hir-compiler)

;;; Enter every Common Lisp special operator into the environment.
;;; We can take them from the host environment.
(loop for symbol being each external-symbol in '#:common-lisp
      when (special-operator-p symbol)
	do (setf (sicl-env:special-operator symbol *environment*) t))

;;; Define NIL and T as constant variables.
(setf (sicl-env:constant-variable t *environment*) t)
(setf (sicl-env:constant-variable nil *environment*) nil)

;;; Initially, we enter lots of functions from the host environment
;;; into the target environment.  The reason for that is so that we
;;; can run the macroexpanders of the target macros that we will
;;; define.  Later, we gradually replace these functions with target
;;; versions.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *imported-functions*
    '(;; From the Conses dictionary
      cons consp atom
      rplaca rplacd
      car cdr rest
      caar cadr cdar cddr
      caaar caadr cadar caddr
      cdaar cdadr cddar cddr
      caaaar caaadr caadar caaddr cadaar cadadr caddar caddr
      cdaaar cdaadr cdadar cdaddr cddaar cddadr cdddar cdddr
      first second third
      fourth fifth sixth
      seventh eighth ninth
      tenth
      copy-tree sublis nsublis
      subst subst-if subst-if-not nsubst nsubst-if nsubst-if-not
      tree-equal copy-list list list* list-length listp
      make-list nth endp null nconc
      append revappend nreconc butlast nbutlast last
      ldiff tailp nthcdr
      member member-if member-if-not
      mapc mapcar mapcan mapl maplist mapcon
      acons assoc assoc-if assoc-if-not copy-alist
      pairlis rassoc rassoc-if rassoc-if-not
      get-properties getf
      intersection nintersection adjoin
      set-difference nset-difference
      set-exclusive-or nset-exclusive-or
      subsetp union nunion
      ;; From the Sequences dictionary
      copy-seq elt fill make-sequence subseq map map-into reduce
      count count-if count-if-not
      length reverse nreverse sort stable-sort
      find find-if find-if-not
      position position-if position-if-not
      search mismatch replace
      substitute substitute-if substitute-if-not
      nsubstitute nsubstitute-if nsubstitute-if-not
      concatenate merge
      remove remove-if remove-if-not
      delete delete-if delete-if-not
      remove-duplicates delete-duplicates
      ;; From the Conditions dictionary
      error warn
      ;; From the Numbers dictionary
      = /= < > <= >= max min minusp plusp zerop
      floor ceiling truncate round
      * + - / 1+ 1- abs evenp oddp exp expt
      mod rem numberp integerp rationalp)))

(loop for symbol in *imported-functions*
      do (setf (sicl-env:fdefinition symbol *environment*)
	       (fdefinition symbol)))

;;; Add every environment function into the environment.
(loop for symbol being each external-symbol in '#:sicl-env
      when (fboundp symbol)
	do (setf (sicl-env:fdefinition symbol *environment*)
		 (fdefinition symbol))
      when (fboundp `(setf ,symbol))
	do (setf (sicl-env:fdefinition `(setf ,symbol) *environment*)
		 (fdefinition `(setf ,symbol))))

(setf (sicl-env:macro-function 'defmacro *environment*)
      (compile nil
	       (cleavir-code-utilities:parse-macro
		'defmacro
		'(name lambda-list &body body)
		`((eval-when (:compile-toplevel :load-toplevel :execute)
		    (setf (sicl-env:macro-function name *environment*)
			  (compile nil
				   (cleavir-code-utilities:parse-macro
				    name
				    lambda-list
				    body))))))))

(setf (sicl-env:default-setf-expander *environment*)
      (lambda (form)
	(if (symbolp form)
	    (let ((new (gensym)))
	      (values '()
		      '()
		      `(,new)
		      `(setq ,form ,new)
		      form))
	    (let ((temps (loop for arg in (rest form) collect (gensym)))
		  (new (gensym)))
	      (values temps
		      (rest form)
		      `(,new)
		      `(funcall #'(setf ,(first form) ,new ,@temps))
		      `(,(first form) ,@temps))))))

;;; We need to be able to add new functions to the environment, so we
;;; need a definition of (SETF FDEFINITION).
(setf (sicl-env:fdefinition '(setf fdefinition) *environment*)
      (lambda (&rest args)
	(unless (= (length args) 2)
	  (funcall (sicl-env:fdefinition 'cl:error *environment*)
		   "wrong number of arguments"))
	(destructuring-bind (new-function name) args
	  (unless (functionp new-function)
	    (funcall (sicl-env:fdefinition 'cl:error *environment*)
		   "Argument to (SETF FDEFINITION) must be a function ~s"
		   new-function))
	  (unless (or (symbolp name)
		      (and (consp name)
			   (consp (cdr name))
			   (null (cddr name))
			   (eq (car name) 'setf)
			   (symbolp (cadr name))))
	    (funcall (sicl-env:fdefinition 'cl:error *environment*)
		     "(SETF FDEFINITION) must be given a function name, not ~s"
		     name))
	  (setf (sicl-env:fdefinition name *environment*)
		new-function))))

;;; We also need the function FUNCALL, because that is what is used by
;;; the default SETF expander.  At the momement, it only handles
;;; functions as its first argument.
(setf (sicl-env:fdefinition 'funcall *environment*)
      (lambda (&rest args)
	(unless (plusp (length args))
	  (funcall (sicl-env:fdefinition 'cl:error *environment*)
		   "wrong number of arguments"))
	(unless (functionp (first args))
	  (funcall (sicl-env:fdefinition 'cl:error *environment*)
		   "First argument to must be a function ~s"
		   (first args)))
	(apply (first args) (rest args))))

;;; We need a definition of the function VALUES, and the host one is
;;; just fine for this.
(setf (sicl-env:fdefinition 'values *environment*)
      #'values)

;;; Function SYMBOL-VALUE.  It searches the runtime stack to see
;;; whether there is a binding for the variable.  If no binding is
;;; found, it uses the variable-cell in the global environment.
;;;
;;; FIXME: Check argument count etc.
(setf (sicl-env:fdefinition 'symbol-value *environment*)
      (let ((env *environment*))
	(lambda (symbol)
	  (loop with unbound = (sicl-env:variable-unbound symbol env)
		with cell = (sicl-env:variable-cell symbol env)
		with error = (sicl-env:fdefinition 'cl:error env)
		for entry in *dynamic-environment*
		do (when (and (typep entry 'variable-binding)
			      (eq (symbol entry) symbol))
		     (if (eq (value entry) unbound)
			 (funcall error "unbound variable ~s" symbol)
			 (return (value entry))))
		finally
		   (if (eq (car cell) unbound)
		       (funcall error "unbound variable ~s" symbol)
		       (return (car cell)))))))

;;; Set the variable SICL-ENV:*ENVIRONMENT* in the environment.
(setf (sicl-env:special-variable 'sicl-env:*global-environment* *environment* t)
      *environment*)

;;; This definition allows us to find the definition of any host function.
;;; It is not ideal right now because it can fail and call ERROR.
(setf (sicl-env:fdefinition 'host-fdefinition *environment*)
      #'fdefinition)

;;; Import some simple functions to from the host to the target
;;; environment.
(defprimitive cl:consp (t))
(defprimitive cl:cons (t t))

(defprimitive cl:numberp (t))
(defprimitive cl:integerp (t))
(defprimitive cl:rationalp (t))

(defprimitive cl:null (t))

(defprimitive cl:symbolp (t))

(defprimitive cl:characterp (t))
(defprimitive cl:char-code (character))
(defprimitive cl:alphanumericp (character))

(defprimitive cl:stringp (t))
