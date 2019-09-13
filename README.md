
# SICL: A new Common Lisp Implementation

This is the main source code repository for SICL. It contains the compiler,
standard library, and documentation.

## What is SICL?

SICL is a new implementation of Common
Lisp. It is intentionally
divided into many implementation-independent modules that are written
in a totally or near-totally portable way, so as to allow other
implementations to incorporate these modules from SICL, rather than
having to maintain their own, perhaps implementation-specific
versions.

## Quick Start

1. Make sure you have installed the dependencies:

[the Concrete-Syntax-Tree repository]:https://github.com/robert-strandh/Concrete-Syntax-Tree
[the Eclector repository]:https://github.com/robert-strandh/Eclector
[the Trucler repository]:https://github.com/robert-strandh/Trucler

   * A recent 64-bit version of SBCL
   * The system "concrete-syntax-tree" from [the Concrete-Syntax-Tree repository]
   * The system "eclector", from [the Eclector repository]
   * The system "trucler-reference", from [the Trucler repository]

2. Make sure your SBCL has a 10GB heap by passing --dynamic-space-size
   10000 to SBCL when it starts up.

3. Clone the [source] with `git`:

   ```
   $ git clone https://github.com/robert-strandh/SICL
   $ cd SICL
   ```

4. Make sure the top-level directory can be found by ASDF.

5. Compile the boot system as follows:

   ```lisp
   (asdf:load-system :sicl-boot)
   ```

6. Change the package for convenience:

   ```lisp
   (in-package #:sicl-boot)
   ```

7. Create an instance of the BOOT class:

   ```lisp
   (defparameter *b* (boot))
   ```

   Creating the first environment will take a few minutes.  In
   particular, it will seem that it is stuck when loading a few files,
   especially remf-defmacro.lisp.

8. Start a REPL:

   ```lisp
   (repl ee4)
   ```

[source]: https://github.com/robert-strandh/SICL

## Cleavir

Cleavir is an implementation-independent compilation framework for Common Lisp. To use it, make sure that you that you are in the SICL directory and load the neccesary packages and files.

```lisp
(ql:quickload '(cleavir-generate-ast  cleavir-ast-to-hir cleavir-hir-interpreter))
(load "Code/Cleavir/Environment/Examples/sbcl.lisp")
```

Now you can compile Common Lisp expressions like this:

```lisp
(cleavir-ast-to-hir:compile-toplevel-unhoisted
  (cleavir-generate-ast:generate-ast
   '(lambda () (+ 32 10))
   (sb-kernel:make-null-lexenv)
   nil))
```

## Documentation

SICL releases are [here].

[Documentation]:https://github.com/robert-strandh/SICL/tree/master/Specification

Check the [Documentation] directory for more information.

[here]:https://github.com/robert-strandh/SICL/blob/master/RELEASES.md

[CONTRIBUTING.md]: https://github.com/robert-strandh/SICL/blob/master/CONTRIBUTING.md

## Getting Help and Contributing

The SICL community members are usually on various IRC channels.  There
is now a dedicated channel called [#sicl], but discussion can also be
found on [#lisp], [#clasp], and [#clim].

[#sicl]: https://webchat.freenode.net/
[logs]:https://irclog.tymoon.eu/freenode/%23sicl
[#lisp]: https://webchat.freenode.net/
[#clasp]: https://webchat.freenode.net/
[#clim]: https://webchat.freenode.net/


[LICENSE-BSD]:https://github.com/robert-strandh/SICL/blob/master/LICENSE

Keep up on SICL by reading the IRC [logs]

If you want to contribute SICL, please read [CONTRIBUTING.md].

## License

SICL is primarily distributed under the terms of the BSD license.

See [LICENSE-BSD] for more details.



