(defsystem "cl-stack-brotli"
  :version "1.2.0"
  :description "Brotli native overlays + thin CFFI for cl-stack Content-Encoding"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cffi" "trivial-gray-streams")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "ffi")
               (:file "api")
               (:file "streams"))
  :in-order-to ((test-op (test-op "cl-stack-brotli/tests")))
  :properties
  (:cl-repo
   (:cffi-libraries ("libbrotlicommon" "libbrotlidec" "libbrotlienc")
    :provides ("cl-stack-brotli")
    :overlays
    ((:platform (:os "linux" :arch "amd64")
      :layers ((:role "native-library"
                :files (("lib/linux-amd64/libbrotlicommon.so" . "libbrotlicommon.so")
                        ("lib/linux-amd64/libbrotlidec.so" . "libbrotlidec.so")
                        ("lib/linux-amd64/libbrotlienc.so" . "libbrotlienc.so")))))
     (:platform (:os "linux" :arch "arm64")
      :layers ((:role "native-library"
                :files (("lib/linux-arm64/libbrotlicommon.so" . "libbrotlicommon.so")
                        ("lib/linux-arm64/libbrotlidec.so" . "libbrotlidec.so")
                        ("lib/linux-arm64/libbrotlienc.so" . "libbrotlienc.so")))))
     (:platform (:os "darwin" :arch "arm64")
      :layers ((:role "native-library"
                :files (("lib/darwin-arm64/libbrotlicommon.dylib" . "libbrotlicommon.dylib")
                        ("lib/darwin-arm64/libbrotlidec.dylib" . "libbrotlidec.dylib")
                        ("lib/darwin-arm64/libbrotlienc.dylib" . "libbrotlienc.dylib")))))
     (:platform (:os "windows" :arch "amd64")
      :layers ((:role "native-library"
                :files (("lib/windows-amd64/brotlicommon.dll" . "brotlicommon.dll")
                        ("lib/windows-amd64/brotlidec.dll" . "brotlidec.dll")
                        ("lib/windows-amd64/brotlienc.dll" . "brotlienc.dll")))))))))

(defsystem "cl-stack-brotli/tests"
  :depends-on ("cl-stack-brotli" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "api-test")
               (:file "streams-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
