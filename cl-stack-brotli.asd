(defsystem "cl-stack-brotli"
  :version "1.2.1.2"
  :description "Brotli native overlays + thin CFFI for cl-stack Content-Encoding"
  :author "egao1980"
  :license "MIT"
  :defsystem-depends-on ("asdf-native")
  :depends-on ("cffi" "trivial-gray-streams" "compression-protocol")
  :serial t
  :pathname "src"
  :components ((:file "package")
               ;; $CL_STACK_BROTLI_NATIVE, native/ (overlay), lib/<os>-<arch>/ (checkout), else the system library; missing → warning (it loaded lazily before).
               ;; Dependency first: dec and enc link against common.
               (:native-library "brotlicommon" :versions ("1") :env "CL_STACK_BROTLI_NATIVE" :system t :optional t)
               (:native-library "brotlidec" :versions ("1") :env "CL_STACK_BROTLI_NATIVE" :system t :optional t)
               (:native-library "brotlienc" :versions ("1") :env "CL_STACK_BROTLI_NATIVE" :system t :optional t)
               (:file "ffi")
               (:file "api")
               (:file "streams")
               (:file "compression"))
  :in-order-to ((test-op (test-op "cl-stack-brotli/tests")))
  ;; Overlays: lib/<os>-<arch>/ per platform, from the :native-library components.
  :properties (:cl-repo (:provides ("cl-stack-brotli"))))

(defsystem "cl-stack-brotli/tests"
  :depends-on ("cl-stack-brotli" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "api-test")
               (:file "streams-test")
               (:file "protocol-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
