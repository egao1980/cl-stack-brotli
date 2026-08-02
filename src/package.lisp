(defpackage #:cl-stack-brotli
  (:use #:cl #:cffi)
  (:export #:+brotli-version+
           #:brotli-error
           #:compress
           #:decompress
           #:make-decompressing-stream
           #:make-compressing-stream
           #:brotli-decompressing-stream
           #:brotli-compressing-stream))
